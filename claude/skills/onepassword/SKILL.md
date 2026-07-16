---
name: onepassword
description: >-
  Work with 1Password — vault hygiene, secret injection, and Environments. Use
  when the user wants to audit or clean up 1Password vaults/сейфы (untagged
  items, tag-taxonomy violations, duplicates, weak passwords, missing 2FA, stale
  logins, reused passwords) via the `op` CLI; OR inject secrets into a dev
  environment / run a command with secrets (`op run`, `op read`, `op://`
  references, `.env` files, service accounts, item create/edit); OR manage
  1Password Environments and local `.env` secrets via the 1Password MCP server
  (list/create/rename environments, list/append variables, sync `.env` files,
  check env-var drift). Triggers on: "1Password", "1password", "op cli",
  "op run", "op read", "inject secrets", "api key from 1password", "secret
  reference", "сейф/vault hygiene", "watchtower", "теги паролей", "untagged
  secrets", "reused/weak passwords", "1password environments", ".env secrets".
  Read-only first; changes only after the user confirms.
metadata:
  short-description: 1Password vault hygiene + secret injection (op CLI) + Environments (MCP)
---

# 1Password

Three **engines** behind one skill. Route to the right one — they do not
overlap:

| If the user wants… | Engine | Tool | Reference |
|---|---|---|---|
| audit / clean **vault items** (tags, weak/reused pw, 2FA, duplicates, stale) | `op` CLI | `scripts/*.sh` | `references/vault-hygiene.md` |
| **inject / use secrets** — run a command with secrets, read a value, `.env`, create/edit items | `op` CLI | `op run` / `op read` / `op item` | `references/secret-injection.md` |
| manage **Environments** / `.env` secrets, env-var drift | 1Password **MCP** | `mcp__1password__*` | `references/environments.md` |

**Critical:** the 1Password MCP server **cannot read or audit vault items** — it
only manages Environments. Anything about сейфы / passwords / tags / Watchtower /
injecting a secret goes through the `op` CLI. If the user says "use the MCP to
clean my vault" or "read a secret via the MCP", correct them: that's a CLI job.

## Hard rules (all engines)

- **Read-only first.** Always audit and present a report before any change.
- **Mode = audit + fix on confirmation.** Never mutate without an explicit OK
  from the user for the specific change. Show the exact commands first.
- **Secret values never enter context.** CLI reads strength labels / field
  shape, not values; reuse is hashed locally. MCP never returns values. When
  injecting, prefer `op run` (secrets stay ephemeral + masked) over
  `export FOO=$(op read …)` (plaintext in shell + history).
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

Taxonomy of allowed tags: `assets/taxonomy.txt` is a generic starter; put your
personal tags in `assets/taxonomy.local.txt` (gitignored — `audit.sh` prefers
it). Supports `#remap A -> B`. See `references/vault-hygiene.md`.

## Secret injection — quick start

Inject, don't export. Secrets stay ephemeral and masked with `op run`:

```bash
# run a command with .env secret references resolved at launch
op run --env-file=.env -- npm run dev

# one-off single value in a pipe (avoid assigning to a long-lived var)
curl -H "Authorization: Bearer $(op read 'op://Dev/OpenAI/api-key')" https://…
```

`.env` holds `op://vault/item/field` **references, not values** — safe to keep in
the repo. Auth = desktop-app integration here; service-account token for CI.
Item create/edit/archive is mutating → confirm first. See
`references/secret-injection.md`.

## Environments — quick start

Use the MCP tools (`mcp__1password__list_environments`, `list_variables`,
`append_variables`, `rename_environment`, `create_local_env_file`,
`list_local_env_files`). No delete/update-value tool — those are app-only.
Hygiene = naming consistency, variable-set drift across stages, orphan `.env`
mounts, empty environments. See `references/environments.md`.

## Optional automation

Pair `scripts/audit.sh` with the harness `/schedule` or `/loop` to run a weekly
hygiene report; keep the fix step interactive.
