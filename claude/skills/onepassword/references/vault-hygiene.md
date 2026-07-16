# Vault hygiene — `op` CLI engine

Engine for "чистота сейфов". Uses the 1Password CLI (`op`, desktop-app
integration). **The 1Password MCP server cannot do any of this** — it only
manages Environments (see `environments.md`).

## Safety invariants

- **Password values never enter the model context.** Strength is read from
  `password_details.strength` (a label, not the value); 2FA from field
  `type=="OTP"`; reuse via local hashing in `reuse-check.sh`.
- **Audit is read-only.** Edits happen only after the user confirms, then via
  explicit `op item edit` calls.
- **`op item edit --tags` OVERWRITES tags** — never pass a partial list. Always
  merge: new = (existing tags with remap applied) | unique. `audit.sh` already
  emits correctly-merged commands under "Proposed fixes".
- **SSH keys, SSO logins (`ssoLogin` field), and license `key` items are not
  editable via CLI** — tag/fix those in the 1Password GUI. Expect a residual
  set of untagged items that CLI cannot touch.

## Connectivity

`op` here uses desktop-app integration (biometric per call), not a shell
session — so `op whoami` fails while `op vault list` works. Scripts guard on
`op vault list`. Account: `den.soldugeev@yandex.ru`. Vaults: `Dev`, `Personal`.

## The audit script

```bash
scripts/audit.sh [--vault NAME] [--stale-days N] [--deep] [--max-list N]
```

Fast mode (default, metadata only, one `op item list`): untagged, tag remaps,
bare-domain tags, unknown tags, duplicate titles, stale items.

`--deep` (one `op item get` per login, values dropped by jq): weak passwords,
logins without 2FA, logins without URL.

Checks and what they mean:

| check | meaning | fixable via CLI? |
|---|---|---|
| untagged | item has zero tags | yes (logins), no (SSH/SSO/key) |
| tag remap | tag matches a `#remap A -> B` rule in taxonomy | yes |
| bare-domain | tag is a top domain (`work`, `dev`) lacking a sub-tag | yes — pick a sub-tag |
| unknown tag | tag not in `assets/taxonomy.txt` | yes — fix tag or extend taxonomy |
| duplicate titles | ≥2 items share a normalized title | manual — merge/archive |
| stale | `updated_at` older than `--stale-days` | manual — review/rotate/archive |
| weak password | `strength` ∈ {TERRIBLE, WEAK, FAIR} | rotate in app |
| no 2FA | has password, no OTP field | add TOTP |
| no URL | has password, no URL (autofill won't work) | add URL |

## Taxonomy

The tag allowlist (one tag per line). Precedence, highest first:

1. `$ONEP_TAXONOMY` — explicit path override.
2. `assets/taxonomy.local.txt` — **your personal taxonomy, gitignored.** Put
   employer / client / location-specific tags here so they never get committed.
3. `assets/taxonomy.txt` — generic starter set committed to the repo.

`audit.sh` picks the first that applies. Two machine-read forms in any of them:

- normal line → an allowed tag (e.g. `work/email`).
- `#remap A -> B` → propose rewriting tag `A` to `B` (known typo / misfiling).

A top-level domain that owns any sub-tag (e.g. `work` owns `work/email`) is
auto-treated as "must not appear bare".

To start your own: `cp assets/taxonomy.txt assets/taxonomy.local.txt` and edit.

## Remediation workflow (mode: audit + fix on confirmation)

1. Run `audit.sh` → present the markdown report.
2. For each fixable bucket, show the exact `op item edit` commands.
3. **Ask for confirmation.** Only then execute.
4. Re-run `audit.sh` to confirm the count dropped.

Tag-merge edit (safe pattern):

```bash
# existing tags come from `op item get ID --format json | jq -c '.tags'`
op item edit ID --tags "tagA,tagB,tagC"   # full merged list, comma-separated
```

Archive (reversible) instead of delete for stale/duplicate items:

```bash
op item delete ID --archive
```

## Reuse check (opt-in, heaviest)

```bash
scripts/reuse-check.sh [--vault NAME]
```

Reads every login's password, hashes it locally with a per-run salt, prints
only the buckets of items that share a password (titles + ids, never values).
Triggers one secret read per login (native approvals possible). Run
deliberately. Rotate shared passwords in the app.

## Optional: schedule it

Pair with the harness `/schedule` or `/loop` to run `audit.sh` weekly and
surface the report. The skill itself stays interactive for the fix step.
