# The Read — Prompt v1.1
 
**File version:** 1.1
**Schema version:** matches `TheReadEngine.classifierInstructions`, `TheReadEngine.bodyGeneratorInstructions(kind:)`, and `TheReadEngine.weeklyInstructions` in `Plenty/Features/Home/TheRead/TheReadEngine.swift`.
**Last updated:** Phase 7
 
## Changes since v1.0
- Added `.weekly` kind for the Sunday Read notification
- Added Stage 4 (weekly generation) below; Stages 1-3 unchanged
- Updated kind table to include weekly
- Added weekly deterministic templates
This document is the canonical prompt source for The Read. Engineering loads the equivalent strings from `TheReadEngine.swift` at runtime; both copies must stay in sync. When you edit this file, edit `TheReadEngine.swift` to match in the same commit.
 
---
 
## What is The Read
 
The Read is contextual sentence content surfaced to the user. Two delivery channels:
 
1. **Inline (daily)** — a single sentence beneath the hero number on Home. Six possible kinds: silence, paceWarning, paceTrend, billReminder, incomeReminder, milestone.
2. **Notification (weekly)** — the Sunday Read. 1-3 sentences delivered as a notification on Sunday at 9am. One kind: weekly.
Both channels share architecture (classifier + generator + validator + cache + deterministic fallback) and the same restraint policy. When there's nothing meaningful to say, say nothing.
 
---
 
## The seven kinds
 
| Kind | Channel | When | Example body |
|---|---|---|---|
| `silence` | Inline | Nothing distinctive to surface, or no data yet. | (no body shown) |
| `paceWarning` | Inline | Burn rate is above the sustainable per-day rate. | "Your spending sits at $58 a day. To finish the month with margin, $42 a day is the line." |
| `paceTrend` | Inline | Burn rate is meaningfully below sustainable. | "You're tracking under your usual pace at $28 a day. The room is there if you want it." |
| `billReminder` | Inline | Unpaid bills this month deserve a heads-up. | "Three bills are still unpaid this month, totaling $1,240." |
| `incomeReminder` | Inline | A paycheck is arriving in the next day or two. | "Your next paycheck arrives Friday." |
| `milestone` | Inline | Positive savings progress this month. | "You've added $300 toward your savings this month." |
| `weekly` | Notification | Sunday morning at 9am. | "You have $1,840 spendable through the rest of the month. 2 bills are still to pay totaling $640. Saved $300 so far." |
 
---
 
## Stage 1: Classifier (inline kinds only)
 
The classifier picks one of the six inline kinds. Weekly is not classified — it has its own generator that runs on a weekly cache schedule.
 
(See v1.0 for full classifier instructions; unchanged in v1.1.)
 
---
 
## Stage 2: Body Generator (inline kinds only)
 
(See v1.0 for full body generator instructions; unchanged in v1.1.)
 
---
 
## Stage 3: Validator (both channels)
 
Validates that mentioned amounts are within $1 of snapshot values and mentioned dates match snapshot dates by calendar day. Weekly skips date validation (1-3 sentence summaries don't typically reference specific dates) but still validates amounts when present.
 
---
 
## Stage 4: Weekly Generator (Phase 7)
 
Produces the Sunday Read. Single-pass generation with a constrained @Generable output: body (1-3 sentences) and primaryAmount (the most prominent dollar value).
 
### Instructions sent to the model
 
```
You are writing the Sunday Read, a calm weekly digest delivered as a
notification on Sunday mornings. Compose 1-3 short sentences that
summarize where the user stands financially right now.
 
Voice:
• Second person ("you have", "your bills", "your savings")
• Possession-leading ("you have $1,840" not "$1,840 is available")
• Calm and direct, no exclamations
• No em-dashes, no bullet points, no emojis, no marketing language
• Plain currency like "$1,840"
• Each sentence complete and self-contained
• Total length 1-3 sentences, never more
 
Content priorities (in order):
1. Spendable status — how much is available, or whether the user is over
2. Bills situation — count and total of unpaid bills, or "all paid"
3. Savings progress — amount saved this month, if any
 
Skip anything that doesn't apply. If the user has no meaningful financial
activity (zone=empty), return an empty body.
 
If you mention a dollar amount, set primaryAmount to the most prominent
one for validation.
```
 
The user message that follows contains the snapshot summary and the directive `Write the Sunday Read.`
 
### Validation
 
Same validator as inline kinds. The prominent amount must match a snapshot value within $1. Unlike inline, weekly does not retry on validation failure — it falls back to deterministic templates immediately. Weekly is not time-critical (runs in advance of Sunday's notification), so retry latency would only add cache time, not user-facing wait.
 
### Deterministic fallback templates
 
When AI is unavailable or output failed validation, the deterministic generator composes from snapshot fields in priority order:
 
1. Spendable line: `"You have ${spendable} spendable through the rest of the month."` or `"You're ${over} past your margin this month."`
2. Bills line (if any unpaid): `"${count} bill(s) are still to pay totaling ${total}."` or `"Every bill for the month is squared away."` (if some paid, none unpaid)
3. Savings line (if any contributed this month): `"Saved ${amount} so far."`
Returns silence (empty body, kind=.silence) if zone is empty.
 
---
 
## Versioning policy
 
(Unchanged from v1.0.)
 
- **Major (2.0)** — adds or removes a delivery channel, restructures stages, changes voice substantively
- **Minor (1.1)** — adds a kind, refines per-kind guidance, adds examples
- **Patch (1.0.1)** — fixes typos, clarifies wording without behavioral change
