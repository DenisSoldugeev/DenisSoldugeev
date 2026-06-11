# llama-server

Local LLM on Linux — [llama.cpp](https://github.com/ggml-org/llama.cpp) (Vulkan)
serving models on an RTX 3060 (12 GB), managed via `llama-mgr` or as a
`systemd --user` service with a `make` wrapper.

- Web UI + OpenAI-compatible API on `http://localhost:8080` (`/v1/chat/completions`)
- 64K context (YaRN-extended), q8 KV cache + flash-attn to fit 12 GB VRAM
- Auto-starts on boot via systemd, restarts on failure

## Contents

| File | Target | Purpose |
|------|--------|---------|
| `llama-mgr.sh` | `~/llama.cpp/llama-mgr.sh` + `~/bin/llama-mgr` | interactive server manager (start / stop / update / models) |
| `llama-mgr.conf` | `~/llama.cpp/llama-mgr.conf` | runtime config (ctx, KV, sampling…) |
| `serve.sh` | `~/llama.cpp/serve.sh` | fixed-config launcher used by the systemd unit |
| `llama.service` | `~/.config/systemd/user/llama.service` | systemd --user unit (autostart, restart-on-failure) |
| `Makefile` | `~/Makefile` | `make llama-*` wrapper over `systemctl --user` |
| `install.sh` | — | lays all of the above into place |

## Install

```sh
./install.sh
llama-mgr start        # interactive — pick a model, start in background
# or via systemd:
make llama-start
```

## llama-mgr

The primary way to run the server interactively. Detects the latest installed
build automatically, reads `~/llama.cpp/llama-mgr.conf`, and accepts CLI overrides.

```sh
llama-mgr                           # help + current settings
llama-mgr start                     # pick model interactively, then start
llama-mgr start --ctx 32768         # override context size
llama-mgr start --model ~/models/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf
llama-mgr stop
llama-mgr restart
llama-mgr status                    # is it running? PID / URL / model
llama-mgr log                       # tail -f /tmp/llama-server.log
llama-mgr models                    # list .gguf files in ~/models/
llama-mgr update                    # pull latest Vulkan build from GitHub
llama-mgr config                    # open llama-mgr.conf in $EDITOR
```

### CLI overrides (start / restart)

| Flag | Default | Description |
|------|---------|-------------|
| `--model <path>` | interactive | path to .gguf |
| `--ctx <N>` | 131072 | context size |
| `--port <N>` | 8080 | listen port |
| `--host <addr>` | 0.0.0.0 | listen host |
| `--parallel <N>` | 1 | concurrent slots |
| `--ngl <N>` | 999 | GPU layers (999 = all) |
| `--kv-k <type>` | q8_0 | KV key quant (f16/q8_0/q4_0) |
| `--kv-v <type>` | q8_0 | KV value quant |
| `--flash on\|off` | on | flash attention |
| `--ncmoe <N>` | 32 | active MoE experts |
| `--extra "..."` | — | raw extra flags for llama-server |

## Systemd / make

```sh
make                 # command list + live status
make llama-start     # start
make llama-stop      # stop
make llama-restart   # restart
make llama-status    # active/inactive + URL
make llama-logs      # live logs (Ctrl+C to exit)
make llama-tail      # last 50 log lines
make llama-ps        # processes + memory
make llama-enable    # autostart on boot
make llama-disable   # disable autostart
make llama-url       # open the web UI
```

The systemd unit runs `serve.sh` which is pinned to **Qwen2.5-14B** and
auto-detects the latest installed build. For a different model, use `llama-mgr`.

## Requirements

Not tracked in this repo (too large) — provide them separately:

| What | Expected path | How |
|------|---------------|-----|
| llama.cpp Vulkan build | `~/llama.cpp/llama-b<N>/` | prebuilt Vulkan release from [llama.cpp releases](https://github.com/ggml-org/llama.cpp/releases) — look for `ubuntu-vulkan-x64` |
| Model weights | `~/models/*.gguf` | download below |

Vulkan runtime (`vulkan-icd-loader` + NVIDIA driver Vulkan ICD) must be present.

### Models

| Model | Size | Path |
|-------|------|------|
| Qwen2.5-14B-Instruct Q4\_K\_M | ~8.4 GB | `~/models/Qwen2.5-14B-Instruct-Q4_K_M.gguf` |
| Qwen3.6-35B-A3B-UD Q4\_K\_XL | ~22 GB | `~/models/Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf` |

## Notes

- Bound to `127.0.0.1` in the systemd unit (local only). `llama-mgr` defaults to
  `0.0.0.0` — tunnel from another host with `ssh -fN -L 8090:127.0.0.1:8080 user@host`.
- `llama-mgr update` fetches the latest Vulkan Ubuntu x64 release from GitHub
  and extracts it into `~/llama.cpp/llama-b<N>/`. The next `start` picks it up
  automatically via build auto-detection.
- `llama-mgr.conf` is not overwritten by re-running `install.sh` — local tuning
  is preserved.
