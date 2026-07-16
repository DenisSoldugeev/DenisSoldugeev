# 1Password Environments — MCP engine

Engine for managing 1Password **Environments** (secrets organized per
project/stage, injected into local `.env` files). This is what the official
local 1Password MCP server actually does. It does **not** touch vault items,
tags, or Watchtower — for that, see `vault-hygiene.md` (`op` CLI).

Docs: <https://www.1password.dev/environments/> ·
local `.env`: <https://www.1password.dev/environments/local-env-file/>

## Security model

- The MCP server **never returns secret values** into the model context — only
  variable names and `op://…` references are visible.
- Every mutating action requires a **native approval prompt** in 1Password.
- Read the server's `getting-started` and `environments-guide` resources first
  (via the MCP resource tools) when unsure of exact semantics.

## Available MCP tools

| tool | purpose |
|---|---|
| `mcp__1password__authenticate` | establish/refresh the MCP session |
| `mcp__1password__list_environments` | list Environments |
| `mcp__1password__create_environment` | create a new Environment |
| `mcp__1password__rename_environment` | rename an Environment |
| `mcp__1password__list_variables` | list variable names in an Environment (no values) |
| `mcp__1password__append_variables` | add variables to an Environment |
| `mcp__1password__create_local_env_file` | register a local `.env` mount target |
| `mcp__1password__list_local_env_files` | list registered local `.env` files |

Note: there is **no delete-environment** and **no update-value** tool. To remove
an Environment or change a value, use the 1Password app.

## Environments hygiene (what "чистота" means here)

Since values are invisible, hygiene is about structure, not strength:

- **Naming consistency** — environments follow one convention
  (e.g. `<project>-<stage>`: `mondo-prod`, `mondo-staging`).
- **Variable-set drift** — the same project's `prod` / `staging` / `dev`
  expose the same variable *names*; flag a var present in one stage but missing
  in another (`list_variables` diff).
- **Orphan `.env` mounts** — `list_local_env_files` entries pointing at paths
  that no longer exist or no longer map to a live Environment.
- **Empty environments** — created but with zero variables.

There is no script for this (the MCP has no bulk export); do it interactively:
`list_environments` → for each, `list_variables` → diff names across stages →
report gaps. Mutations (`append_variables`, `rename_environment`) only after
the user confirms, and each still needs the native 1Password approval.

## Workflow (mode: audit + fix on confirmation)

1. `authenticate` if needed.
2. `list_environments`; for each candidate, `list_variables`.
3. Diff names across stages of the same project → report missing/extra.
4. `list_local_env_files` → flag orphans.
5. Present findings. **Ask before** `append_variables` / `rename_environment`.
   Deletions and value edits → tell the user to do them in the app.
