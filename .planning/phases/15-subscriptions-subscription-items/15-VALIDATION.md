---
phase: 15
slug: subscriptions-subscription-items
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-12
---

# Phase 15 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Draft — the planner will fill the per-task verification map once PLAN.md is authored.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) + Mox ~> 1.2 |
| **Config file** | `test/test_helper.exs` (existing) |
| **Quick run command** | `mix test --exclude integration` |
| **Full suite command** | `mix test --include integration` (requires stripe-mock Docker container on :12111) |
| **Estimated runtime** | ~5s unit / ~30s with integration |

---

## Sampling Rate

- **After every task commit:** Run `mix test <scoped test file>` + `mix format --check-formatted` + `mix credo --strict`
- **After every plan wave:** Run `mix test --exclude integration` (full unit suite)
- **Before `/gsd-verify-work`:** `mix test --include integration` must be green with stripe-mock running
- **Max feedback latency:** ~5 seconds (unit), ~30 seconds (with integration)

---

## Per-Task Verification Map

*To be populated by the planner when PLAN files are authored.*

Expected structure — one row per task across 15-01, 15-02, 15-03:

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 15-01-xx | 01 | N | BILL-03 | T-15-01 / T-15-05 | Inspect hides PII; form encoder escapes metadata | unit | `mix test test/lattice_stripe/subscription_test.exs` | ❌ W0 | ⬜ pending |
| 15-02-xx | 02 | N | BILL-03 | T-15-03 | Guard rejects missing proration on items[] | unit | `mix test test/lattice_stripe/subscription_item_test.exs` | ❌ W0 | ⬜ pending |
| 15-03-xx | 03 | N | BILL-03 | T-15-02 / T-15-04 | Idempotency key forwarded; webhook note in guide | integration | `mix test --include integration test/integration/subscription_integration_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Test files that must exist as skeletons before Wave 1 execution starts:

- [ ] `test/lattice_stripe/subscription_test.exs` — stubs for BILL-03 (Subscription CRUD + lifecycle)
- [ ] `test/lattice_stripe/subscription/pause_collection_test.exs` — nested struct decode
- [ ] `test/lattice_stripe/subscription/cancellation_details_test.exs` — nested struct decode
- [ ] `test/lattice_stripe/subscription/trial_settings_test.exs` — nested struct decode
- [ ] `test/lattice_stripe/subscription_item_test.exs` — stubs for BILL-03 (SubscriptionItem CRUD)
- [ ] `test/integration/subscription_integration_test.exs` — stripe-mock integration skeleton
- [ ] `test/integration/subscription_item_integration_test.exs` — stripe-mock integration skeleton
- [ ] `test/support/fixtures/subscription.ex` — fixture module (templated from `customer.ex`)
- [ ] `test/support/fixtures/subscription_item.ex` — fixture module
- [ ] Extend `test/lattice_stripe/billing/guards_test.exs` with two new cases: items-array-with-proration, items-array-without

ExUnit + Mox already installed (no framework bootstrap needed).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `mix docs` renders `guides/subscriptions.md` cleanly under Billing module group | BILL-03 SC6 | HTML rendering + navigation structure is visual | `mix docs && open doc/index.html` — verify Billing group contains Subscription, SubscriptionItem, PauseCollection, CancellationDetails, TrialSettings and that the subscriptions guide appears in the sidebar |
| `Inspect.inspect(subscription)` hides PII | T-15-01 | Output inspection is subjective; automated regex-based check is added but visual sanity matters | `iex -S mix` → `LatticeStripe.Subscription.from_map(sample_json) |> IO.inspect()` — confirm no customer email, no payment_settings internals |

---

## Validation Sign-Off

- [ ] Planner populates per-task verification map in this file
- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (integration), < 5s (unit)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
