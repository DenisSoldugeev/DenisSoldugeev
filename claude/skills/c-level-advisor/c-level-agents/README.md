# c-level-agents — Founder-Mode Executive Team

A virtual C-suite for Claude Code. Eight ds-* agents with distinct cognitive voices, seventeen `/ds:*` slash commands, one artifact-driven pipeline.

This plugin is the **surface layer** on top of the 28 c-level skills already in this repo. The skills provide frameworks and Python tools; this plugin adds:

1. **Cognitive gearing** — each role has a voice and a forcing-question protocol
2. **Slash-command invocation** — `/ds:cfo-review`, `/ds:boardroom`, `/ds:founder-mode`
3. **Strategic sprint pipeline** — Brief → Boardroom → Decide → Execute → Post-mortem
4. **Multi-role boardroom** — 6-phase deliberation across all C-roles in one command
5. **Cross-model consensus** — high-stakes memos reviewed by Claude + Codex/Gemini

Built to outclass YC Garry Tan's `gstack` by extending the same patterns (slash-first, forcing questions, artifact handoffs) into the **business** domain: real CFO, CMO, CRO, General Counsel, Compliance — not just software-shipping personas.

## Quick Start

```
/ds:onboard                          # 6-question founder interview → company-context.md
/ds:office-hours <topic>             # YC-style 6-question interrogation
/ds:founder-mode <question>          # auto-routes to the right C-role
/ds:cfo-review <plan>                # numerate skeptic stress-tests unit economics
/ds:boardroom <brief>                # full panel deliberation, 6 phases
/ds:decide <memo>                    # logs decision to two-layer memory
```

## Agent Roster

| Agent | Voice | Wraps Skill |
|---|---|---|
| ds-cfo-advisor | Numerate skeptic — "show me the spreadsheet" | cfo-advisor |
| ds-cmo-advisor | Narrative-first — "what's the story?" | cmo-advisor |
| ds-cro-advisor | Pipeline-paranoid — "where's the coverage?" | cro-advisor |
| ds-cpo-advisor | JTBD-driven — "what job hired this?" | cpo-advisor |
| ds-coo-advisor | Execution OS — "what's the cadence?" | coo-advisor |
| ds-chro-advisor | People-systems — "comp band, ladder, level" | chro-advisor |
| ds-ciso-advisor | Risk-paranoid — "what's the blast radius?" | ciso-advisor |
| ds-chief-of-staff | Router & synthesist — orchestrates boardroom | chief-of-staff |

Existing `ds-ceo-advisor` and `ds-cto-advisor` live in `/agents/c-level/` and integrate seamlessly.

## Slash Command Map

**Forcing-question office hours (8)** — interrogate before advising
- `/ds:office-hours` — 6-question YC-style intake
- `/ds:cfo-review` `/ds:cmo-review` `/ds:cpo-review` `/ds:cro-review`
- `/ds:cto-review` `/ds:ciso-review` `/ds:gc-review`

**Strategic sprint pipeline (5)** — Think → Decide → Ship for business
- `/ds:brief` → `/ds:boardroom` → `/ds:decide` → `/ds:execute` → `/ds:post-mortem`

**Meta + safety (4)**
- `/ds:founder-mode` — auto-routes to the right C-role
- `/ds:onboard` — founder interview, populates `~/.claude/company-context.md`
- `/ds:cross-eval` — multi-model consensus (Claude + Codex/Gemini, graceful degradation)
- `/ds:freeze` — locks a strategic decision for cooldown period

## Design Principles

- **Voice is bookended, analysis is neutral.** Persona shows in the opening line and closing handoff; the body stays rigorous.
- **Artifacts over chat.** Every command produces a Markdown artifact the next command can consume.
- **Two-layer memory.** Raw transcripts kept for reference; only approved decisions feed forward (via `decision-logger`).
- **Phase 2 isolation.** In `/ds:boardroom`, each role thinks independently before cross-examination.
- **Graceful degradation.** `/ds:cross-eval` falls back to Claude-only if no other models are configured.

## References

- [persona-voices.md](references/persona-voices.md) — voice spec for each role
- [llm-wiki-bridge.md](references/llm-wiki-bridge.md) — point company-context at an llm-wiki vault
- [Parent CLAUDE.md](../CLAUDE.md) — c-level domain guide
- [executive-mentor sibling](../executive-mentor/) — `/em:*` adversarial commands

## What's Different vs `gstack`

| | gstack | c-level-agents |
|---|---|---|
| Roles | ~6 software-shipping personas | 10 real C-suite roles + General Counsel lane |
| Domain | Code shipping only | Business + compliance + GTM + finance + product |
| Frameworks | Scope cut, sprint pipeline | RICE, JTBD, OKR, Wardley, ADKAR, 8-dim org health |
| Memory | Postgres + pgvector (separate repo) | Markdown via llm-wiki bridge (stdlib-only) |
| Voice | Default Claude voice | Per-role cognitive style |
| Compliance | None | ra-qm-team integration (ISO/MDR/FDA/GDPR) |
| Boardroom | Sequential review chain | 6-phase deliberation with isolation |

---

**Version:** 2.9.0
**Status:** Production Ready
**License:** MIT
