---
phase: 65
slug: webhook-objecttypes-testing-fixtures
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-28
validated: 2026-07-29
---

# Phase 65 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `65-RESEARCH.md` → `## Validation Architecture`. All baselines below were
> measured by execution during research, not estimated.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.19.5 stdlib). Mox `~> 1.2` is available but **not needed** this phase — every assertion is a pure decode or a structural/config check. |
| **Config file** | `test/test_helper.exs` — `ExUnit.configure(exclude: [:integration, :fuse_integration, :otel_integration])` |
| **Quick run command** | `mix test test/lattice_stripe/object_types_test.exs test/lattice_stripe/testing_test.exs` |
| **Full suite command** | `mix test` |
| **Docs-truth lane** | `mix test test/lattice_stripe/docs_truth_test.exs` (own CI lane, `ci.yml:217`) |
| **Estimated runtime** | ~5 seconds full suite; sub-second quick run |
| **Measured test baseline** | **2305 tests, 0 failures, 1 skipped, 214 excluded — 5.1s** |
| **Measured ExDoc baseline** | `mix docs` exit 0, **38 warnings**, **0** matching `entitlement\|meter\|testing\|fixture` |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/lattice_stripe/object_types_test.exs test/lattice_stripe/testing_test.exs`
- **After every plan wave:** Run `mix test` — full suite, count must be **≥ 2305**, never fewer
- **Before `/gsd-verify-work`:** The five-step differential phase gate below, all green
- **Once per phase (not per wave):** `MIX_ENV=prod mix compile` and `mix hex.build` — required
  because fixtures crossing from `test/support/` into `lib/` change what ships in the Hex tarball
- **Max feedback latency:** ~5 seconds

---

## ⚠ `mix ci` is NOT this phase's gate

`mix ci`'s final step is `docs --warnings-as-errors`, which is **RED at clean HEAD** on 38
pre-existing warnings (Tax.* nested types, `File.create/3`, `../README.md`, hidden `ObjectTypes` /
`BillingPortal.Guards` / `Webhook.check_tolerance`). Steps 1–4 pass. Clearing them is Phase
67-shaped work, out of scope here. Use the five-step differential gate instead.

### Phase gate (five differential steps)

1. `mix format --check-formatted && mix compile --warnings-as-errors` — green
2. `mix credo --strict` — green
3. `mix test` — green, count **≥ 2305** (never fewer). A single failure in `client_test.exs:912`
   or `batch_test.exs:72` is a **known pre-existing flake** — re-run once before treating it as a
   regression.
4. `mix docs` exits 0 **and** warning count **≤ 38** (never up). Measure with
   `mix docs 2>&1 | grep -c 'warning:'`.
5. **Zero** `mix docs` warnings matching the substring `entitlement`, `meter`, `testing`, or
   `fixture` — currently **0** for all four. Unconditional. If one appears, fix it at its cause.
   **Do not rescope the substring list to make the step pass** — Phase 63 (STATE `[63-07]`) and
   Phase 64 (D-29) both settled that rescoping a gate is the same move as raising a baseline.

### Not in the gate

`mix test --only integration` (needs stripe-mock). Phase 65 requires **no** integration tests.

---

## Per-Task Verification Map

> Task IDs are assigned when plans are written; this table was seeded from the requirement→behavior
> map in `65-RESEARCH.md` and **completed by 65-06 Task 2** from the executed run (2026-07-29).
> The `File Exists` column was seeded pre-execution, when every Wave 0 *case* was still unwritten;
> it now records the post-execution fact.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| T1 | 65-01 | 1 | OBJ-01 | — | `maybe_deserialize/1` → `%ActiveEntitlement{}` for `entitlements.active_entitlement` | unit | `mix test test/lattice_stripe/object_types_test.exs` | ✅ file + case | ✅ |
| T1 | 65-04 | 3 | OBJ-01 | — | `maybe_deserialize/1` → `%ActiveEntitlementSummary{}` and `refute Map.has_key?(result, :id)` | unit | same | ✅ file + case | ✅ |
| T1 | 65-04 | 3 | OBJ-01 | — | `maybe_deserialize/1` → `%MeterEvent{event_name: ...}` — **never** assert on `.object` (no such field; raises `KeyError`) | unit | same | ✅ file + case | ✅ |
| T1 | 65-04 | 3 | OBJ-01 | — | `maybe_deserialize/1` → `%MeterEventSummary{}` incl. float `aggregated_value` | unit | same | ✅ file + case | ✅ |
| T1 | 65-04 | 3 | OBJ-01 | — | `fetch_module/1` → `{:ok, Module}` for each of the four keys | unit (structural) | same | ✅ file + case | ✅ |
| T2 | 65-04 | 3 | OBJ-01 | T-65-01 | **`billing.meter_error_report` absent** from `@object_map` (`refute`) | unit (structural) | same | ✅ **already green** — pre-existing Phase 64 lock — **verified, not re-authored** (`grep -c` counts byte-identical to pre-plan) | ✅ |
| T2 | 65-04 | 3 | OBJ-01 | T-65-01 | Error-report `data` payload round-trips unchanged through `maybe_deserialize/1` | unit | same | ✅ **already green** — pre-existing Phase 64 positive twin, verified | ✅ |
| T2 | 65-04 | 3 | OBJ-01 | T-65-02 | No `webhook/fetch_test.exs` case regresses from the new `fetch_module/1` rows (`@object_map` also gates `Webhook.fetch_related_object/3`'s HTTP request) | unit (regression) | `mix test test/lattice_stripe/webhook/` | ✅ exists | ✅ (62 tests, 0 failures) |
| T2 | 65-01 | 1 | OBJ-02 | — | `Testing.Fixtures.Entitlements.{active_entitlement_json,active_entitlement_summary_json,feature_json,active_entitlement_list_json}` public, return maps | unit | `mix test test/lattice_stripe/testing_test.exs` | ✅ file + case | ✅ |
| T2 | 65-02 | 2 | OBJ-02 | — | Meter fixtures public (shape per Q1 = `flat-three`) and return maps | unit | same | ✅ file + case | ✅ |
| T2 | 65-01, 65-02 | 1, 2 | OBJ-02 | — | Typed wrappers in `LatticeStripe.Testing` return the right struct for each new entitlement/meter fixture | unit | same (`describe "typed wrappers"`) | ✅ file + case | ✅ |
| T2 | 65-01 | 1 | OBJ-02 | — | The **no-`id` summary** wrapper produces a struct with no `:id` | unit (structural) | same | ✅ file + case | ✅ |
| T1, T2 | 65-01, 65-02 | 1, 2 | OBJ-02 | — | The 4 entitlement + metering caller test files still compile and pass after the module rename (metering: **6** callers needed edits, not the 9 anticipated — 3 reference only fixtures that stay private under `flat-three`) | regression | `mix test` | ✅ all exist | ✅ |
| T2, T1 | 65-03, 65-05 | 3, 4 | OBJ-03 | — | `Testing.Fixtures.{Customer,Subscription,Invoice,PaymentIntent}` public, return maps, convert to typed structs | unit | `mix test test/lattice_stripe/testing_test.exs` | ✅ file + case | ✅ |
| T1 | 65-05 | 4 | OBJ-03 | — | `invoice_test.exs`'s existing ~19 assertions still pass against the promoted fixture | regression | `mix test test/lattice_stripe/invoice_test.exs` | ✅ exists — **0 assertion lines changed** | ✅ |
| T2, T2, T2, T1 | 65-01, 65-02, 65-03, 65-05 | 1, 2, 3, 4 | OBJ-01/02/03 | — | Every new public module appears in `groups_for_modules[:Testing]` (ExDoc **silently drops** ungrouped modules) | unit (config) | `mix test test/lattice_stripe/docs_truth_test.exs` | ✅ file + case — mutation-checked in 65-01, 65-03 and 65-05 | ✅ |
| T2, T2, T2, T1, T1 | 65-01, 65-02, 65-03, 65-05, 65-06 | 1, 2, 3, 4, 5 | OBJ-02/03 | — | `guides/testing.md`'s public-fixture bullet list names each new module (per-plan bullets, plus 65-06's consolidated all-8 lock) | unit (docs-truth) | same | ✅ file + case | ✅ |
| T2 | 65-06 | 5 | all | T-65-03 | Promoted fixtures compile outside `:test` | build | `MIX_ENV=prod mix compile` | n/a — **not covered by CI**, run as an explicit `<verify>` in every promoting plan and once at phase close | ✅ (exit 0) |
| T2 | 65-06 | 5 | all | T-65-03 | Hex tarball builds with the enlarged `lib/` | build | `mix hex.build` | ✅ CI Quality lane `ci.yml:257` | ✅ (exit 0; 229 entries, 18 fixture modules, 0 `test/support/` paths) |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

### Phase-close measurements (65-06 Task 2, 2026-07-29)

| Measurement | Value |
|---|---|
| `mix test` | **2332 tests, 0 failures, 1 skipped** (214 excluded) — baseline was 2305 |
| `mix docs` | exit **0**, **38** warnings (== baseline, not raised) |
| `mix docs` matches `entitlement` / `meter` / `testing` / `fixture` | **0 / 0 / 0 / 0** |
| `mix format --check-formatted` | exit 0 |
| `mix compile --warnings-as-errors` | exit 0 |
| `mix credo --strict` | exit 0 — 2303 mods/funs, no issues |
| `MIX_ENV=prod mix compile` | exit 0 |
| `mix hex.build` | exit 0 |
| `map_size(ObjectTypes.object_map())` | **52** |
| Known flakes (`client_test.exs:912`, `batch_test.exs:72`) | **neither fired** on any run |

---

## Wave 0 Requirements

No new test **files** are required — every target file already exists. Wave 0 is therefore
**cases, not files**:

- [x] `test/lattice_stripe/object_types_test.exs` — 5 new cases (4 positive dispatch + 1
      `fetch_module/1` group). **Also update its `alias` at line 5** if the metering fixtures move.
      *Discharged by 65-01 T1 (the entitlement tracer) and 65-04 T1/T2 — the file went from 30 to
      37 tests, with the fixture aliases retargeted by 65-01 and 65-02.*
- [x] `test/lattice_stripe/testing_test.exs` — extend `describe "public fixture builders"` (`:22`)
      and `describe "typed wrappers"` (`:244`); update the `alias LatticeStripe.{...}` block at `:4-17`.
      *Discharged by 65-01 T2, 65-02 T2, 65-03 T2 and 65-05 T1 — both describes extended, never
      duplicated.*
- [x] `test/lattice_stripe/docs_truth_test.exs` — a new ExDoc `groups_for_modules[:Testing]`
      placement assertion + a `guides/testing.md` prose assertion. *Discharged by 65-01 T2, 65-02 T2,
      65-03 T2, 65-05 T1, plus 65-06 T1's consolidated all-8 prose lock; 55 tests, mutation-checked.*
- [x] **Framework install:** none — ExUnit is stdlib and already configured.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| No live secrets ship in the Hex tarball | all | A grep is automatable but the *judgement* that a matched string is a placeholder is not | Before each fixture file enters `lib/`, run `grep -nE 'sk_live\|whsec_\|acct_1' <file>`; any hit must be replaced with an obviously-fake token. `mix.exs:325` `files: ["lib", ...]` means anything under `lib/` ships. |

Everything else has automated verification.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (cases, not files — see above)
- [x] No watch-mode flags
- [x] Feedback latency < 10s (full suite 3.4s measured at phase close)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** **APPROVED — all five differential gate steps green at phase close (2026-07-29).**
`mix format --check-formatted`, `mix compile --warnings-as-errors` and `mix credo --strict` all
exit 0; `mix test` reports **2332 tests, 0 failures, 1 skipped** against a floor of 2305; `mix docs`
exits 0 at **38** warnings (baseline held, not raised) with **0** matches for each of `entitlement`,
`meter`, `testing` and `fixture` (substring list not narrowed). The two once-per-phase build checks
both pass: `MIX_ENV=prod mix compile` exit 0 and `mix hex.build` exit 0 with all 18 public fixture
modules present under `lib/lattice_stripe/testing/fixtures/` and zero `test/support/` paths in the
tarball. Every row above is ✅ on evidence from the executed run; no row was marked green that the
run did not exercise.
