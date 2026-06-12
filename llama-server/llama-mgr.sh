#!/usr/bin/env bash
# llama-mgr — управление llama.cpp (update / start / stop / status / models)
set -euo pipefail

LLAMA_DIR="$HOME/llama.cpp"
MODELS_DIR="$HOME/models"
PID_FILE="/tmp/llama-server.pid"
LOG_FILE="/tmp/llama-server.log"

# ── цвета ──────────────────────────────────────────────────────────────────────
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' B='\033[0;34m' C='\033[0;36m' N='\033[0m'

info()    { echo -e "${B}[•]${N} $*"; }
ok()      { echo -e "${G}[✓]${N} $*"; }
warn()    { echo -e "${Y}[!]${N} $*"; }
err()     { echo -e "${R}[✗]${N} $*" >&2; }
die()     { err "$*"; exit 1; }

# ── текущая установленная версия ───────────────────────────────────────────────
current_build() {
  local latest
  latest=$(ls -1 "$LLAMA_DIR" | grep -E '^llama-b[0-9]+$' | sort -t b -k2 -n | tail -1)
  echo "${latest#llama-}"   # → "b9536"
}

current_bin_dir() {
  echo "$LLAMA_DIR/llama-$(current_build)"
}

# ── статус сервера ─────────────────────────────────────────────────────────────
_find_server_pid() {
  # 1. PID-файл (запущен через llama-mgr start)
  if [[ -f "$PID_FILE" ]]; then
    local pid; pid=$(cat "$PID_FILE")
    kill -0 "$pid" 2>/dev/null && { echo "$pid"; return; }
  fi
  # 2. systemd user service
  if systemctl --user is-active --quiet llama.service 2>/dev/null; then
    local spid; spid=$(systemctl --user show llama.service --property=MainPID --value 2>/dev/null)
    [[ "$spid" =~ ^[0-9]+$ && "$spid" != "0" ]] && { echo "$spid"; return; }
  fi
  # 3. fallback: любой llama-server процесс
  pgrep -x llama-server 2>/dev/null | head -1 || true
}

cmd_status() {
  local pid; pid=$(_find_server_pid)
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    ok "Сервер запущен  PID=$pid"
    echo -e "   ${C}API:${N}  http://127.0.0.1:8080"
    echo -e "   ${C}Лог:${N}  $LOG_FILE"
    local model
    model=$(ps -p "$pid" -o args= 2>/dev/null | grep -oP '(?<=--model )\S+' || true)
    [[ -n "$model" ]] && echo -e "   ${C}Модель:${N} $(basename "$model")"
    systemctl --user is-active --quiet llama.service 2>/dev/null && \
      echo -e "   ${C}Управление:${N} systemd (llama.service)"
    return 0
  fi
  warn "Сервер не запущен"
  return 1
}

# ── список моделей ─────────────────────────────────────────────────────────────
cmd_models() {
  info "Модели в $MODELS_DIR:"
  local i=1
  while IFS= read -r f; do
    local size
    size=$(du -sh "$f" | cut -f1)
    echo -e "  ${Y}[$i]${N} $(basename "$f")  ${C}($size)${N}"
    ((i++))
  done < <(find "$MODELS_DIR" -maxdepth 1 -name "*.gguf" | sort)
}

# ── выбор модели ───────────────────────────────────────────────────────────────
pick_model() {
  local models=()
  # сортировка по размеру убывает → самая большая ([1]) — дефолт
  while IFS= read -r f; do models+=("$f"); done < <(
    find "$MODELS_DIR" -maxdepth 1 -name "*.gguf" -printf '%s\t%p\n' | sort -rn | cut -f2
  )
  [[ ${#models[@]} -eq 0 ]] && die "Нет .gguf моделей в $MODELS_DIR"

  if [[ ${#models[@]} -eq 1 ]]; then
    echo "${models[0]}"
    return
  fi

  local i=1
  for f in "${models[@]}"; do
    local size
    size=$(du -sh "$f" | cut -f1)
    if [[ $i -eq 1 ]]; then
      echo -e "  ${G}[$i]${N} $(basename "$f")  ${C}($size)${N}  ${Y}← default${N}" >/dev/tty
    else
      echo -e "  ${Y}[$i]${N} $(basename "$f")  ${C}($size)${N}" >/dev/tty
    fi
    ((i++))
  done

  echo -ne "\n${Y}Выберите модель [1-${#models[@]}, Enter = 1]:${N} " >/dev/tty
  read -r choice </dev/tty
  [[ -z "$choice" ]] && choice=1
  [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le ${#models[@]} ]] \
    || die "Неверный выбор"
  echo "${models[$((choice-1))]}"
}

# ── конфиг ─────────────────────────────────────────────────────────────────────
CONF_FILE="$LLAMA_DIR/llama-mgr.conf"

# Дефолты — перекрываются конфигом и CLI-флагами
CFG_CTX=131072
CFG_PORT=8080
CFG_HOST=0.0.0.0
CFG_PARALLEL=1
CFG_NGL=999
CFG_BATCH=4096
CFG_UBATCH=2048
CFG_N_PREDICT=32768
CFG_CACHE_REUSE=2048
CFG_KV_TYPE_K=q8_0
CFG_KV_TYPE_V=q8_0
CFG_FLASH_ATTN=on
CFG_ROPE_SCALING=yarn
CFG_YARN_ORIG_CTX=32768
CFG_TEMP=0.6
CFG_TOP_K=20
CFG_TOP_P=0.95
CFG_MIN_P=0.0
CFG_NCMOE=32        # кол-во экспертов MoE (-ncmoe / --n-cpu-moe)
CFG_EXTRA_ARGS=""   # произвольные доп. флаги llama-server

load_conf() {
  [[ -f "$CONF_FILE" ]] || return 0
  # shellcheck disable=SC1090
  source "$CONF_FILE"
}

cmd_config() {
  if [[ ! -f "$CONF_FILE" ]]; then
    cat >"$CONF_FILE" <<'EOF'
# llama-mgr.conf — параметры запуска llama-server

# ── контекст / батчинг ────────────────────────────────────────────────────────
CFG_CTX=131072          # --ctx-size          размер контекста (токены)
CFG_N_PREDICT=32768     # --n-predict         макс. токенов генерации
CFG_BATCH=4096          # --batch-size        размер батча (prompt processing)
CFG_UBATCH=2048         # --ubatch-size       микробатч (физический)
CFG_CACHE_REUSE=2048    # --cache-reuse       порог переиспользования KV-кэша

# ── GPU ───────────────────────────────────────────────────────────────────────
CFG_NGL=999             # --n-gpu-layers      слоёв на GPU (999 = всё)

# ── сеть ──────────────────────────────────────────────────────────────────────
CFG_HOST=0.0.0.0        # --host              0.0.0.0 = доступен снаружи
CFG_PORT=8080           # --port

# ── параллелизм ───────────────────────────────────────────────────────────────
CFG_PARALLEL=1          # --parallel  (-np)   параллельных слотов

# ── KV-кэш ───────────────────────────────────────────────────────────────────
CFG_KV_TYPE_K=q8_0      # --cache-type-k      f16 / q8_0 / q4_0
CFG_KV_TYPE_V=q8_0      # --cache-type-v
CFG_FLASH_ATTN=on       # --flash-attn        on / off

# ── RoPE ──────────────────────────────────────────────────────────────────────
CFG_ROPE_SCALING=yarn   # --rope-scaling      none / linear / yarn
CFG_YARN_ORIG_CTX=32768 # --yarn-orig-ctx     оригинальный контекст модели

# ── сэмплинг (дефолты для сервера) ───────────────────────────────────────────
CFG_TEMP=0.6            # --temp
CFG_TOP_K=20            # --top-k
CFG_TOP_P=0.95          # --top-p
CFG_MIN_P=0.0           # --min-p

# ── MoE ───────────────────────────────────────────────────────────────────────
CFG_NCMOE=32            # -ncmoe              кол-во активных экспертов

# ── всё остальное ─────────────────────────────────────────────────────────────
# CFG_EXTRA_ARGS="--no-mmap --mlock"
CFG_EXTRA_ARGS=""
EOF
    ok "Создан конфиг: $CONF_FILE"
  fi
  "${EDITOR:-nano}" "$CONF_FILE"
}

# ── запуск ─────────────────────────────────────────────────────────────────────
cmd_start() {
  cmd_status &>/dev/null && { warn "Сервер уже запущен. Используй 'restart' или 'stop'."; return; }

  load_conf

  # Парсинг CLI-флагов (перекрывают конфиг)
  local model=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --model)      model="$2";            shift 2 ;;
      --ctx)        CFG_CTX="$2";          shift 2 ;;
      --port)       CFG_PORT="$2";         shift 2 ;;
      --host)       CFG_HOST="$2";         shift 2 ;;
      --parallel)   CFG_PARALLEL="$2";     shift 2 ;;
      --ngl)        CFG_NGL="$2";          shift 2 ;;
      --batch)      CFG_BATCH="$2";        shift 2 ;;
      --ubatch)     CFG_UBATCH="$2";       shift 2 ;;
      --n-predict)  CFG_N_PREDICT="$2";    shift 2 ;;
      --cache-reuse) CFG_CACHE_REUSE="$2"; shift 2 ;;
      --kv-k)       CFG_KV_TYPE_K="$2";   shift 2 ;;
      --kv-v)       CFG_KV_TYPE_V="$2";   shift 2 ;;
      --flash)      CFG_FLASH_ATTN="$2";   shift 2 ;;
      --temp)       CFG_TEMP="$2";         shift 2 ;;
      --top-k)      CFG_TOP_K="$2";        shift 2 ;;
      --top-p)      CFG_TOP_P="$2";        shift 2 ;;
      --min-p)      CFG_MIN_P="$2";        shift 2 ;;
      --ncmoe)      CFG_NCMOE="$2";        shift 2 ;;
      --extra)      CFG_EXTRA_ARGS="$2";   shift 2 ;;
      -*)           die "Неизвестный флаг: $1" ;;
      *)            model="$1";            shift ;;
    esac
  done

  if [[ -z "$model" ]]; then
    model=$(pick_model)
  fi
  [[ -f "$model" ]] || die "Модель не найдена: $model"

  local bindir
  bindir=$(current_bin_dir)

  echo -e "${C}"
  echo '  ██╗     ██╗      █████╗ ███╗   ███╗ █████╗'
  echo '  ██║     ██║     ██╔══██╗████╗ ████║██╔══██╗'
  echo '  ██║     ██║     ███████║██╔████╔██║███████║'
  echo '  ██║     ██║     ██╔══██║██║╚██╔╝██║██╔══██║'
  echo '  ███████╗███████╗██║  ██║██║ ╚═╝ ██║██║  ██║'
  echo '  ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝'
  echo -e "${N}"
  echo -e "  ${B}model   ${N} $(basename "$model")"
  echo -e "  ${B}build   ${N} $(current_build)"
  echo -e "  ${B}ctx     ${N} $CFG_CTX  │  ngl $CFG_NGL  │  batch $CFG_BATCH / $CFG_UBATCH"
  echo -e "  ${B}kv      ${N} ${CFG_KV_TYPE_K}/${CFG_KV_TYPE_V}  │  flash $CFG_FLASH_ATTN  │  moe $CFG_NCMOE"
  echo -e "  ${B}sampler ${N} temp $CFG_TEMP  top_k $CFG_TOP_K  top_p $CFG_TOP_P  min_p $CFG_MIN_P"
  echo -e "  ${B}listen  ${N} http://$CFG_HOST:$CFG_PORT"
  echo

  local extra_arr=()
  # shellcheck disable=SC2206
  [[ -n "$CFG_EXTRA_ARGS" ]] && extra_arr=($CFG_EXTRA_ARGS)

  LD_LIBRARY_PATH="$bindir" "$bindir/llama-server" \
    --model           "$model" \
    --ctx-size        "$CFG_CTX" \
    --n-predict       "$CFG_N_PREDICT" \
    --batch-size      "$CFG_BATCH" \
    --ubatch-size     "$CFG_UBATCH" \
    --n-gpu-layers    "$CFG_NGL" \
    --cache-reuse     "$CFG_CACHE_REUSE" \
    --cache-type-k    "$CFG_KV_TYPE_K" \
    --cache-type-v    "$CFG_KV_TYPE_V" \
    --flash-attn      "$CFG_FLASH_ATTN" \
    --rope-scaling    "$CFG_ROPE_SCALING" \
    --yarn-orig-ctx   "$CFG_YARN_ORIG_CTX" \
    --temp            "$CFG_TEMP" \
    --top-k           "$CFG_TOP_K" \
    --top-p           "$CFG_TOP_P" \
    --min-p           "$CFG_MIN_P" \
    -ncmoe            "$CFG_NCMOE" \
    --parallel        "$CFG_PARALLEL" \
    --host            "$CFG_HOST" \
    --port            "$CFG_PORT" \
    --jinja \
    "${extra_arr[@]}" \
    >"$LOG_FILE" 2>&1 &

  echo $! >"$PID_FILE"
  sleep 1
  if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    ok "Запущен  PID=$(cat "$PID_FILE")  →  http://$CFG_HOST:$CFG_PORT"
    echo -e "  ${B}logs    ${N} llama-mgr log"
  else
    err "Процесс упал. Смотри лог: $LOG_FILE"
    tail -20 "$LOG_FILE"
    exit 1
  fi
}

# ── остановка ──────────────────────────────────────────────────────────────────
cmd_stop() {
  local stopped=0

  # systemd user service
  if systemctl --user is-active --quiet llama.service 2>/dev/null; then
    systemctl --user stop llama.service
    ok "Systemd сервис остановлен (llama.service)"
    stopped=1
  fi

  # PID-файл (запущен через llama-mgr start)
  if [[ -f "$PID_FILE" ]]; then
    local pid; pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid"
      ok "Сервер остановлен (PID=$pid)"
      stopped=1
    fi
    rm -f "$PID_FILE"
  fi

  # fallback: убить оставшиеся процессы
  local leftover; leftover=$(pgrep -x llama-server 2>/dev/null || true)
  if [[ -n "$leftover" ]]; then
    kill $leftover 2>/dev/null && ok "Убиты оставшиеся процессы: $leftover" || true
    stopped=1
  fi

  [[ "$stopped" -eq 0 ]] && warn "Сервер не был запущен"
}

cmd_restart() {
  cmd_stop || true
  sleep 1
  cmd_start "$@"   # все флаги пробрасываются
}

# ── обновление ─────────────────────────────────────────────────────────────────
cmd_update() {
  command -v curl &>/dev/null || die "curl не установлен"
  command -v unzip &>/dev/null || die "unzip не установлен"

  info "Проверяю последний релиз llama.cpp на GitHub..."
  local api_url="https://api.github.com/repos/ggml-org/llama.cpp/releases/latest"
  local release
  release=$(curl -fsSL "$api_url") || die "Не удалось получить данные с GitHub"

  local tag
  tag=$(echo "$release" | grep -oP '"tag_name":\s*"\K[^"]+')
  local build="${tag#b}"        # "9999"
  local build_tag="b$build"    # "b9999"

  local cur
  cur=$(current_build)          # "b9536"

  if [[ "$build_tag" == "$cur" ]]; then
    ok "Уже установлена актуальная версия: $cur"
    return
  fi

  info "Текущая: $cur  →  Новая: $build_tag"

  # Ищем Linux-CUDA бинарник в assets (cu12 → cu11 → любой cuda)
  local all_assets
  all_assets=$(echo "$release" | grep -oP '"browser_download_url":\s*"\K[^"]+' | grep -v '\.sha256')

  local asset_url
  asset_url=$(echo "$all_assets" | grep -i 'ubuntu' | grep -i 'cuda' | grep -i 'x64' | grep -i 'cu12' | head -1 || true)
  [[ -z "$asset_url" ]] && \
    asset_url=$(echo "$all_assets" | grep -i 'ubuntu' | grep -i 'cuda' | grep -i 'x64' | grep -i 'cu11' | head -1 || true)
  [[ -z "$asset_url" ]] && \
    asset_url=$(echo "$all_assets" | grep -i 'ubuntu' | grep -i 'cuda' | grep -i 'x64' | head -1 || true)

  if [[ -z "$asset_url" ]]; then
    warn "CUDA-бинарник для Ubuntu x64 не найден в релизе $build_tag"
    info "Доступные активы:"
    echo "$all_assets" | sed 's/^/  /'
    die "Обновление отменено. Скачай нужный пакет вручную."
  fi

  local zip_name
  zip_name=$(basename "$asset_url")
  local tmp_dir
  tmp_dir=$(mktemp -d)

  info "Скачиваю $zip_name ..."
  curl -fL --progress-bar "$asset_url" -o "$tmp_dir/$zip_name"

  info "Распаковываю..."
  unzip -q "$tmp_dir/$zip_name" -d "$tmp_dir/out"

  # Переносим в целевую директорию
  local dest="$LLAMA_DIR/llama-$build_tag"
  mkdir -p "$dest"
  # Бинарники обычно лежат в build/bin или прямо в корне архива
  local bin_src
  bin_src=$(find "$tmp_dir/out" -name "llama-server" -type f | head -1)
  [[ -n "$bin_src" ]] || die "llama-server не найден в архиве"
  local bin_dir
  bin_dir=$(dirname "$bin_src")
  cp -r "$bin_dir/." "$dest/"
  chmod +x "$dest"/llama-* 2>/dev/null || true

  rm -rf "$tmp_dir"
  ok "Обновлено до $build_tag  →  $dest"
  warn "Перезапусти сервер командой:  llama-mgr restart"
}

# ── лог ────────────────────────────────────────────────────────────────────────
cmd_log() {
  [[ -f "$LOG_FILE" ]] || die "Лог не найден: $LOG_FILE"
  tail -f "$LOG_FILE"
}

# ── помощь ─────────────────────────────────────────────────────────────────────
usage() {
  echo -e "${C}llama-mgr${N} — управление llama.cpp сервером\n"
  echo -e "  ${Y}start${N}   [модель] [флаги]        Запустить (интерактивный выбор если модель не указана)"
  echo -e "  ${Y}stop${N}                            Остановить сервер"
  echo -e "  ${Y}restart${N} [модель] [флаги]        Перезапустить"
  echo -e "  ${Y}status${N}                          Статус"
  echo -e "  ${Y}log${N}                             Следить за логом (Ctrl+C)"
  echo -e "  ${Y}models${N}                          Список доступных моделей"
  echo -e "  ${Y}update${N}                          Обновить бинарники с GitHub"
  echo -e "  ${Y}config${N}                          Открыть конфиг в редакторе\n"
  echo -e "${C}Флаги start/restart:${N}"
  echo -e "  ${B}--model${N}    <путь>     путь к .gguf"
  echo -e "  ${B}--ctx${N}      <N>        размер контекста (сейчас: $CFG_CTX)"
  echo -e "  ${B}--port${N}     <N>        порт (сейчас: $CFG_PORT)"
  echo -e "  ${B}--host${N}     <addr>     хост (сейчас: $CFG_HOST)"
  echo -e "  ${B}--parallel${N} <N>        параллельных слотов"
  echo -e "  ${B}--ngl${N}      <N>        слоёв на GPU (пусто = авто)"
  echo -e "  ${B}--kv-k${N}     <type>     квантизация KV K (f16/q8_0/q4_0)"
  echo -e "  ${B}--kv-v${N}     <type>     квантизация KV V"
  echo -e "  ${B}--flash${N}    on|off     flash attention"
  echo -e "  ${B}--extra${N}    \"...\"      произвольные доп. флаги llama-server\n"
  echo -e "${C}Примеры:${N}"
  echo -e "  llama-mgr start --ctx 32768 --port 8081"
  echo -e "  llama-mgr start --ngl 35 --parallel 4 --extra \"--no-mmap\""
  echo -e "  llama-mgr restart --model ~/models/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf"
}

# ── точка входа ────────────────────────────────────────────────────────────────
subcmd="${1:-}"; shift || true
case "$subcmd" in
  start)   cmd_start   "$@" ;;
  stop)    cmd_stop ;;
  restart) cmd_restart "$@" ;;
  status)  cmd_status ;;
  log)     cmd_log ;;
  models)  cmd_models ;;
  update)  cmd_update ;;
  config)  cmd_config ;;
  *)       load_conf; usage ;;
esac
