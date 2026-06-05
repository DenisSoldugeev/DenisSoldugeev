---
name: onepassword
description: >-
  Work with 1Password — vault hygiene and Environments. Use when the user wants
  to audit or clean up 1Password vaults/сейфы (untagged items, tag-taxonomy
  violations, duplicates, weak passwords, missing 2FA, stale logins, reused
  passwords) via the `op` CLI, OR manage 1Password Environments and local `.env`
  secrets via the 1Password MCP server (list/create/rename environments, list/
  append variables, sync `.env` files, check env-var drift). Triggers on:
  "1Password", "1password", "op cli", "сейф/vault hygiene", "watchtower",
  "теги паролей", "untagged secrets", "reused/weak passwords", "1password
  environments", ".env secrets". Read-only audit first; changes only after the
  user confirms.
metadata:
  short-description: 1Password vault hygiene (op CLI) + Environments (MCP)
---

# 1Password

Two **separate engines** behind one skill. Route to the right one — they do not
overlap:

| If the user wants… | Engine | Tool | Reference |
|---|---|---|---|
| audit / clean **vault items** (tags, weak/reused pw, 2FA, duplicates, stale) | `op` CLI | `scripts/*.sh` | `references/vault-hygiene.md` |
| manage **Environments** / `.env` secrets, env-var drift | 1Password **MCP** | `mcp__1password__*` | `references/environments.md` |

**Critical:** the 1Password MCP server **cannot read or audit vault items** — it
only manages Environments. Anything about сейфы / passwords / tags / Watchtower
goes through the `op` CLI. If the user says "use the MCP to clean my vault",
correct them: that's a CLI job.

## Hard rules (both engines)

- **Read-only first.** Always audit and present a report before any change.
- **Mode = audit + fix on confirmation.** Never mutate without an explicit OK
  from the user for the specific change. Show the exact commands first.
- **Secret values never enter context.** CLI reads strength labels / field
  shape, not values; reuse is hashed locally. MCP never returns values.
- **`op item edit --tags` overwrites** — always pass the full merged tag list
  (`audit.sh` emits merged commands).
- **Archive, don't delete** (`op item delete ID --archive`) for stale/dup items.
- SSH keys, SSO logins, license `key` items → **GUI only** (CLI can't edit tags).

## Vault hygiene — quick start

```bash
# fast audit (metadata only) — all vaults
scripts/audit.sh

# one vault, custom staleness, deep checks (weak pw / 2FA / no-URL)
scripts/audit.sh --vault Personal --stale-days 365 --deep

# reused-password scan (heavy; values hashed locally, never printed)
scripts/reuse-check.sh --vault Personal
```

Then: present the report → for fixable buckets show the `op item edit` commands
→ **get confirmation** → run them → re-run `audit.sh` to verify counts dropped.

Taxonomy of allowed tags lives in `assets/taxonomy.txt` (edit it as the schema
evolves; supports `#remap A -> B` lines). See `references/vault-hygiene.md`.

## Environments — quick start

Use the MCP tools (`mcp__1password__list_environments`, `list_variables`,
`append_variables`, `rename_environment`, `create_local_env_file`,
`list_local_env_files`). No delete/update-value tool — those are app-only.
Hygiene = naming consistency, variable-set drift across stages, orphan `.env`
mounts, empty environments. See `references/environments.md`.

## Optional automation

Pair `scripts/audit.sh` with the harness `/schedule` or `/loop` to run a weekly
hygiene report; keep the fix step interactive.
