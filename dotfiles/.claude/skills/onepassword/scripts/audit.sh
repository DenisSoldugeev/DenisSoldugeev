#!/usr/bin/env bash
#
# 1Password vault hygiene audit — READ ONLY. Makes NO changes to any item.
#
# Security model: password VALUES are never read into the report. Default mode
# uses only `op item list` (pure metadata). --deep additionally calls
# `op item get` per item but extracts ONLY field shape (strength label, OTP
# presence, URL/username presence) — the `.value`/`.totp` are dropped by jq and
# never printed.
#
# Usage:
#   audit.sh [--vault NAME] [--stale-days N] [--deep] [--max-list N]
#
# Flags:
#   --vault NAME    limit audit to one vault (default: all)
#   --stale-days N  staleness threshold in days (default: 730 = 2 years)
#   --deep          add weak-password / no-2FA / no-URL checks (slow: one
#                   `op item get` per item; values stay out of context)
#   --max-list N    cap items shown per finding section (default: 40)
#
# Exit codes: 0 ok (report printed), 1 environment error, 2 bad usage.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Taxonomy precedence: $ONEP_TAXONOMY > assets/taxonomy.local.txt (personal,
# gitignored) > assets/taxonomy.txt (generic default committed to the repo).
if [ -n "${ONEP_TAXONOMY:-}" ]; then
  TAXONOMY="$ONEP_TAXONOMY"
elif [ -f "$SKILL_DIR/assets/taxonomy.local.txt" ]; then
  TAXONOMY="$SKILL_DIR/assets/taxonomy.local.txt"
else
  TAXONOMY="$SKILL_DIR/assets/taxonomy.txt"
fi

VAULT=""; STALE_DAYS=730; DEEP=0; MAX_LIST=40
while [ $# -gt 0 ]; do
  case "$1" in
    --vault)      VAULT="${2:?--vault needs a value}"; shift ;;
    --stale-days) STALE_DAYS="${2:?--stale-days needs a value}"; shift ;;
    --deep)       DEEP=1 ;;
    --max-list)   MAX_LIST="${2:?--max-list needs a value}"; shift ;;
    -h|--help)    sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac; shift
done

command -v op >/dev/null || { echo "op CLI not found (brew install 1password-cli)" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq not found (brew install jq)" >&2; exit 1; }
op vault list >/dev/null 2>&1 || { echo "op: not reachable. Sign in (eval \$(op signin)) or enable desktop-app CLI integration." >&2; exit 1; }
[ -f "$TAXONOMY" ] || { echo "taxonomy not found: $TAXONOMY" >&2; exit 1; }

STALE_SECS=$(( STALE_DAYS * 86400 ))

# --- load taxonomy ---------------------------------------------------------
ALLOWJSON="$(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$TAXONOMY" \
  | sed -E 's/[[:space:]]+$//' \
  | jq -R -s 'split("\n") | map(select(length>0))')"

# domains that own at least one sub-tag must never appear bare
BAREJSON="$(printf '%s' "$ALLOWJSON" \
  | jq -c '[ .[] | select(test("/")) | split("/")[0] ] | unique')"

REMAPJSON="$(grep -E '^[[:space:]]*#remap ' "$TAXONOMY" 2>/dev/null \
  | sed -E 's/^[[:space:]]*#remap[[:space:]]+//' \
  | awk -F' -> ' 'NF==2{printf "%s\t%s\n",$1,$2}' \
  | jq -R -s 'split("\n") | map(select(length>0) | split("\t") | {(.[0]):.[1]}) | add // {}')"

# --- pull item metadata ----------------------------------------------------
LIST_ARGS=(item list --format json)
[ -n "$VAULT" ] && LIST_ARGS+=(--vault "$VAULT")
ITEMS="$(op "${LIST_ARGS[@]}")"
TOTAL="$(printf '%s' "$ITEMS" | jq 'length')"

# --- list-based findings (fast, metadata only) -----------------------------
REPORT="$(jq -n \
  --argjson items "$ITEMS" \
  --argjson allow "$ALLOWJSON" \
  --argjson bare "$BAREJSON" \
  --argjson remap "$REMAPJSON" \
  --argjson staleSecs "$STALE_SECS" '
  def slim: {id, title, vault: .vault.name, category, tags: (.tags // [])};

  ($items) as $all
  | {
      untagged: [ $all[] | select(((.tags // []) | length) == 0) | slim ],

      remap: [ $all[] | . as $it | (.tags // [])[] as $t
               | select($remap[$t] != null)
               | {id: $it.id, title: $it.title, vault: $it.vault.name,
                  from: $t, to: $remap[$t],
                  newtags: (($it.tags // []) | map($remap[.] // .) | unique | join(",")) } ],

      bare: [ $all[] | . as $it | (.tags // [])[] as $t
              | select(($bare | index($t)) != null)
              | {id: $it.id, title: $it.title, vault: $it.vault.name, tag: $t} ],

      unknown: [ $all[] | . as $it | (.tags // [])[] as $t
                 | select(($allow | index($t)) == null
                          and ($bare | index($t)) == null
                          and $remap[$t] == null)
                 | {id: $it.id, title: $it.title, vault: $it.vault.name, tag: $t} ],

      dup_title: [ $all
                   | group_by(.title | ascii_downcase | gsub("^[[:space:]]+|[[:space:]]+$"; ""))
                   | map(select(length > 1))
                   | .[]
                   | {title: .[0].title, count: length,
                      items: map({id, vault: .vault.name, category})} ],

      stale: [ $all[]
               | select((.updated_at | fromdateiso8601) < (now - $staleSecs))
               | slim + {updated_at} ]
    }
')"

# --- deep findings (per-item get; values never printed) --------------------
DEEPJSON='{"weak":[],"no_2fa":[],"no_url":[],"scanned":0}'
if [ "$DEEP" -eq 1 ]; then
  ids="$(printf '%s' "$ITEMS" | jq -r '.[] | select(.category=="LOGIN") | .id')"
  ndjson=""
  scanned=0
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    rec="$(op item get "$id" --format json 2>/dev/null | jq -c '
      {
        id, title, vault: .vault.name,
        weakest: ([ .fields[]? | .password_details.strength // empty ] | unique),
        has_pw:  ([ .fields[]? | select(.purpose=="PASSWORD" and (.value // "") != "") ] | length > 0),
        has_otp: ([ .fields[]? | select(.type=="OTP") ] | length > 0),
        has_url: ((.urls // []) | length > 0),
        has_user: ([ .fields[]? | select(.purpose=="USERNAME" and (.value // "") != "") ] | length > 0)
      }')" || continue
    ndjson+="$rec"$'\n'
    scanned=$((scanned+1))
  done <<< "$ids"

  DEEPJSON="$(printf '%s' "$ndjson" | jq -s --argjson scanned "$scanned" '
    {
      weak:   [ .[] | select(.weakest | any(. == "TERRIBLE" or . == "WEAK" or . == "FAIR"))
                | {id, title, vault, strength: (.weakest | join(","))} ],
      no_2fa: [ .[] | select(.has_pw and (.has_otp | not))
                | {id, title, vault} ],
      no_url: [ .[] | select(.has_pw and (.has_url | not))
                | {id, title, vault} ],
      scanned: $scanned
    }')"
fi

# --- render markdown -------------------------------------------------------
jq -rn \
  --argjson r "$REPORT" \
  --argjson d "$DEEPJSON" \
  --argjson total "$TOTAL" \
  --argjson max "$MAX_LIST" \
  --argjson deep "$DEEP" \
  --arg vault "${VAULT:-all vaults}" \
  --arg staledays "$STALE_DAYS" '
  def cap(arr): (arr | length) as $n
    | (arr[0:$max] | map("    - " + (.title // .from // "?")
        + (if .tag then "  (tag: `" + .tag + "`)" else "" end)
        + (if .from then "  `" + .from + "` -> `" + .to + "`" else "" end)
        + (if .vault then "  _[" + .vault + "]_" else "" end)
        + (if .strength then "  strength: " + .strength else "" end)
        + "  `" + (.id // (.items[0].id) // "") + "`") | join("\n"))
      + (if $n > $max then "\n    - … +" + (($n-$max)|tostring) + " more (truncated)" else "" end);

  "# 1Password vault hygiene — \($vault)\n",
  "Scanned **\($total)** items. Mode: " + (if $deep==1 then "deep" else "fast (metadata only)" end)
    + ". Stale threshold: \($staledays)d. **No changes were made.**\n",

  "## Summary\n",
  "| check | count |",
  "|---|---|",
  "| untagged | \($r.untagged|length) |",
  "| tag remap suggested | \($r.remap|length) |",
  "| bare-domain tag | \($r.bare|length) |",
  "| unknown tag | \($r.unknown|length) |",
  "| duplicate titles | \($r.dup_title|length) |",
  "| stale (>\($staledays)d) | \($r.stale|length) |"
    + (if $deep==1 then "\n| weak password | \($d.weak|length) |\n| login without 2FA | \($d.no_2fa|length) |\n| login without URL | \($d.no_url|length) |" else "" end),
  "",

  (if ($r.untagged|length)>0 then "## Untagged (\($r.untagged|length))\n" + cap($r.untagged) + "\n" else empty end),
  (if ($r.remap|length)>0 then "## Tag remaps suggested (\($r.remap|length))\n" + cap($r.remap) + "\n" else empty end),
  (if ($r.bare|length)>0 then "## Bare-domain tags — need a sub-tag (\($r.bare|length))\n" + cap($r.bare) + "\n" else empty end),
  (if ($r.unknown|length)>0 then "## Unknown tags — not in taxonomy (\($r.unknown|length))\n" + cap($r.unknown) + "\n" else empty end),
  (if ($r.dup_title|length)>0 then "## Duplicate titles (\($r.dup_title|length))\n"
     + ($r.dup_title[0:$max] | map("    - **" + .title + "** ×" + (.count|tostring)) | join("\n")) + "\n" else empty end),
  (if ($r.stale|length)>0 then "## Stale (\($r.stale|length))\n" + cap($r.stale) + "\n" else empty end),

  (if $deep==1 then
     (if ($d.weak|length)>0 then "## Weak passwords (\($d.weak|length))\n" + cap($d.weak) + "\n" else empty end),
     (if ($d.no_2fa|length)>0 then "## Logins without 2FA (\($d.no_2fa|length))\n" + cap($d.no_2fa) + "\n" else empty end),
     (if ($d.no_url|length)>0 then "## Logins without URL (\($d.no_url|length))\n" + cap($d.no_url) + "\n" else empty end)
   else empty end),

  (if ($r.remap|length)>0 then
     "## Proposed fixes (NOT executed)\n",
     "```bash",
     ($r.remap[0:$max] | map("op item edit " + .id + " --tags \"" + .newtags + "\"  # " + .title) | join("\n")),
     "```\n",
     "> Tags are OVERWRITTEN by `op item edit --tags`; the commands above already merge existing tags. Review, then run only after confirmation."
   else empty end)
'
