---
phase: 63
slug: stripe-native-entitlements
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-27
---

# Phase 63 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `63-RESEARCH.md` § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) + Mox `~> 1.2` |
| **Config file** | `test/test_helper.exs` — `ExUnit.configure(exclude: [:integration, :fuse_integration, :otel_integration])`; `Mox.defmock(LatticeStripe.MockTransport, for: LatticeStripe.Transport)` |
| **Test support path** | `test/support` (compiled only in `:test` — `mix.exs:317`) |
| **Quick run command** | `mix test test/lattice_stripe/entitlements/` |
| **Full suite command** | `mix test` (baseline: 2114 tests, 0 failures, 1 skipped, 197 excluded) |
| **Integration command** | `mix test --include integration` (requires `docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest`) |
| **Estimated runtime** | ~2.5 seconds (full unit suite); < 5 seconds (quick) |

> **Do NOT use `mix ci` as a gate.** The alias includes `docs --warnings-as-errors`, which is RED at clean HEAD (42-warning pre-existing baseline). Research correction C-02.

---

## Sampling Rate

- **After every task commit:** `mix format --check-formatted && mix compile --warnings-as-errors && mix test test/lattice_stripe/entitlements/`
- **After every plan wave:** `mix test` (full unit suite) + `mix credo --strict`
- **Before `/gsd-verify-work`:** all five phase gates green —
  1. `mix test` — 0 failures
  2. `mix test --include integration` — stripe-mock running on :12111
  3. `mix docs` — exit 0, warning count ≤ dynamically-captured clean-HEAD baseline, and zero warning
     lines naming the new surface (`grep 'warning:' <log> | grep -ci entitle` == `0`, scoped to
     warning lines, not the whole log). Canonical command: `63-07-PLAN.md` Task 2 `<verify>` — note
     that both count assignments there carry `|| true`, since a counting grep exits 1 when it prints `0`
  4. `mix credo --strict` — 0 issues
  5. `mix test test/lattice_stripe/docs_truth_test.exs` — green (its own required CI lane)
- **Max feedback latency:** 5 seconds — **per-task sampling only**. This bounds the after-every-task
  command on line 37 (`mix format` + `mix compile` + the scoped `mix test`), which is the loop the
  executor runs dozens of times. **Phase gates are exempt** and are expected to take minutes: the
  Docker-backed integration run (pulling and starting `stripe/stripe-mock` on first use), the full
  `mix test` suite, and both `mix docs` builds. A slow phase gate is normal, not a hang and not
  flakiness — let it finish rather than interrupting and retrying.

---

## Per-Task Verification Map

> Seeded at plan time; task IDs are assigned by the planner. `/gsd-validate-phase` fills and signs off this table.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 63-01-T1 | 63-01 | 1 | ENT-01 | T-63-01 | N/A | unit (Mox) | `mix test test/lattice_stripe/entitlements/active_entitlement_test.exs` | 🆕 created by this task | ⬜ pending |
| 63-01-T2 | 63-01 | 1 | ENT-01 | T-63-01 | `list/3` raises `ArgumentError` with no `customer` **before** any transport call | unit (Mox, zero expects) | `mix test test/lattice_stripe/entitlements/active_entitlement_test.exs` | ✅ from 63-01-T1 | ⬜ pending |
| 63-05-T1 | 63-05 | 3 | ENT-01 | T-63-15 | N/A | integration | `mix test --include integration test/integration/entitlements_integration_test.exs` | 🆕 created by this task | ⬜ pending |
| 63-02-T2 | 63-02 | 2 | ENT-02 | — | N/A | unit (Mox multi-page) | `mix test test/lattice_stripe/entitlements/active_entitlement_stream_test.exs` | 🆕 created by this task | ⬜ pending |
| 63-02-T2 | 63-02 | 2 | ENT-02 | **T-63-02** | Page 2 preserves the `customer` filter — regression returns the whole account's entitlements (ASVS V4) | unit (Mox) | `mix test test/lattice_stripe/entitlements/active_entitlement_stream_test.exs` | ✅ same file | ⬜ pending |
| 63-02-T1 | 63-02 | 2 | ENT-03 | — | N/A | unit | `mix test test/lattice_stripe/entitlements/active_entitlement_test.exs` | ✅ from 63-01-T1 | ⬜ pending |
| 63-03-T3 | 63-03 | 2 | ENT-04 | T-63-09 | N/A | unit (Mox) | `mix test test/lattice_stripe/entitlements/feature_test.exs` | 🆕 created by this task | ⬜ pending |
| 63-03-T3 | 63-03 | 2 | ENT-04 | — | No DELETE verb exists on `Feature` | integration + structural | `mix test --include integration …` + `refute function_exported?(Feature, :delete, 2)` / `3` | ✅ same file | ⬜ pending |
| 63-04-T2 | 63-04 | 3 | ENT-05 | — | N/A | unit (pure) | `mix test test/lattice_stripe/entitlements/active_entitlement_summary_test.exs` | 🆕 created by this task | ⬜ pending |
| 63-04-T2 | 63-04 | 3 | ENT-05 | — | `refute Map.has_key?(%ActiveEntitlementSummary{}, :id)` — no-`id` design lock | unit (pure) | same | ✅ same file | ⬜ pending |
| 63-04-T2 | 63-04 | 3 | ENT-05 | T-63-12 / T-63-13 | Nested `entitlements` → `%LatticeStripe.List{data: [%ActiveEntitlement{}]}`, `has_more` preserved; `_last_id` non-nil; `url`/`_params` rewritten; `data: []` + `has_more: true` still deserializes | unit (pure) | same | ✅ same file | ⬜ pending |
| 63-01-T2 | 63-01 | 1 | Scope fence | T-63-04 | `refute function_exported?(ActiveEntitlement, :entitled?, 2/3/4)`; no `:create`/`:update`/`:delete` | structural | `mix test test/lattice_stripe/entitlements/active_entitlement_test.exs` | ✅ from 63-01-T1 | ⬜ pending |
| 63-03-T3 | 63-03 | 2 | Scope fence | — | `refute function_exported?(Feature, :delete/:archive/:unarchive/:retrieve_by_lookup_key)` | structural | `mix test test/lattice_stripe/entitlements/feature_test.exs` | ✅ same file | ⬜ pending |
| 63-07-T1 | 63-07 | 5 | Docs fence | T-63-04 / T-63-08 | Prose locks: `"gate"`, `"fail closed"`, `"stream!/3"`, `"no top-level"`, `"entitled?"` present | docs-truth | `mix test test/lattice_stripe/docs_truth_test.exs` | ✅ extend | ⬜ pending |
| 63-07-T1 | 63-07 | 5 | Docs | T-63-17 | `guides/entitlements.md` in both `extras:` and `groups_for_extras["Canonical Guides"]`; `Entitlements:` in `groups_for_modules` | docs-truth | same | ✅ extend | ⬜ pending |
| 63-07-T2 | 63-07 | 5 | Phase gate | T-63-19 | Differential docs gate: plain `mix docs` exits 0; post-change warning count ≤ the baseline captured by 63-01-T1; zero warnings naming the new surface | CLI | see `63-07-PLAN.md` Task 2 `<verify>` | ✅ baseline from 63-01-T1 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Every `MISSING` test reference is created by the plan named beside it, in the same task that needs it —
no task in this phase carries a `MISSING` automated verify.

- [ ] `test/support/fixtures/entitlements.ex` — `LatticeStripe.Test.Fixtures.Entitlements`, `@moduledoc false`, with `active_entitlement_json/1`, `active_entitlement_summary_json/1`, `feature_json/1`, `active_entitlement_list_json/2` → **63-01 Task 1**
- [ ] `test/support/test_helpers.ex` — extend `list_json/2` → `list_json(items, url, has_more \\ false)`; all existing call sites must still compile → **63-01 Task 1**
- [ ] `test/lattice_stripe/entitlements/active_entitlement_test.exs` — ENT-01 (63-01 T1), ENT-03 + `stream!` guard (63-02 T1), scope-fence locks (63-01 T2)
- [ ] `test/lattice_stripe/entitlements/active_entitlement_stream_test.exs` — ENT-02 pagination assertions + the customer-filter-preservation test → **63-02 Task 2**
- [ ] `test/lattice_stripe/entitlements/active_entitlement_summary_test.exs` — ENT-05 incl. the `_last_id` ordering lock → **63-04 Task 2**
- [ ] `test/lattice_stripe/entitlements/feature_test.exs` — ENT-04, no-DELETE locks → **63-03 Task 3**
- [ ] `test/integration/entitlements_integration_test.exs` — six verbs, `setup_all` raises if stripe-mock absent → **63-05 Task 1**
- [ ] `test/lattice_stripe/docs_truth_test.exs` — extend with the entitlements guide lock and the `guides/scope.md` lock → **63-07 Task 1**
- [ ] `.planning/phases/63-stripe-native-entitlements/docs-warning-baseline.txt` — clean-HEAD ExDoc warning count, captured **before** any `lib/` change → **63-01 Task 1** (consumed by 63-07 Task 2)

*Framework install: not required — ExUnit + Mox already present.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real pagination against live Stripe | ENT-02 | stripe-mock returns one item and ignores `limit`/`starting_after` — pagination is structurally unprovable there. Mox proves the SDK *constructs* correct page-2 requests, not that Stripe honors them. | With a live test key, list a customer with >1 active entitlement and confirm `stream!/3` yields all of them across pages. |
| Whether `/v1/customer/{cus}/entitlements` is callable | ENT-01 | Design routes around this endpoint entirely, so it is unfalsifiable-but-irrelevant. | None — accepted as out of scope. |
| `archived` filter real semantics | ENT-04 | stripe-mock accepts the param (200) but its synthetic response does not vary. Proven only by the spec description; mitigated by moduledoc. | With a live test key, archive a feature and confirm it is excluded from the default list. |
| `lookup_key` immutability on update | ENT-04 | Spec proves it structurally (`lookup_key` is absent from the update body schema); stripe-mock will not error on an extra param. | With a live test key, attempt to update `lookup_key` and confirm Stripe rejects or ignores it. |
| Real `active_entitlement_summary` webhook delivery | ENT-05 | No endpoint serves this object. Only proof is `from_map/1` against a hand-authored fixture matching Stripe's published payload. | Trigger a subscription change on a live account and inspect the delivered webhook payload. |

*Accepted risk: no live Stripe key is available for this phase. Spec + stripe-mock triangulation is the project's standing posture.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s for the per-task sampling command (phase gates exempt — see § Sampling Rate)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
