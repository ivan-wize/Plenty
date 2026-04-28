# The Read — Prompt v2.0

**File version:** 2.0
**Schema version:** matches `TheReadEngine.classifierInstructions`, `TheReadEngine.bodyGeneratorInstructions(kind:)`, and `TheReadEngine.weeklyInstructions` in `Plenty/Features/Overview/TheRead/TheReadEngine.swift`.
**Last updated:** Phase 7 (v2)

## Changes since v1.1

- Hero vocabulary changes from `spendable` to `monthlyBudgetRemaining`. The Read no longer says "spendable" or "margin" — it says "left" and "over your budget."
- `paceWarning` and `paceTrend` bodies fold in `BurnRate.monthEndProjection` when the month is at least five days in. Pace messaging is now grounded in a concrete projected outcome, not just a per-day rate.
- Snapshot summary now leads with `monthlyBudgetRemaining`, includes `monthEndProjection` when available, and adds calendar-derived `day` and `daysRemainingInMonth` so the model can reason about timing.
- Deterministic classifier prefers `paceWarning` whenever `monthlyBudgetRemaining < 0`, even when `pace` is on-track. Being over budget is the strongest signal.

This document is the canonical prompt source for The Read. Engineering loads the equivalent strings from `TheReadEngine.swift` at runtime; both copies must stay in sync. When you edit this file, edit `TheReadEngine.swift` to match in the same commit.

---

## What is The Read

The Read is contextual sentence content surfaced to the user. Two delivery channels:

1. **Inline (daily)** — a single sentence beneath the hero number on Overview. Six possible kinds: silence, paceWarning, paceTrend, billReminder, incomeReminder, milestone.
2. **Notification (weekly)** — the Sunday Read. 1-3 sentences delivered as a notification on Sunday at 9am. One kind: weekly.

Both channels share architecture (classifier + generator + validator + cache + deterministic fallback) and the same restraint policy. When there's nothing meaningful to say, say nothing.

---

## The seven kinds

| Kind | Channel | When | Example body |
|---|---|---|---|
| `silence` | Inline | Nothing distinctive to surface, or no data yet. | (no body shown) |
| `paceWarning` | Inline | `monthlyBudgetRemaining < 0` OR burn rate above sustainable. | "You're spending about $58 a day; at this pace you'll be about $200 over by month-end." |
| `paceTrend` | Inline | Burn rate is meaningfully below sustainable. | "You're tracking under at $28 a day; at this pace you'll end the month with about $400 left." |
| `billReminder` | Inline | Unpaid bills this month deserve a heads-up. | "Three bills are still unpaid this month, totaling $1,240." |
| `incomeReminder` | Inline | A paycheck is arriving in the next day or two. | "Your next paycheck arrives Friday." |
| `milestone` | Inline | Positive savings progress this month. | "You've added $300 toward your savings this month." |
| `weekly` | Notification | Sunday morning at 9am. | "You have $1,840 left for the rest of the month. 2 bills are still to pay totaling $640. Saved $300 so far." |

---

## Voice rules (apply to all kinds)

- One sentence for inline kinds. 1-3 sentences for weekly. No exclamations.
- Second person ("you have," "your bills").
- Possession-leading where natural ("you have $1,840 left" not "$1,840 is available").
- No em-dashes, no bullet points, no marketing language, no emojis.
- Plain currency like $1,840 (no decimals on whole dollars).
- Calm and direct. Calm matters more than clever.

---

## Stage 1: Classifier (inline kinds only)

The classifier picks one of the six inline kinds. Weekly is not classified — it has its own generator that runs on a weekly cache schedule.

### Priority logic

1. If the user has no data at all, return `silence`.
2. If `monthlyBudgetRemaining < 0`, prefer `paceWarning`.
3. If `pace == .over`, prefer `paceWarning`.
4. If unpaid bills exist, consider `billReminder`.
5. If next paycheck is within 1 day, consider `incomeReminder`.
6. If pace is on-track and well below sustainable, consider `paceTrend`.
7. If savings have been logged this month, consider `milestone`.
8. Otherwise return `silence`. **Restraint matters more than coverage.**

### Instructions sent to the model

```
You are a classifier for "The Read", a single calm sentence shown beneath
Plenty's Overview hero number. Pick exactly one of these kinds:

• silence       — Nothing distinctive to say. Use this generously.
• paceWarning   — Spending pace is above sustainable, OR
                  monthlyBudgetRemaining is negative.
• paceTrend     — Spending pace is meaningfully below sustainable.
• billReminder  — Unpaid bills this month deserve a heads-up.
• incomeReminder — A paycheck is arriving in the next day or two.
• milestone     — Positive savings progress worth acknowledging.

Rules:
• If the user has no data at all, pick silence.
• If monthlyBudgetRemaining is negative, prefer paceWarning.
• If pace is over (smoothedDailyBurn > sustainableDailyBurn),
  prefer paceWarning.
• Otherwise pick the most relevant single kind.
• When in doubt, pick silence. Restraint matters more than coverage.

Output only the kind value.
```

---

## Stage 2: Body Generator (inline kinds only)

Per-kind instructions — see `bodyGeneratorInstructions(kind:)` in `TheReadEngine.swift` for the canonical strings. The instructions enforce the voice rules and provide a one-line example for each kind.

`paceWarning` and `paceTrend` instructions ask the model to lead with `monthEndProjection` when present and meaningful, otherwise fall back to per-day rate language.

---

## Stage 3: Validator (both channels)

Validates that mentioned amounts are within $1 of snapshot values and mentioned dates match snapshot dates by calendar day.

The validator continues to recognize v1 fields (`spendable`, `pace`-derived values) as valid amounts so retroactive Reads in cache don't fail. New v2 amounts (`monthlyBudgetRemaining`, `expectedIncomeRemaining`, `monthEndProjection`) are added to the candidate set.

Weekly skips date validation (1-3 sentence summaries don't typically reference specific dates) but still validates amounts when present.

---

## Stage 4: Weekly Generator

Single-pass generation with a constrained @Generable output: body (1-3 sentences) and primaryAmount (the most prominent dollar value).

### Instructions sent to the model

```
You are writing the Sunday Read, a calm weekly digest delivered as a
notification on Sunday mornings. Compose 1-3 short sentences that
summarize where the user stands financially right now.

Voice:
• Second person ("you have", "your bills", "your savings")
• Possession-leading ("you have $1,840 left" not "$1,840 is available")
• Calm and direct, no exclamations
• No em-dashes, no bullet points, no emojis, no marketing language
• Plain currency like "$1,840"
• Each sentence complete and self-contained
• Total length 1-3 sentences, never more

Content priorities (in order):
1. Monthly budget status — how much is left this month, or whether
   the user is over. Use monthlyBudgetRemaining as the headline number.
2. Bills situation — count and total of unpaid bills, or "all paid"
3. Savings progress — amount saved this month, if any

Skip anything that doesn't apply. If the user has no meaningful
financial activity, return an empty body.

If you mention a dollar amount, set primaryAmount to the most
prominent one for validation.
```

### Validation

Same validator as inline kinds. The prominent amount must match a snapshot value within $1. Unlike inline, weekly does not retry on validation failure — it falls back to deterministic templates immediately. Weekly is not time-critical (runs in advance of Sunday's notification), so retry latency would only add cache time, not user-facing wait.

### Deterministic fallback templates

When AI is unavailable or output failed validation, the deterministic generator composes from snapshot fields in priority order:

1. **Headline budget line:**
   - Positive: `"You have ${monthlyBudgetRemaining} left for the rest of the month."`
   - Zero: `"You're at zero this month — everything's spoken for."`
   - Negative: `"You're ${over} over your budget this month."`
2. **Bills line** (if any unpaid): `"${count} bill(s) are still to pay totaling ${total}."` or `"Every bill for the month is squared away."` (if some paid, none unpaid)
3. **Savings line** (if any contributed this month): `"Saved ${amount} so far."`

Returns silence (empty body, kind=.weekly with empty body) if `zone == .empty`.

---

## Snapshot summary fields the model sees

```
monthlyBudgetRemaining: 1840
confirmedIncome: 3200
expectedIncomeRemaining: 0
billsTotal: 1700 (4 bills, 2 unpaid)
billsRemaining: 850
expensesThisMonth: 620
plannedSavingsRemaining: 250
actualSavingsThisMonth: 250
smoothedDailyBurn: 38
sustainableDailyBurn: 92
monthEndProjection: 1450     # only present when day >= 5
day: 12
daysRemainingInMonth: 18
nextIncomeDate: 2026-04-19
```

---

## Versioning policy

- **Major (2.0)** — adds or removes a delivery channel, restructures stages, changes voice substantively, or shifts the underlying snapshot vocabulary (this release)
- **Minor (1.1)** — adds a kind, refines per-kind guidance, adds examples
- **Patch (1.0.1)** — fixes typos, clarifies wording without behavioral change
