# Claude Code — agents, commands & skills

A curated set of [Claude Code](https://docs.claude.com/en/docs/claude-code) agents, slash-commands and skills.

## Attribution

This collection is essentially a fork of and derived from
**[alirezarezvani/claude-skills](https://github.com/alirezarezvani/claude-skills)** — full credit to the upstream
author. This copy is reorganized and rebranded for personal use; the original repository remains the source of truth.

## What changed from upstream

- The `cs-` / `/cs:` branding prefix was renamed to `ds-` / `/ds:` across agents, commands and skills.
  Genuine domain terms (e.g. customer-success `cs-playbooks`, `cs-coverage-model`) were left intact.
- Internal cross-reference paths were repaired where the target exists in this layout.
- The `onepassword` skill is **not** included here — it lives in the personal `dotfiles` repo (it carries a
  git-ignored local override).

## Layout

```
claude/
├── agents/     # subagent definitions (frontmatter `name:` = subagent_type)
├── commands/   # slash-command playbooks
└── skills/     # skill bundles (SKILL.md + references/scripts/assets)
```

## Install

Symlink (or copy) the directories into your global Claude Code config:

```bash
ln -s "$PWD/claude/agents"   ~/.claude/agents
ln -s "$PWD/claude/commands" ~/.claude/commands
ln -s "$PWD/claude/skills"   ~/.claude/skills
```

> Some internal "Related"/"See also" doc links point to upstream content that is not part of this subset
> (per-bundle `CLAUDE.md`, `*-megaprompt.md`, etc.) — see the upstream repo for the full set.
