#!/usr/bin/env bash
#
# Detect REUSED passwords across 1Password logins.
#
# Security model: each password value is piped value -> sha256 inside a
# subshell. The value is NEVER stored in a variable, NEVER echoed, and NEVER
# leaves this script. Output is ONLY: salted hash buckets with item titles.
# The salt is per-run and in-memory, so hashes are not comparable across runs.
#
# This is the HEAVIEST check: it reads every login's secret via the desktop
# app, which may trigger native approval prompts. Run it intentionally.
#
# Usage: reuse-check.sh [--vault NAME]
set -euo pipefail

VAULT=""
[ "${1:-}" = "--vault" ] && { VAULT="${2:?--vault needs a value}"; }

command -v op >/dev/null || { echo "op CLI not found" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq not found" >&2; exit 1; }
op vault list >/dev/null 2>&1 || { echo "op: not reachable. Sign in (eval \$(op signin)) or enable desktop-app CLI integration." >&2; exit 1; }

# per-run salt so emitted hashes can't be matched against any external table
SALT="$(head -c 16 /dev/urandom | xxd -p)"

LIST_ARGS=(item list --categories Login --format json)
[ -n "$VAULT" ] && LIST_ARGS+=(--vault "$VAULT")

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT

# id<TAB>title map from the (value-free) list
declare -A TITLE
while IFS=$'\t' read -r id title; do TITLE["$id"]="$title"; done < <(
  op "${LIST_ARGS[@]}" | jq -r '.[] | [.id, .title] | @tsv')

echo "scanning ${#TITLE[@]} logins (values hashed locally, never printed)…" >&2

for id in "${!TITLE[@]}"; do
  # value -> sha256, fully in-pipe. empty/absent password -> skip.
  h="$(op item get "$id" --format json 2>/dev/null \
        | jq -r 'first(.fields[]? | select(.purpose=="PASSWORD") | .value) // empty' \
        | { IFS= read -r v || true; [ -n "$v" ] && printf '%s%s' "$SALT" "$v" | shasum -a 256 | awk '{print $1}'; })" || true
  [ -n "$h" ] && printf '%s\t%s\n' "$h" "$id" >> "$tmp"
done

# group by hash; report only buckets with >1 distinct item
echo
echo "# Reused passwords"
awk -F'\t' '{a[$1]=a[$1]","$2; n[$1]++} END{for(h in n) if(n[h]>1) print n[h]"\t"a[h]}' "$tmp" \
  | sort -rn \
  | while IFS=$'\t' read -r count ids; do
      echo "- **${count} items share one password:**"
      IFS=',' read -ra arr <<< "${ids#,}"
      for id in "${arr[@]}"; do echo "    - ${TITLE[$id]:-?}  \`$id\`"; done
    done

groups="$(awk -F'\t' '{n[$1]++} END{c=0; for(h in n) if(n[h]>1) c++; print c}' "$tmp")"
[ "${groups:-0}" -eq 0 ] && echo "_No reused passwords found._"
echo
echo "_No changes were made. Rotate shared passwords in the 1Password app or via \`op item edit\`._"
