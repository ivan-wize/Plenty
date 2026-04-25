//
//  Plenty-Rebuild-Plan.md
//  PlentyTests
//
//  Created by Ivan Wize on 4/24/26.
//

# Plenty — Rebuild Plan

**Status:** Working document, v1.0
**Companion to:** Plenty Product Requirements Document (v1.0, Final for build)
**Owner:** Engineering
**Target ship:** Tuesday, September 8, 2026

This is the engineering phasing plan referenced in PRD Section 1. The PRD specifies *what* Plenty is. This document specifies *how and in what order* it gets built from the existing Left codebase. Where the two disagree, the PRD wins.

---

## 1. Project setup: new Xcode project, copy forward the foundations

Plenty is built as a new Xcode project, not a rename of Left. The bundle identifier, App Group, and CloudKit container all change under the PRD, and renaming those across an existing multi-target Xcode project is a known failure mode. Starting fresh costs one afternoon of target setup; renaming in place has cost teams a week of follow-on bugs.

Approximately 60 percent of Left's code copies forward unchanged or with only a rebrand pass. The data layer, engine layer, most utilities, all App Intents, the receipt parser, the Watch scaffold, and the CloudKit sync monitor are reused. View code and onboarding are largely new. Section 9 of this document lists every file by disposition (copy, rewrite, delete, build new).

---

## 2. Phase summary

Thirteen phases over roughly 20 weeks. Target ship is week 20 from today (April 24, 2026), which maps to September 8. Phases 4 through 7 can overlap if a second engineer is available; otherwise the schedule runs serially.

| Phase | Weeks | Name | Risk |
|---|---|---|---|
| 0 | 1 | Architecture decisions | High (gates everything) |
| 1 | 1 | Identity and infrastructure | Low |
| 2 | 1 | Shell and navigation | Low |
| 3 | 1 | Data model additions | Medium |
| 4 | 2 | Home and The Read v1 | Medium |
| 5 | 2 | Accounts consolidation | Low |
| 6 | 2 | Plan tab | Low |
| 7 | 2 | The Read complete and notifications | Medium |
| 8 | 2 | Household sharing | High |
| 9 | 1.5 | Import, privacy, receipt | Medium |
| 10 | 1 | Pro, onboarding, demo mode | Low |
| 11 | 1 | Widgets and Watch | Low |
| 12 | 2 | Accessibility, performance, QA | Medium |
| 13 | 1 | Launch prep | Low |

---

## 3. Phase 0: Architecture decisions

No code. Three decisions must be settled before the schema is touched, because each one changes what gets built.

**Decision 3.1: Household sharing architecture.** Today Left uses SwiftData's `cloudKitDatabase: .automatic`, which syncs the user's private zone only. PRD Section 9.13 requires that selected records be visible to other Family Sharing members, which means CloudKit *shared* zones. SwiftData's public API does not expose `CKShare` participation cleanly. The spike question: can `@Model` types be made shareable through the default container, or does sharing force a fallback to `NSPersistentCloudKitContainer` with NSManagedObject subclasses? If the answer is the second, the entire data layer gets rewritten, not copied. Budget three days to prototype both paths on a throwaway branch.

**Decision 3.2: Hero number math.** PRD Section 9.1 defines the hero number as "total balance across spendable accounts, minus unpaid bills coming due before the next income event, minus credit card balances owed, minus remaining scheduled savings contributions." Subtracting the full credit card balance penalizes users who carry a revolving balance they are paying down over time, which is common for the 38-year-old household manager persona. The alternative is to subtract only the statement balance due before the next income event, which matches how a user actually experiences a credit card as a "this month" commitment. Decide: match PRD literally, or refine. The math change is one method in `BudgetEngine`; the product implication is meaningful.

**Decision 3.3: The Read reliability model.** Foundation Models is a small on-device LLM being asked to produce prose about someone's money. A single hallucinated date or amount costs trust disproportionately. The spike: lock the v1 prompt, define a runtime validator that cross-checks any dates and amounts the model produces against the structured snapshot, and decide the cache TTL. PRD already states silence is a first-class output; the question is how strict the gate to non-silence should be. Propose: validator rejects on any numeric or date mismatch and defaults to silence. Prompt lives in `Resources/TheReadPrompt.md` under version control.

Deliverable for Phase 0: a one-page decisions doc, committed to the repo root.

---

## 4. Phases 1 through 3: foundations

**Phase 1, identity and infrastructure (1 week).** Create `Plenty.xcodeproj`. Set bundle identifier `com.plenty.app`, App Group `group.com.plenty.app`, CloudKit container `iCloud.com.plenty.app`. Configure all four targets (iPhone, Widget, Watch, Intents). Import the sage color palette, the SF Pro Display/Text/Rounded typography tokens, and the stadium-bar app icon asset. Build the `Wordmark` SwiftUI view with optical tracking applied per PRD Section 4.1. Copy forward the foundation utilities listed in Section 9.1 below. No UI on screen yet.

*Done when:* the app builds, launches to a blank screen, renders the wordmark correctly at hero and text sizes, and the icon appears in the simulator home screen.

**Phase 2, shell and navigation (1 week).** Build the floating Liquid Glass tab bar with four tabs and a centered Add button. The Add button presents a sheet offering Add expense / Add income / Add bill. Wire deep linking between tabs via `AppState`. All four tabs are empty scaffolds at this point.

*Done when:* the user can tap between four tabs, tap Add, see the three-option sheet, and dismiss it.

**Phase 3, data model additions (1 week, depends on Decision 3.1).** Port the data model files forward. Add fields for sharing (`isShared`, zone assignment if applicable), a `Subscription` model for the detection engine, notification preference storage, and a demo-mode flag. Deploy the new CloudKit schema to the Development environment. No migration code is needed because there is no production data.

*Done when:* `ModelContainerFactory` creates a container successfully with the new schema, CloudKit Development is accepting writes, and `CloudKitSyncMonitor` reports clean sync.

---

## 5. Phase 4: Home and The Read v1

Two weeks. This is the single most marketing-critical surface in the app.

Build the new `HeroNumberView`: a single number, no ring, state-driven color (sage / amber / terracotta per the zone). Build `TheReadService`, `TheReadGenerator`, `TheReadValidator`, and `TheReadCache`. The generator consumes a `PlentySnapshot` and a 30-day transaction window, calls the on-device model with the versioned prompt, runs the output through the validator, and caches the approved sentence for the day. On non-Apple-Intelligence devices, The Read is suppressed entirely; the hero stands alone.

Build `GlanceListView`: up to five items from the next seven days, drawn from `TransactionProjections` plus scheduled income and savings contributions. Wire the demo-mode banner.

*Done when:* a fresh user taps Start with demo data, sees a hero number, a sentence that matches the demo state, and three to five glance items within five seconds. A user on an iPhone 13 sees the same hero and glance list with no sentence.

---

## 6. Phases 5 and 6: Accounts and Plan

**Phase 5, Accounts consolidation (2 weeks).** The Accounts tab absorbs Bills (as a linked sub-screen), Subscriptions (new), All Transactions (new filterable view), and the Net Worth summary card. Account detail ports forward from Left with minor surface updates: six-month balance chart, 30-day cash-in / cash-out summary, filtered transaction list, staleness indicator, Mine/Ours indicator if sharing is enabled. Add, Edit, Update Balance, and Delete flows copy forward. Net Worth detail view is new: twelve-month trend chart, assets and debts breakdown, 30-day delta.

*Done when:* a user can see every account, every bill, every subscription, and every transaction from a single tab with filters.

**Phase 6, Plan tab (2 weeks).** Three sub-sections: Outlook, Save, Trends. All three are Pro-gated per the PRD pricing model.

Outlook is net new: a 90-day line chart rendered from `BudgetEngine`'s scheduled events, with event markers for income arrivals (sage up-tick), bill due dates (terracotta down-tick), and savings contributions. Projected shortfalls are highlighted with a terracotta region and summarized in the banner above the chart. Disclosure text reminds the user that discretionary spending is not projected.

Save ports forward from Left's existing savings flow with voice-rule cleanup: goal completion shows one checkmark and one sentence, no celebration animation, no fanfare.

Trends ports forward from Left's `TrendsTabContent` with the recommendation engine removed. Trends are descriptive only per PRD Section 9.9.

Debt payoff (already built in `DebtEngine`) moves to a view opened from a debt account's detail in the Accounts tab, not Plan.

*Done when:* a Pro user can see the 90-day outlook with correct shortfall detection, manage savings goals, and review the past twelve months of spending. A free user sees the Plan tab as a paywalled surface.

---

## 7. Phase 7: The Read complete and notifications

Two weeks. The PRD unifies every on-device intelligence feature under the brand "The Read." This phase builds the ones not done in Phase 4.

Per-transaction inline notes: when the user saves a new expense, an async call produces at most a 60-character observation ("first time here this month", "30 percent above your usual") and displays it inline on the transaction row. Suppressed for income and bills. Most transactions get no note.

Sunday Read: a local notification scheduled for 9 AM Sunday in the user's local time zone, showing a three-sentence summary of the past week. Permission requested after one week of app use, not at onboarding.

Bill-due reminders: local notifications three days before and day-of. Permission requested the first time the user creates a bill. Per-bill and global toggles in Settings.

Subscription detection: pattern engine finds three-plus charges with similar amount (±5 percent) and consistent cadence (monthly, annual, weekly windows per PRD Section 9.5). Foundation Models normalizes merchant names ("NETFLIX.COM 866-..." becomes "Netflix"). Detected subscriptions appear as suggestions on the Subscriptions screen; user promotes each to tracked status.

Cancellation reminders: user marks a subscription "to cancel"; an EventKit calendar entry is created for the day before the next renewal, plus a local notification. Plenty does not cancel anything itself.

Graceful degradation matrix per PRD Section 10.8 is implemented as a single `ReadAvailability` gate, not scattered `if available` checks.

*Done when:* all five behaviors work on an iPhone 15 Pro, all five are suppressed or fall back cleanly on an iPhone 13, and a full week of dogfooding produces no hallucinated Sunday Read content.

---

## 8. Phase 8: Household sharing (high risk)

Two weeks budgeted. The single phase most likely to slip.

Depends on the answer to Decision 3.1. If SwiftData can participate in CloudKit shared zones, the work is: add per-account and per-record sharing toggles, implement the Mine / Ours / All filter on the Accounts tab, wire last-write-wins conflict behavior (no conflict UI per PRD), and test end-to-end with two Apple IDs.

If SwiftData cannot, this phase is 4 weeks and the scope-cut hierarchy (Section 11) kicks in: ship Plenty V1 without sharing, move sharing to V1.1.

*Done when:* two users on two Apple IDs in the same Family Sharing group can both install Plenty, share an account, see the same account in each other's app, add a transaction to it, and see each other's transactions appear within one minute.

---

## 9. Phases 9 through 13: the long tail

**Phase 9, import and privacy and receipt (1.5 weeks).** Build the import flow: file picker, format detection (CSV / OFX / QFX), AI column mapping suggestion for CSV, preview screen with duplicate detection, streaming parser for 10,000-row files. Settings > Privacy & Data: JSON export, CSV export (port from Left's existing exporter), Delete All with confirmation and iCloud propagation. Port receipt scanning forward with the Plenty name.

**Phase 10, Pro and onboarding and demo mode (1 week).** Single $9.99 StoreKit IAP. Restore flow. Pro gating on the Plan tab. One-screen onboarding: wordmark, one sentence, two buttons (Start with demo data / Start fresh). Demo seed: two accounts, one active income source with recent arrivals, six recurring bills, thirty transactions across categories, two subscriptions, one savings goal. Persistent banner reads "Demo data · Start fresh to begin" with a clear action.

**Phase 11, widgets and Watch (1 week).** Widgets: Small (hero only), Medium (hero + Read), Large (hero + Read + three glance items), Lock Circular (hero with state ring), Lock Rectangular (hero + Read truncated). The Large widget is net new; the others rebrand and add The Read. Watch app: rebrand, keep the four views (Glance, Quick Add, Bills, Income).

**Phase 12, accessibility and performance and QA (2 weeks).** Dynamic Type sweep to AX5 with the stacked hero fallback at AX3. VoiceOver labels on every interactive element. Voice Control labels. High Contrast and Smart Invert verification. ProMotion 120fps scroll audit. Cold-launch measurement (target: under 1 second on iPhone 15). Network capture during 30 minutes of normal use must show traffic only to Apple services. 50-sample Read voice review by Product. External TestFlight wave of roughly 100 curated testers, including the four named tester profiles in PRD Section 16 item 14.

**Phase 13, launch prep (1 week).** App Store listing (ten screenshots including two text-only privacy statements per PRD Section 15). Privacy policy in plain English under 250 words. Press kit. Landing page. Four pre-drafted launch essays per PRD cadence. USPTO filing in Class 9 and Class 36 (filing date is the ship gate; clearance is not required per PRD Section 16 item 12). Submit to App Store review approximately ten days before September 8 to leave room for rejection loops.

---

## 10. Cross-phase concerns

**Testing.** Engine code keeps the unit test discipline Left already has: `BudgetEngine`, `DebtEngine`, `RecurringRule`, `IncomeEntryGenerator` all have test suites that copy forward. New engines (`CashFlowProjector`, `SubscriptionDetector`) ship with test suites before they ship to users. `TheReadValidator` is tested against a fixture library of adversarial snapshots designed to tempt hallucination.

**Accessibility.** Not a Phase 12 afterthought. Every new view in every phase ships with accessibility labels and Dynamic Type support from the first commit. Phase 12 is the audit and edge-case pass, not the introduction.

**Voice review.** Every user-facing string written in every phase goes through the voice rules in PRD Section 5 before the view ships. Reviewer is Product. Phase 12's 50-sample Read voice review is the final gate, not the first check.

**Privacy verification.** Every third-party SDK, every network call, every analytics library is a hard stop. Plenty's repo has no `Podfile`, no unexpected SPM dependencies, no `URLSession` calls to non-Apple hosts. The network capture in Phase 12 is the proof; the discipline is daily.

---

## 11. Scope-cut hierarchy (what goes if we slip)

If the ship date is at risk at week 14, cuts happen in this order. First cut first.

1. Large Home Screen widget (PRD wants three sizes; Medium is the priority surface per Section 9.15, so Small + Medium + Lock variants ships and Large follows in a point release).
2. OFX and QFX import (CSV alone covers the 80 percent case; OFX and QFX ship in V1.1).
3. Subscription cancellation reminders via EventKit (detection and display still ship; the reminder hand-off follows).
4. Per-transaction inline AI notes (nice-to-have on The Read surface; hero sentence and Sunday Read are the priority).
5. Household sharing (ships in V1.1 if the Phase 0 spike reveals it needs twice the budgeted time).

The following do *not* get cut regardless: The Read sentence on Home, 90-day Outlook chart, bill-due reminders, demo mode, one-time Pro purchase, full accessibility pass, network capture privacy proof.

---

## 12. Risks

**Architecture risk, Decision 3.1.** Addressed above. Mitigation is the Phase 0 spike and the scope-cut hierarchy.

**Apple Intelligence device split.** A non-trivial fraction of installs will be on iPhone 14 and earlier, where The Read is silent. The app has to feel complete on those devices, not diminished. Phase 4 acceptance includes a walkthrough on an iPhone 13 where the Home screen, Accounts tab, and Plan tab all feel coherent without any AI surfaces.

**App Store review rejection.** Common rejection reasons for finance apps: privacy policy clarity, in-app purchase disclosure, health-adjacent claims. Mitigation: the privacy policy is plain English (PRD Section 15), the Pro purchase surface follows Apple's template language exactly, and no claim in the app is health-adjacent.

**Trademark on "Plenty."** USPTO Class 36 is crowded. PRD Section 16 makes filing (not clearance) the ship gate. If a substantive opposition lands between filing and launch, the launch holds.

**Foundation Models prompt drift.** The Read's prompt is versioned. Any change that alters output semantics requires a fresh 50-sample review. This is a process risk more than a technical one; owner is Product.

---

## 13. File inventory from Left to Plenty

Every file in the Left codebase has one of four dispositions.

**Copy forward with rename-only changes** (approx. 40 files):
Foundation, data, and engine layers. `Account`, `AccountBalance`, `AccountCategory`, `IncomeSource`, `RecurringRule`, `SavingsGoal`, `SavingsGoalType`, `SpendingLimit`, `Transaction`, `TransactionCategory`, `TransactionKind`, `BudgetEngine`, `BudgetEngine_Savings`, `BurnRate`, `DebtEngine`, `ExpenseCategorizer`, `IncomeEntryGenerator`, `LeftSnapshot` (renamed `PlentySnapshot`), `TransactionProjections`, `AccountDerivations`, `NetWorthInsightEngine`, `Calendar_Helpers`, `Decimal_Currency`, `Int_Ordinal`, `ModelContext_SafeSave`, `CloudKitSyncMonitor`, `ReceiptParser`, `AIReceiptParser`, `AIExpenseCategorizer`, `LeftAIService` (renamed `PlentyReadService`), `AIUnavailableView`, `BillSuggestions`, `TransactionSuggestions`, `CategoryIconView`, `CategoryPickerView`, `AccountPickerView`, `CurrencyField`, `KeyboardDoneButton`, all nine App Intent files, `LeftShortcutsProvider` (renamed), most of the Watch scaffold.

**Rewrite** (approx. 25 files):
`Theme` gets the sage palette. `RootView`, `AppState`, `ModelContainerFactory` get the new tab enum and identifiers. `OverviewTab` becomes `HomeTab`, restructured. `HeroNumberView` loses the ring. `AccountsTab` absorbs bills and subscriptions. `PlanTab` reorganizes to three sub-sections. `SettingsView` becomes `SettingsTab` as a top-level surface. `ProUpgradeSheet` loses tip tiers. `LeftWidget` becomes `PlentyWidget` with The Read integration and Large support. All onboarding files replaced by a single screen.

**Delete** (approx. 15 files):
`LeftAssistView`, `LeftAssistViewModel`, `BudgetCoachTools` (PRD Section 13, no chat assistant). `OnboardingHookScreen`, `OnboardingPromiseScreen`, `OnboardingPrivacyScreen`, `OnboardingSimpleSetup` (replaced by single-screen onboarding). `SetupChecklist`, `OverviewEmptyState` (no tour, no checklist). `BalanceReconciliationNudge`, `ReceiptScanNudge` (nudges violate the calm voice rules). `CopyForwardCard` (paradigm no longer matches the new IA). `MonthSelectorView` (new IA is not month-centric on Home), `IncomeTab`, `ExpensesTab`, `AddIncomeSheet` (income is a sub-view under Accounts; the Add button handles quick income).

**Build new** (approx. 35 files):
The Read layer (`TheReadGenerator`, `TheReadValidator`, `TheReadCache`, `TheReadService`), notification layer (`NotificationService`, `EventKitService`), import flow (`ImportService`, `ColumnMappingView`, `ImportPreviewView`, `AIColumnMapper`), subscription layer (`SubscriptionDetector`, `AISubscriptionNormalizer`, `SubscriptionsView`, `SubscriptionRow`, `SubscriptionSuggestionsView`), cash flow (`CashFlowProjector`, `OutlookView`, `CashFlowChart`, `ShortfallBanner`), sharing (`HouseholdShareService` and related), demo mode (`DemoModeService`, `DemoModeBanner`), design system (`Wordmark`, `LiquidGlassTabBar`, `PlentySage`, `Typography`), new tabs (`HomeTab`, `SettingsTab`), new onboarding (single file), new Large widget, Large widget, glance list component, settings sub-sections.

---

## 14. Folder and file structure

Target layout for the new Xcode project. All Swift files live under one of four target roots (`Plenty`, `PlentyWidget`, `PlentyWatch`, `PlentyTests`). App Intents live inside the `Plenty` target under `Intents/` rather than in a separate extension; at Plenty's size the extension adds complexity without benefit.

```
Plenty/
├── Plenty.xcodeproj
├── Plenty/                                    iPhone app target
│   ├── App/
│   │   ├── PlentyApp.swift
│   │   ├── RootView.swift
│   │   ├── AppState.swift
│   │   ├── AppearanceMode.swift
│   │   └── ModelContainerFactory.swift
│   ├── Resources/
│   │   ├── Assets.xcassets/
│   │   │   ├── AppIcon.appiconset/            stadium-bar icon, light + dark
│   │   │   ├── PlentySage.colorset
│   │   │   ├── PlentyOffWhite.colorset
│   │   │   ├── PlentyCharcoal.colorset
│   │   │   ├── PlentyAmber.colorset
│   │   │   └── PlentyTerracotta.colorset
│   │   ├── Info.plist
│   │   ├── Plenty.entitlements
│   │   ├── TheReadPrompt.md                   versioned prompt, Phase 0 output
│   │   ├── TheReadPrompt.version              integer version string
│   │   └── DemoData.json                      demo-mode seed
│   ├── Models/
│   │   ├── Account.swift
│   │   ├── AccountBalance.swift
│   │   ├── AccountCategory.swift
│   │   ├── IncomeSource.swift
│   │   ├── RecurringRule.swift
│   │   ├── SavingsGoal.swift
│   │   ├── SavingsGoalType.swift
│   │   ├── SpendingLimit.swift
│   │   ├── Subscription.swift                 NEW
│   │   ├── Transaction.swift
│   │   ├── TransactionCategory.swift
│   │   └── TransactionKind.swift
│   ├── Engine/
│   │   ├── AccountDerivations.swift
│   │   ├── BudgetEngine.swift
│   │   ├── BudgetEngine+Savings.swift
│   │   ├── BurnRate.swift
│   │   ├── CashFlowProjector.swift            NEW, 90-day outlook
│   │   ├── DebtEngine.swift
│   │   ├── ExpenseCategorizer.swift
│   │   ├── IncomeEntryGenerator.swift
│   │   ├── NetWorthInsightEngine.swift
│   │   ├── PlentySnapshot.swift               renamed from LeftSnapshot
│   │   ├── SubscriptionDetector.swift         NEW
│   │   └── TransactionProjections.swift
│   ├── Intelligence/                          The Read
│   │   ├── PlentyReadService.swift            renamed from LeftAIService
│   │   ├── TheReadGenerator.swift             NEW
│   │   ├── TheReadValidator.swift             NEW
│   │   ├── TheReadCache.swift                 NEW
│   │   ├── TransactionNoteGenerator.swift     NEW
│   │   ├── SundayReadGenerator.swift          NEW
│   │   ├── AIExpenseCategorizer.swift
│   │   ├── AIReceiptParser.swift
│   │   ├── AIColumnMapper.swift               NEW, CSV import
│   │   ├── AISubscriptionNormalizer.swift     NEW
│   │   └── ReceiptParser.swift                regex fallback
│   ├── Services/
│   │   ├── CloudKitSyncMonitor.swift
│   │   ├── DemoModeService.swift              NEW
│   │   ├── EventKitService.swift              NEW, cancellation reminders
│   │   ├── HouseholdShareService.swift        NEW
│   │   ├── ImportService.swift                NEW, CSV/OFX/QFX
│   │   ├── NotificationService.swift          NEW, bill-due and Sunday Read
│   │   └── StoreService.swift                 renamed from StoreManager
│   ├── DesignSystem/
│   │   ├── Theme.swift                        sage palette, tokens
│   │   ├── Typography.swift                   SF Pro Display/Text/Rounded
│   │   ├── Wordmark.swift                     NEW, with optical tracking
│   │   ├── LiquidGlassTabBar.swift            NEW, floating with center Add
│   │   └── Components/
│   │       ├── AccountPickerView.swift
│   │       ├── CategoryIconView.swift
│   │       ├── CategoryPickerView.swift
│   │       ├── CurrencyField.swift
│   │       ├── EmptyStateView.swift
│   │       ├── ErrorBanner.swift
│   │       ├── KeyboardDoneButton.swift
│   │       ├── ReceiptThumbnailView.swift
│   │       └── TransactionRow.swift
│   ├── Features/
│   │   ├── Home/
│   │   │   ├── HomeTab.swift                  NEW, absorbs OverviewTab
│   │   │   ├── HeroNumberView.swift           rewritten, no ring
│   │   │   ├── TheReadView.swift              NEW
│   │   │   └── GlanceListView.swift           NEW
│   │   ├── Accounts/
│   │   │   ├── AccountsTab.swift
│   │   │   ├── AccountsListView.swift
│   │   │   ├── AccountRowView.swift
│   │   │   ├── AccountDetailView.swift
│   │   │   ├── AccountTransactionsView.swift
│   │   │   ├── AllTransactionsView.swift      NEW, filterable
│   │   │   ├── AddAccountSheet.swift
│   │   │   ├── EditAccountSheet.swift
│   │   │   ├── UpdateBalanceSheet.swift
│   │   │   ├── AccountStripView.swift
│   │   │   ├── Bills/
│   │   │   │   ├── BillsListView.swift
│   │   │   │   ├── BillRow.swift
│   │   │   │   └── BillEditorSheet.swift
│   │   │   ├── Subscriptions/
│   │   │   │   ├── SubscriptionsView.swift            NEW
│   │   │   │   ├── SubscriptionRow.swift              NEW
│   │   │   │   └── SubscriptionSuggestionsView.swift  NEW
│   │   │   ├── NetWorth/
│   │   │   │   ├── NetWorthSummaryCard.swift
│   │   │   │   ├── NetWorthDetailView.swift           NEW
│   │   │   │   └── NetWorthChartView.swift
│   │   │   ├── Debt/
│   │   │   │   ├── DebtPayoffView.swift
│   │   │   │   ├── DebtBreakdownView.swift
│   │   │   │   ├── DebtChartView.swift
│   │   │   │   └── PayoffStrategyView.swift
│   │   │   └── Import/
│   │   │       ├── ImportFlow.swift           NEW
│   │   │       ├── ColumnMappingView.swift    NEW
│   │   │       └── ImportPreviewView.swift    NEW
│   │   ├── Plan/
│   │   │   ├── PlanTab.swift                  rewritten
│   │   │   ├── PlanHelpers.swift
│   │   │   ├── PlanLayout.swift
│   │   │   ├── Outlook/
│   │   │   │   ├── OutlookView.swift          NEW
│   │   │   │   ├── CashFlowChart.swift        NEW
│   │   │   │   └── ShortfallBanner.swift      NEW
│   │   │   ├── Save/
│   │   │   │   ├── SavingsView.swift          renamed from SavingsTabContent
│   │   │   │   ├── SavingsPlanCard.swift
│   │   │   │   ├── AddSavingsGoalSheet.swift
│   │   │   │   ├── LogContributionSheet.swift
│   │   │   │   └── ContributionHistoryView.swift
│   │   │   └── Trends/
│   │   │       ├── TrendsView.swift
│   │   │       ├── MonthlyTrendChart.swift
│   │   │       ├── CategoryBreakdownView.swift
│   │   │       └── SpendingBreakdownView.swift
│   │   ├── Settings/
│   │   │   ├── SettingsTab.swift              NEW, was a sheet
│   │   │   ├── AccountsAndSharingSection.swift  NEW
│   │   │   ├── NotificationsSection.swift     NEW
│   │   │   ├── AppearanceSection.swift
│   │   │   ├── PrivacyAndDataSection.swift    NEW
│   │   │   ├── PlentyProSection.swift         renamed
│   │   │   ├── AboutSection.swift
│   │   │   └── ProUpgradeSheet.swift          rewritten
│   │   ├── Add/                               the + button in the tab bar
│   │   │   ├── AddActionSheet.swift           NEW, three-option chooser
│   │   │   ├── AddExpenseSheet.swift
│   │   │   ├── AddIncomeSheet.swift
│   │   │   ├── ConfirmIncomeSheet.swift
│   │   │   └── ReceiptScannerView.swift
│   │   └── Onboarding/
│   │       ├── OnboardingView.swift           NEW, single screen
│   │       └── DemoModeBanner.swift           NEW
│   ├── Intents/                               App Intents, in-target
│   │   ├── PlentyShortcutsProvider.swift      renamed
│   │   ├── AddExpenseIntent.swift
│   │   ├── AddIncomeIntent.swift
│   │   ├── AddBillIntent.swift
│   │   ├── MarkBillPaidIntent.swift
│   │   ├── LogSavingsIntent.swift
│   │   ├── ConfirmIncomeIntent.swift
│   │   ├── GetPlentyIntent.swift              renamed from GetLeftIntent
│   │   ├── MonthlySummaryIntent.swift
│   │   └── SpendingBreakdownIntent.swift
│   └── Utilities/
│       ├── Calendar+Helpers.swift
│       ├── Decimal+Currency.swift
│       ├── Int+Ordinal.swift
│       └── ModelContext+SafeSave.swift
├── PlentyWidget/                              widget extension target
│   ├── PlentyWidget.swift                     configuration
│   ├── PlentyWidgetBundle.swift
│   ├── TimelineProvider.swift
│   ├── WidgetEntry.swift
│   ├── Views/
│   │   ├── SmallWidgetView.swift
│   │   ├── MediumWidgetView.swift             updated for The Read
│   │   ├── LargeWidgetView.swift              NEW
│   │   ├── CircularLockScreenView.swift
│   │   └── RectangularLockScreenView.swift
│   ├── Assets.xcassets
│   └── Info.plist
├── PlentyWatch/                               watchOS app target
│   ├── PlentyWatchApp.swift                   renamed from LeftWatchApp
│   ├── Views/
│   │   ├── WatchHomeView.swift                the Glance view
│   │   ├── QuickAddWatchView.swift
│   │   ├── BillsChecklistView.swift
│   │   ├── IncomeStatusView.swift
│   │   └── ContentView.swift
│   ├── Assets.xcassets
│   └── Info.plist
├── PlentyTests/                               unit tests
│   ├── BudgetEngineTests.swift
│   ├── CashFlowProjectorTests.swift           NEW
│   ├── DebtEngineTests.swift
│   ├── IncomeEntryGeneratorTests.swift
│   ├── ImportServiceTests.swift               NEW
│   ├── RecurringRuleTests.swift
│   ├── SubscriptionDetectorTests.swift        NEW
│   ├── TheReadValidatorTests.swift            NEW
│   └── Fixtures/
│       ├── DemoSnapshots.swift
│       └── ReadAdversarialCases.swift         NEW
├── CloudKitSchema.ckdb                        tracked in repo
├── Plenty-Rebuild-Plan.md                     this file
└── Plenty-PRD.md                              the PRD, source of truth
```

### Target memberships at a glance

Most files live in the `Plenty` iPhone target only. Files that need to belong to multiple targets:

| File | Plenty | Widget | Watch | Intents |
|---|:-:|:-:|:-:|:-:|
| Models (all 12) | ✓ | ✓ | ✓ | ✓ |
| `PlentySnapshot`, `BudgetEngine`, `BudgetEngine+Savings` | ✓ | ✓ | ✓ | ✓ |
| `AccountDerivations`, `TransactionProjections` | ✓ | ✓ | ✓ | ✓ |
| `IncomeEntryGenerator` | ✓ | ✓ | ✓ | ✓ |
| `ModelContainerFactory` | ✓ | ✓ | ✓ | ✓ |
| `ExpenseCategorizer` (rule-based) | ✓ |   | ✓ | ✓ |
| Utilities (all 4) | ✓ | ✓ | ✓ | ✓ |

Any file whose membership spans multiple targets is verified during the Phase 1 target setup and is not changed thereafter.

---

## 15. Open items

Items in this doc that need the founder's decision before Phase 0 ends.

1. Hero number math. PRD literal versus refined (Decision 3.2 above).
2. Whether to match PRD punctuation (em dashes) in the final canonical docs or unify on the Rebuild Plan's non-em-dash style. Zero engineering impact; brand-consistency call.
3. Ship-date stance. Twenty weeks of work maps to September 8 only if Phase 0's sharing spike comes back cleanly. If not, cut sharing to V1.1 per Section 11.

---

*End of Rebuild Plan v1.0. This document sits alongside the PRD as canonical build reference. Updates to this document are tracked in the repo; updates to the PRD require a version bump and a voice-and-scope review.*
