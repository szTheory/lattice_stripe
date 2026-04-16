---
phase: 22-expand-deserialization-status-atomization
verified: 2026-04-16T18:30:00Z
status: gaps_found
score: 3/4 must-haves verified
overrides_applied: 0
gaps:
  - truth: "All test call sites of deprecated status_atom/1 are updated so mix test --warnings-as-errors passes"
    status: failed
    reason: "test/lattice_stripe/account_test.exs lines 145-149 call Capability.status_atom/1 directly (not via apply/3), producing a deprecation warning that aborts mix test --warnings-as-errors. Plan 03 acceptance criteria explicitly required no such warnings."
    artifacts:
      - path: "test/lattice_stripe/account_test.exs"
        issue: "Direct calls to Capability.status_atom/1 at lines 145-149 instead of apply/3 idiom used elsewhere"
    missing:
      - "Update lines 145-149 in account_test.exs to use apply(Capability, :status_atom, [...]) or rewrite to assert .status directly on the %Capability{} struct"
---

# Phase 22: Expand Deserialization & Status Atomization Verification Report

**Phase Goal:** Developers who pass `expand:` options receive fully typed structs (not raw string IDs) in response fields, dot-path expand syntax works for nested list items, and every resource module consistently exposes `_atom` converters for status-like string fields.
**Verified:** 2026-04-16T18:30:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A developer who calls `PaymentIntent.retrieve/3` with `expand: ["customer"]` receives a `%Customer{}` struct — expand guards wire ObjectTypes dispatch | ✓ VERIFIED | `payment_intent.ex` has `ObjectTypes.maybe_deserialize(known["customer"])` guard; full test suite (1610 tests) passes; `ObjectTypes` registry maps all 31 Stripe object types |
| 2 | Dot-path expand syntax (`expand: ["data.customer"]`) works — nested expanded maps are deserialized to typed structs via the same `is_map` guard | ✓ VERIFIED | `test/lattice_stripe/invoice_test.exs` line 281: EXPD-02 test with `"cus_expanded_via_dot_path"` passes; mechanism is identical whether expand was `["customer"]` or `["data.customer"]` |
| 3 | All in-scope resource modules with documented finite status fields auto-atomize via private `defp atomize_status/1` | ✓ VERIFIED (partial) | 14 modules have atomizers: PaymentIntent, Subscription, SubscriptionSchedule, Charge, Refund, SetupIntent, Payout, BalanceTransaction, BankAccount, Checkout.Session, Invoice (pre-existing), Billing.Meter, Account.Capability, TestClock. Note: `MeterEventAdjustment.status` (a resource module with documented status field) was not in D-03 scope — see deferred section. |
| 4 | CHANGELOG has migration note; all test call sites of deprecated `status_atom/1` produce no deprecation warnings under `mix test --warnings-as-errors` | ✗ FAILED | CHANGELOG migration note EXISTS and is correct. But `test/lattice_stripe/account_test.exs:145-149` calls `Capability.status_atom/1` directly, not via `apply/3`. Running `mix test --warnings-as-errors test/lattice_stripe/account_test.exs` aborts with deprecation warning. |

**Score:** 3/4 truths verified (Truth 4 partially — CHANGELOG passes, deprecated call site fails)

### Deferred Items

Items not yet met but explicitly addressed in later milestone phases.

No deferred items — all gaps are actionable fixes in this phase's scope.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/lattice_stripe/object_types.ex` | Central ObjectTypes registry with 31 entries + maybe_deserialize/1 | ✓ VERIFIED | 31 entries in `@object_map`; 4-clause maybe_deserialize/1; compiles clean |
| `test/lattice_stripe/object_types_test.exs` | Unit tests for ObjectTypes dispatch, min 40 lines | ✓ VERIFIED | 60 lines, 10 tests covering nil, string, dispatch, fallthrough — all pass |
| `lib/lattice_stripe/payment_intent.ex` | Status atomization + expand guards | ✓ VERIFIED | `atomize_status/1` for 7 statuses; expand guards for customer, latest_charge, payment_method |
| `lib/lattice_stripe/subscription.ex` | Status + collection_method atomization + expand guards | ✓ VERIFIED | 8 statuses + collection_method; 5 expand guards |
| `lib/lattice_stripe/charge.ex` | Status atomization + 7 expand guards | ✓ VERIFIED | 3 statuses; guards for customer, invoice, payment_intent, payment_method, balance_transaction, destination, source_transfer |
| `lib/lattice_stripe/refund.ex` | Status atomization + expand guards for charge, payment_intent | ✓ VERIFIED | 5 statuses; 2 expand guards |
| `lib/lattice_stripe/setup_intent.ex` | Status + usage atomization + expand guards | ✓ VERIFIED | 6 statuses + usage; 2 expand guards (latest_attempt skipped — SetupAttempt module does not exist) |
| `lib/lattice_stripe/subscription_schedule.ex` | Status + end_behavior atomization + expand guards | ✓ VERIFIED | 5 statuses + end_behavior; 2 expand guards |
| `lib/lattice_stripe/payout.ex` | Status + type + method atomization + 3 expand guards | ✓ VERIFIED | 5 statuses, 2 types, 2 methods; 3 expand guards |
| `lib/lattice_stripe/balance_transaction.ex` | Status + type atomization + source expand guard | ✓ VERIFIED | 2 statuses, 21 types; source expand guard |
| `lib/lattice_stripe/bank_account.ex` | Status atomization + customer expand guard | ✓ VERIFIED | 5 statuses; customer expand guard in cast/1 |
| `lib/lattice_stripe/checkout/session.ex` | Status + mode + payment_status atomization + 5 expand guards | ✓ VERIFIED | 3 statuses, 3 modes, 3 payment_statuses; guards for customer, invoice, payment_intent, setup_intent, subscription |
| `lib/lattice_stripe/billing/meter.ex` | Auto-atomized status + deprecated public status_atom/1 | ✓ VERIFIED | `atomize_status/1` private + `@deprecated` on public `status_atom/1` |
| `lib/lattice_stripe/account/capability.ex` | Auto-atomized status + deprecated public status_atom/1 | ✓ VERIFIED | `atomize_status/1` private + `@deprecated` on public `status_atom/1` |
| `lib/lattice_stripe/invoice.ex` | Expand guards for customer, charge, payment_intent, subscription | ✓ VERIFIED | 4 ObjectTypes.maybe_deserialize guards added to existing atomized module |
| `lib/lattice_stripe/invoice_item.ex` | Expand guards for customer, invoice, subscription | ✓ VERIFIED | 3 expand guards |
| `lib/lattice_stripe/card.ex` | Expand guard for customer | ✓ VERIFIED | customer expand guard in cast/1 |
| `lib/lattice_stripe/payment_method.ex` | Expand guard for customer | ✓ VERIFIED | customer expand guard |
| `lib/lattice_stripe/promotion_code.ex` | Expand guard for customer | ✓ VERIFIED | customer expand guard |
| `lib/lattice_stripe/transfer.ex` | Expand guards for 4 fields | ✓ VERIFIED | balance_transaction, destination, destination_payment, source_transaction |
| `lib/lattice_stripe/transfer_reversal.ex` | Expand guards for 4 fields | ✓ VERIFIED | balance_transaction, destination_payment_refund, source_refund, transfer |
| `CHANGELOG.md` | Migration note for expand behavior change and status atomization | ✓ VERIFIED | Contains "Expand deserialization", "Status atomization", before/after examples, deprecation notes |
| `test/lattice_stripe/invoice_test.exs` | EXPD-02 dot-path expand test | ✓ VERIFIED | Line 281 test with "cus_expanded_via_dot_path" assertion |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `lib/lattice_stripe/payment_intent.ex` | `lib/lattice_stripe/object_types.ex` | `alias + ObjectTypes.maybe_deserialize/1` | ✓ WIRED | Lines 593, 602, 610 — 3 expand guards active |
| `lib/lattice_stripe/invoice.ex` | `lib/lattice_stripe/object_types.ex` | `alias + ObjectTypes.maybe_deserialize/1` | ✓ WIRED | Lines 949, 956, 992, 1011 — 4 expand guards active |
| `lib/lattice_stripe/transfer.ex` | `lib/lattice_stripe/object_types.ex` | `alias + ObjectTypes.maybe_deserialize/1` | ✓ WIRED | Lines 294, 301, 305, 313 — 4 expand guards active |
| `CHANGELOG.md` | expand behavior change | migration note prose | ✓ WIRED | "Expand deserialization" and "Migration note" found; before/after pattern-match example present |
| `test/lattice_stripe/account_test.exs` | `Capability.status_atom/1` | direct call (not apply/3) | ✗ PARTIAL | Calls deprecated function directly instead of via apply/3 — produces deprecation warning that aborts `mix test --warnings-as-errors` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|-------------------|--------|
| `ObjectTypes.maybe_deserialize/1` | `@object_map` | Compile-time map (31 entries) | Yes — dispatches to module.from_map/1 | ✓ FLOWING |
| `payment_intent.ex` customer field | `known["customer"]` after `Map.split/2` | Stripe API response map | Yes — string ID or expanded map dispatched | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| ObjectTypes dispatches to Customer | `mix test test/lattice_stripe/object_types_test.exs` | 10 tests, 0 failures | ✓ PASS |
| PaymentIntent expand + atomize | `mix test test/lattice_stripe/payment_intent_test.exs` | Pass (included in 238-test run) | ✓ PASS |
| EXPD-02 dot-path expand test | `mix test test/lattice_stripe/invoice_test.exs` | 73 tests, 0 failures | ✓ PASS |
| Full test suite | `mix test` | 1610 tests, 0 failures (149 excluded) | ✓ PASS |
| Compile clean | `mix compile --warnings-as-errors` | EXIT:0, no output | ✓ PASS |
| Deprecation warning in account_test | `mix test --warnings-as-errors test/lattice_stripe/account_test.exs` | ABORT: deprecation warning on Capability.status_atom/1 | ✗ FAIL |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| EXPD-01 | 22-01, 22-02, 22-03, 22-04 | Typed struct dispatch for `expand:` fields | ✓ SATISFIED | ObjectTypes registry wired to 20+ resource modules; expand guards verified by test suite |
| EXPD-02 | 22-01, 22-04 | Dot-path expand syntax works | ✓ SATISFIED | EXPD-02 test in invoice_test.exs passes; mechanism auto-works via is_map guard |
| EXPD-03 | 22-02, 22-03 | Status atomization sweep across all resource modules | ✓ SATISFIED (partial) | 14 modules have private atomize_status/1; MeterEventAdjustment excluded from D-03 scope (see Anti-Patterns) |
| EXPD-04 | 22-04 | Union type specs + CHANGELOG migration note | ✓ SATISFIED (with gap) | CHANGELOG migration note present; union typespecs in all expanded field types; BUT account_test.exs has unupdated deprecated call site |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `test/lattice_stripe/account_test.exs` | 142-150 | Direct call `Capability.status_atom/1` instead of `apply/3` | ✗ Blocker | `mix test --warnings-as-errors` aborts; CI would fail if this flag is used |

### Human Verification Required

None. All checks were automated.

### Gaps Summary

One gap blocks goal achievement:

**1. Deprecated call site in account_test.exs (Blocker)**

Plan 03 Task 2 acceptance criteria required: "All test call sites of `Meter.status_atom/1` and `Capability.status_atom/1` are updated so no compile-time deprecation warnings remain in test files." The capability_test.exs and meter_test.exs files were correctly updated to use `apply/3`. However, `test/lattice_stripe/account_test.exs` lines 145-149 call `Capability.status_atom/1` directly — this was an oversight (the file was not in Plan 03's `files_modified` list).

Running `mix test --warnings-as-errors test/lattice_stripe/account_test.exs` produces:
```
warning: LatticeStripe.Account.Capability.status_atom/1 is deprecated. Status is now automatically atomized in cast/1. Access capability.status directly.
ERROR! Test suite aborted after successful execution due to warnings while using the --warnings-as-errors option
```

**Fix required:** In `test/lattice_stripe/account_test.exs`, update lines 145-149 from direct `Capability.status_atom(...)` calls to either `apply(Capability, :status_atom, [...])` or rewrite to assert `capability.status` directly (since status is now auto-atomized, `account.capabilities["card_payments"].status == :active` is the idiomatic check).

**Note on EXPD-03 scope:** `MeterEventAdjustment` is a resource module with a documented status field (pending/complete/canceled) but no `atomize_status/1`. The D-03 decision in CONTEXT.md explicitly bounded scope to 9+2 modules and excluded `MeterEventAdjustment`. This is a known deviation from the ROADMAP SC3 literal wording ("84+ modules") but reflects a deliberate research-time scoping decision. It is informational rather than a blocker — the CHANGELOG accurately states "All resource modules with a documented finite status field" without specifically listing `MeterEventAdjustment`. If the developer considers EXPD-03 complete as scoped (9+2 modules), add an override for this item.

---

_Verified: 2026-04-16T18:30:00Z_
_Verifier: Claude (gsd-verifier)_
