# Secret injection & item CRUD — `op` CLI engine

Engine for **using** secrets in day-to-day dev work: inject them into a process,
read one value, or create/edit/archive an item. Same CLI as `vault-hygiene.md`,
different intent (hygiene = audit; this = operate). The 1Password **MCP** server
does none of this — it only manages Environments (`environments.md`).

Docs: secret references <https://developer.1password.com/docs/cli/secret-references/> ·
`op run` <https://developer.1password.com/docs/cli/reference/commands/run/>

## Golden rule: inject, don't export

Prefer **`op run`** over `export FOO=$(op read …)`. `op run` keeps secrets
ephemeral (they exist only for the child process), auto-masks them in output,
and never lands them in shell history or a persisted env var.

```bash
# GOOD — secret lives only for the command, masked in logs
op run --env-file=.env -- npm run dev
op run -- ./deploy.sh

# AVOID — plaintext in the shell env + history
export OPENAI_KEY=$(op read "op://Dev/OpenAI/api-key")
```

Use `op read` for a **single** value in a one-off pipe; still avoid assigning it
to a long-lived variable:

```bash
curl -H "Authorization: Bearer $(op read 'op://Dev/OpenAI/api-key')" https://…
```

`--no-masking` disables the concealment — only use it when you must see the value
and understand it will appear in the terminal.

## Secret reference syntax

URI form: `op://<vault>/<item>/[section/]<field>`

```
op://Dev/OpenAI/api-key            # field on an item
op://Personal/GitHub/password      # login password
op://Dev/Database/creds/password   # field inside a section
```

Get the canonical reference for a field without printing its value:

```bash
op item get "OpenAI" --vault Dev --fields api-key --format json | jq -r '.reference'
```

## `.env` with references (not values)

Commit the **references**, never the values. `.env` holds `op://…`; `op run`
resolves them at launch:

```dotenv
# .env  — safe to keep in the repo (contains references, not secrets)
DATABASE_URL="op://Dev/postgres/connection-string"
ANTHROPIC_API_KEY="op://Dev/Anthropic/api-key"
```

```bash
op run --env-file=.env -- python app.py
```

Environment switch via a shell var inside the reference:

```dotenv
DB_PASSWORD="op://$APP_ENV/database/password"
```

```bash
APP_ENV=prod op run --env-file=.env -- ./start.sh
```

## Authentication

Three ways, pick by context:

| Method | When | Setup |
|---|---|---|
| **Desktop-app integration** (biometric) | interactive dev on this Mac — the default here | 1Password app → Settings → Developer → *Integrate with 1Password CLI*. `op whoami` fails but `op vault list` works. |
| **Service-account token** | CI/CD, headless, automation | `export OP_SERVICE_ACCOUNT_TOKEN="ops_…"` (create in 1Password.com → Developer → Service Accounts; scope to only the needed vaults). |
| **Manual signin** | legacy / no desktop app | `eval $(op signin)` (or `--account <team>.1password.com`). |

Troubleshooting: `account is not signed in` → re-run `eval $(op signin)` or set
the service-account token. `op: not reachable` in scripts → enable desktop
integration or sign in.

## Item CRUD (mutating — confirm first)

Read-only inspection is free; **any create/edit/delete needs the user's OK**
(same rule as vault hygiene). Show the exact command before running it.

```bash
# create an API credential
op item create --category "API Credential" --title "My API Key" \
  --vault Dev --fields "api-key=sk-…"

# edit a field
op item edit "My API Key" --vault Dev "api-key=sk-new…"

# archive (reversible) — prefer over delete
op item delete "Old API Key" --vault Dev --archive
```

Note: `op item edit --tags` **overwrites** the whole tag list — see
`vault-hygiene.md`. SSH keys, SSO logins, license `key` items → GUI only.
