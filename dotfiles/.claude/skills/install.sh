#!/usr/bin/env bash
#
# Deploy every skill in this directory into all detected AI agents.
#
# Single source of truth = THIS directory (tracked in git). Each agent's
# skills dir gets a symlink back here, so editing once updates every agent and
# git stays canonical. Skills use the portable `SKILL.md` + YAML-frontmatter
# contract, which Claude Code, Codex, Gemini CLI and others all read.
#
# A "skill" = any immediate sub-directory containing a SKILL.md.
#
# Usage:
#   ./install.sh [--dry-run] [--force] [--agent NAME] [--list]
#
#   --dry-run     show what would happen, change nothing
#   --force       replace a real (non-symlink) file/dir at the destination
#   --agent NAME  only this agent (claude|codex|gemini|cursor); repeatable
#   --list        list detected agents and local skills, then exit
#
# An agent is "detected" when its home dir exists. Override a skills dir with
# env vars: CLAUDE_SKILLS_DIR, CODEX_SKILLS_DIR, GEMINI_SKILLS_DIR,
# CURSOR_SKILLS_DIR.
set -euo pipefail

SKILLS_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# agent name -> "home-marker:skills-dir"
# Only agents with a real "<home>/skills/<name>/SKILL.md" discovery contract go
# here. Cursor / Copilot / Windsurf use per-project rule files (.cursor/rules/
# *.mdc) instead of a global skills dir — out of scope for this symlink
# installer; use `npx agent-skills-cli` for those.
AGENTS=(
  "claude:$HOME/.claude:${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
  "codex:$HOME/.codex:${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
  "gemini:$HOME/.gemini:${GEMINI_SKILLS_DIR:-$HOME/.gemini/skills}"
)

DRY=0; FORCE=0; LIST=0; ONLY=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --force)   FORCE=1 ;;
    --list)    LIST=1 ;;
    --agent)   ONLY+=("${2:?--agent needs a name}"); shift ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac; shift
done

wanted() { # $1 agent name -> 0 if selected
  [ "${#ONLY[@]}" -eq 0 ] && return 0
  local a; for a in "${ONLY[@]}"; do [ "$a" = "$1" ] && return 0; done
  return 1
}

# discover local skills (immediate subdirs with a SKILL.md)
mapfile -t SKILLS < <(
  for d in "$SKILLS_SRC"/*/; do
    [ -f "${d}SKILL.md" ] && basename "$d"
  done | sort
)

if [ "$LIST" -eq 1 ]; then
  echo "skills source: $SKILLS_SRC"
  echo "local skills:  ${SKILLS[*]:-<none>}"
  echo "agents:"
  for entry in "${AGENTS[@]}"; do
    IFS=: read -r name home dir <<< "$entry"
    [ -d "$home" ] && echo "  [present] $name -> $dir" || echo "  [absent ] $name"
  done
  exit 0
fi

[ "${#SKILLS[@]}" -eq 0 ] && { echo "no skills found in $SKILLS_SRC" >&2; exit 1; }

link_one() { # $1 agent, $2 skills-dir, $3 skill-name
  local agent="$1" dir="$2" name="$3"
  local src="$SKILLS_SRC/$name" dest="$dir/$name"

  if [ -L "$dest" ]; then
    if [ "$(readlink "$dest")" = "$src" ]; then
      echo "  = $agent/$name (already linked)"; return 0
    fi
  elif [ -e "$dest" ]; then
    if [ "$FORCE" -ne 1 ]; then
      echo "  ! $agent/$name exists and is not our symlink — skip (use --force)" >&2
      return 0
    fi
  fi

  if [ "$DRY" -eq 1 ]; then
    echo "  + [dry] $agent/$name -> $src"; return 0
  fi
  mkdir -p "$dir"
  rm -rf "$dest"
  ln -s "$src" "$dest"
  echo "  + $agent/$name -> linked"
}

for entry in "${AGENTS[@]}"; do
  IFS=: read -r name home dir <<< "$entry"
  wanted "$name" || continue
  [ -d "$home" ] || { echo "[skip] $name not installed"; continue; }
  echo "[$name] -> $dir"
  for s in "${SKILLS[@]}"; do link_one "$name" "$dir" "$s"; done
done

echo "done."
