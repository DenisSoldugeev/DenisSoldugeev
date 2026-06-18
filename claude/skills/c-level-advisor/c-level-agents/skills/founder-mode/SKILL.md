---
name: "founder-mode"
description: "/ds:founder-mode <question> — Auto-routes any founder question to the right C-role advisor or to /ds:boardroom for multi-role topics. The single-command entry point."
---

# /ds:founder-mode — The Auto-Router

**Command:** `/ds:founder-mode <question>`

The single command a founder needs to remember. Routes the question to the right C-role automatically, or triggers `/ds:boardroom` if multi-role.

This is the **killer command** — the answer to "I don't know which slash command to use." Type the question; the system figures out the room.

## Routing Logic

The router (via `ds-chief-of-staff`) does keyword + intent matching:

| Signal in question | Route |
|---|---|
| burn, runway, fundraise, dilution, model, LTV, CAC | `ds-cfo-advisor` |
| pipeline, win rate, forecast, NRR, churn, ramp | `ds-cro-advisor` |
| positioning, ICP, message, brand, channel, campaign | `ds-cmo-advisor` |
| roadmap, PMF, JTBD, North Star, RICE, kill | `ds-cpo-advisor` |
| cadence, OKR, scorecard, DRI, operating system, rhythm | `ds-coo-advisor` |
| hiring, comp, ladder, level, attrition, eNPS, equity | `ds-chro-advisor` |
| security, threat, breach, compliance, audit, SOC 2 | `ds-ciso-advisor` |
| architecture, scaling, tech debt, SLO, latency | `ds-cto-advisor` |
| contract, IP, term sheet, regulator, license | `/ds:gc-review` |
| strategy, vision, board, M&A, raise, exit | `ds-ceo-advisor` |
| **2+ signals from different roles** | `/ds:boardroom` |
| **ambiguous** | `/ds:office-hours` first, then route |

## Workflow

1. Parse the question for role signals
2. If exactly one role: invoke that ds-* agent directly
3. If 2+ roles: build a brief via `/ds:brief` and trigger `/ds:boardroom`
4. If ambiguous / no signal match: trigger `/ds:office-hours` to force the founder to sharpen
5. Log the routing decision (raw layer) via `decision-logger`

## Output

The router emits one of three responses:

### Single-role route
```
**Routing:** ds-cfo-advisor
**Why:** Question hits burn rate and unit economics.
**Next:** Invoking ds-cfo-advisor with company-context loaded.

[Advisor's response follows]
```

### Multi-role route
```
**Routing:** /ds:boardroom
**Why:** Question touches CFO + CMO + CPO (pricing change has finance, positioning, and product implications).
**Next:** Building brief via /ds:brief, then running boardroom.

Brief saved: ~/.claude/briefs/2026-05-12-pricing-v3.md
Run: /ds:boardroom ~/.claude/briefs/2026-05-12-pricing-v3.md
```

### Ambiguous → office hours
```
**Routing:** /ds:office-hours
**Why:** Question is too broad ("should we grow faster?"). Need framing before any advisor can help.
**Next:** Six-question intake.

[Office hours questions follow]
```

## Why This Is the Killer Command

gstack requires the founder to know all 23 slash commands and pick the right one. That's a cognitive tax. `/ds:founder-mode` collapses that to one — the system picks. This is also where persistent memory pays off: with company-context.md + decision-logger, the router knows what's already been decided and won't re-litigate.

## Examples

```
/ds:founder-mode "should we raise a Series B now or wait 6 months?"
   → boardroom (CFO + CEO + CRO touched)

/ds:founder-mode "the win rate dropped 20% this month"
   → ds-cro-advisor

/ds:founder-mode "let's hire a VP Marketing"
   → boardroom (CHRO + CMO + CFO touched)

/ds:founder-mode "should we be growing faster?"
   → /ds:office-hours (too ambiguous)
```

## Related

- Agent: [`ds-chief-of-staff`](../../agents/ds-chief-of-staff.md) — does the routing
- Skill: [`chief-of-staff`](../../../chief-of-staff/SKILL.md) — routing logic
- Skill: [`context-engine`](../../../context-engine/SKILL.md) — loads context

---

**Version:** 1.0.0
