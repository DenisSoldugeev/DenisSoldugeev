---
name: "brief"
description: "/ds:brief <topic> — Generate a one-page strategy brief from an office-hours intake. First step in the strategic sprint pipeline."
---

# /ds:brief — One-Page Strategy Brief

**Command:** `/ds:brief <topic>` or `/ds:brief <office-hours-output>`

Turns intake (raw question or office-hours output) into a one-page strategy brief that the boardroom can deliberate on. This is **Step 1** of the strategic sprint pipeline.

## Pipeline Position

```
/ds:office-hours  →  /ds:brief  →  /ds:boardroom  →  /ds:decide  →  /ds:execute  →  /ds:post-mortem
                       ↑ you are here
```

## Inputs

- A topic string, **or**
- An office-hours brief (preferred — more rigor)
- `~/.claude/company-context.md` (loaded automatically)

## Output

A single Markdown file under `~/.claude/briefs/YYYY-MM-DD-<slug>.md` with this structure:

```markdown
# Strategy Brief: <topic>
**Date:** YYYY-MM-DD
**Author:** ds-chief-of-staff
**Status:** DRAFT | UNDER REVIEW | APPROVED | RETIRED

## Context
[1-2 paragraphs: where the company sits today on this topic — pulled from company-context.md]

## Question
[The one sentence question the boardroom must answer]

## Options
1. **Option A:** <name> — <one-sentence summary>
2. **Option B:** <name> — <one-sentence summary>
3. **Option C:** <name> — <one-sentence summary>

(Minimum 2 options. "Do nothing" is always an option.)

## Assumptions
- <assumption 1 — explicit>
- <assumption 2>
- <assumption 3>

## Constraints
- Time: <by when must this decide>
- Money: <budget envelope>
- People: <who can / can't be reallocated>
- Reversibility: <one-way door | two-way door>

## Affected Roles
[Which ds-* advisors should weigh in. Used to route to /ds:boardroom panel composition.]

- [ ] ds-ceo-advisor
- [ ] ds-cfo-advisor
- [ ] ds-cto-advisor
- [ ] ds-cmo-advisor
- [ ] ds-cro-advisor
- [ ] ds-cpo-advisor
- [ ] ds-coo-advisor
- [ ] ds-chro-advisor
- [ ] ds-ciso-advisor
- [ ] ds-chief-of-staff

## Success Criteria
[Measurable outcomes that define success — set BEFORE the decision]
- <metric 1, threshold, timeframe>
- <metric 2, threshold, timeframe>

## Kill Criteria
[What signal would tell you in 90 days that this was the wrong call]
- <metric, threshold, action if missed>
```

## Workflow

1. Load company-context.md via context-engine
2. If input is office-hours output, parse the 6 answers
3. If input is a raw topic, prompt the founder for the missing pieces
4. Draft 2-3 options (never just one — every brief needs a counterfactual)
5. Make assumptions and constraints explicit
6. Identify affected roles → drives panel composition for `/ds:boardroom`
7. Write success + kill criteria BEFORE the decision (this is the rigor moment)
8. Save to `~/.claude/briefs/`

## Why This Step Exists

The biggest decision-making failure is debating implementation before agreeing on the question. The brief locks the question, options, and success criteria so the boardroom can deliberate without scope creep.

This is also the **artifact handoff** — the next command consumes this file, not your memory.

## Routing

- `/ds:boardroom <brief>` — multi-role deliberation
- `/ds:cross-eval <brief>` — multi-model sanity check before boardroom (for high-stakes)
- `/ds:freeze <brief>` — cooldown lock for irreversible decisions

## Related

- Agent: [`ds-chief-of-staff`](../../agents/ds-chief-of-staff.md)
- Skills: [`context-engine`](../../../context-engine/SKILL.md), [`board-meeting`](../../../board-meeting/SKILL.md)

---

**Version:** 1.0.0
