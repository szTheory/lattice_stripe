---
phase: 64
slug: meter-event-summary-reads
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-28
---

# Phase 64 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Seeded from `64-RESEARCH.md` § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.19.5 stdlib) + Mox `~> 1.2` for the `Transport` behaviour |
| **Config file** | `test/test_helper.exs` — `ExUnit.configure(exclude: [:integration, :fuse_integration, :otel_integration])` |
| **Quick run command** | `mix test test/lattice_stripe/billing/` |
| **Full suite command** | `mix test` |
| **Integration command** | `mix test --only integration` *(requires stripe-mock on :12111)* |
| **Estimated runtime** | ~3 seconds (full suite) |
| **Current baseline** | 2188 tests, 0 failures, 1 skipped, 204 excluded |

### ⚠ `mix ci` is NOT this phase's gate

`mix ci` is **RED at clean HEAD**, and not because of this phase — its final step
(`docs --warnings-as-errors`) trips on the 42 pre-existing ExDoc warnings recorded in STATE `[63-07]`.
Steps 1–4 of `mix ci` pass. Use the five-step differential gate below in its place.

---

## Sampling Rate

- **After every task commit:** `mix test test/lattice_stripe/billing/` — the tightest loop covering this
  phase's new modules and the guards they call. Sub-second.
- **After every plan wave:** `mix test` — full suite, ~3.0s, baseline 2188 passing. Never skip; running it
  is cheaper than deciding whether to.
- **Before `/gsd-verify-work`:** the five-step phase gate below must be green.
- **Max feedback latency:** 3 seconds.

### Phase gate (D-29's five steps — replaces the RED `mix ci`)

1. `mix format --check-formatted && mix compile --warnings-as-errors`
2. `mix credo --strict` — green
3. `mix test` — green, count **≥ 2188** (never fewer)
4. `mix docs` exits 0 **and** warning count **≤ 42** (never up)
   - *Required, not bonus:* the two fixable warnings are
     `lib/lattice_stripe/billing/meter_event_stream.ex:15` and `:24`
     (*"Illegal attributes […] ignored in IAL"*, from indented code-block lines beginning `{:ok, …}`).
     64-09 clears both as a hard acceptance criterion — measured as an exact **minus-two delta** around its
     own edits rather than against the absolute 42, since a same-wave plan may move the absolute underneath
     it. That clearing is what makes step 5 a single substring check.
5. **Zero** `mix docs` warnings matching the substring `meter`. **Unconditional — no fallback branch.**
   A substring keeps protecting when a file is added; an enumerated path list silently stops. If a warning
   naming a metering file is present here, that is a gate **failure** to be fixed at its cause. Do **not**
   rescope this step to an exact-path list to make it pass: rescoping a gate to route around what it caught
   is the same move as raising a baseline, and Phase 63 (STATE `[63-07]`) settled that the answer is to fix
   the warning. 64-10 carries this as an explicit prohibition.

### Not in the gate — run explicitly

`mix test --only integration`, after:

```
docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest
```

`mix test` **excludes** integration (204 excluded), so a green full suite is **not** evidence the
integration tests ran. stripe-mock is confirmed **not currently running** (Docker is up).

---

## Per-Task Verification Map

> Task IDs are assigned when PLAN.md files are written. The requirement → behavior → command mapping
> below is authoritative; `/gsd-validate-phase` binds each row to its task ID.

| Requirement | Behavior | Test Type | Automated Command | File Exists | Status |
|-------------|----------|-----------|-------------------|-------------|--------|
| MTR-01 | `list/4` builds `GET /v1/billing/meters/:id/event_summaries` with all four params | unit (Mox) | `mix test test/lattice_stripe/billing/meter_event_summary_test.exs` | ❌ W0 | ✅ green |
| MTR-01 | `from_map/1` types all 7 fields; `aggregated_value` is a float; no `:customer` key exists | unit | same | ❌ W0 | ✅ green |
| MTR-01 | `from_map(%MeterEventSummary{})` is idempotent (D-07) | unit | same | ❌ W0 | ✅ green |
| MTR-01 | three `require_param!` raises fire first-failure in order `customer`→`start_time`→`end_time`, D-08 verbatim messages | unit | same | ❌ W0 | ✅ green |
| MTR-01 | `validate_id!/2` raises on `nil` and `""` meter id, message per D-09 | unit | same | ❌ W0 | ✅ green |
| MTR-01 | GUARD-04 matrix: aligned passes; misaligned raises for divisor 60/3600/86400; unknown window passes through; absent/unparseable timestamps pass through | unit | `mix test test/lattice_stripe/billing/guards_test.exs test/lattice_stripe/billing/meter_guards_test.exs` | ⚠️ files exist, cases ❌ W0 | ✅ green |
| MTR-01 | surface refutation: `retrieve/2,3`, `create/2,3`, `update/3,4`, `delete/2,3`, `stream/3`, `align_window/2` absent; **`list/2,3` NOT refuted** | unit (structural) | `mix test test/lattice_stripe/billing/meter_event_summary_test.exs` | ❌ W0 | ✅ green |
| MTR-01 | `Billing.Meter.event_summaries/3,4` absent (stripe-java#1852 lock) | unit (structural) | `mix test test/lattice_stripe/billing/meter_test.exs` | ⚠️ file exists, case ❌ W0 | ✅ green |
| MTR-01 | live path served; three required-param 400s in order; enum rejection; served body decodes | integration | `mix test --only integration test/integration/meter_event_summary_integration_test.exs` | ❌ W0 — needs stripe-mock | ✅ green |
| MTR-02 | D-30's nine assertions (cursor from last `mtrusg_` id; page 2 preserves all four filters; N pages = N calls; `Stream.take(1)` = 1 call; `stripe-account` carries; no `idempotency-key` on page 2; page-2 path = response `url`; page-2 500 raises `LatticeStripe.Error`; `_last_id` derived before typing) | unit (Mox, multi-page) | `mix test test/lattice_stripe/billing/meter_event_summary_pagination_test.exs` | ❌ W0 | ✅ green |
| MTR-03 | `from_map/1` decodes verbatim published payload incl. `developer_message_summary`, `validation_start`, `validation_end` (N-01) | unit (pure) | `mix test test/lattice_stripe/billing/meter_error_report_test.exs` | ❌ W0 | ✅ green |
| MTR-03 | `request_identifier` resolves (the join key); also resolves from legacy `%{"idempotency_key" => …}` shape | unit (pure) | same | ❌ W0 | ✅ green |
| MTR-03 | `assert is_binary(code)` — encodes D-18's no-atomization decision | unit (pure) | same | ❌ W0 | ✅ green |
| MTR-03 | `refute Map.has_key?(struct, :id)` / `:object` / `:livemode` (encodes D-17) | unit (structural) | same | ❌ W0 | ✅ green |
| MTR-03 | missing `error_types` → `[]` not `nil` (D-19) | unit (pure) | same | ❌ W0 | ✅ green |
| MTR-03 | `sample_errors: []` with `error_count: 900` still decodes (real high-volume shape) | unit (pure) | same | ❌ W0 | ✅ green |
| MTR-03 | `from_map(data).meter == nil` while `from_event/1` populates it (D-16 as asserted contract) | unit (pure) | same | ❌ W0 | ✅ green |
| MTR-03 | a `no_meter_found`-shaped event with `related_object: nil` decodes (F-17/N-06) | unit (pure) | same | ❌ W0 | ✅ green |
| MTR-03 | `list/2,3`, `retrieve/2,3`, `create/2,3` absent; `from_map/1` + `from_event/1` present | unit (structural) | same | ❌ W0 | ✅ green |
| MTR-03 | `ObjectTypes` has no `billing.meter_error_report` key (D-14/D-31) | unit (structural) | `mix test test/lattice_stripe/object_types_test.exs` | ⚠️ file exists, case ❌ W0 | ✅ green |
| MTR-04 | exact-body round-trip: three custom dimensions + decimal-string value | unit | `mix test test/lattice_stripe/form_encoder_test.exs` | ⚠️ file exists (27 tests, zero float/decimal), cases ❌ W0 | ✅ green |
| MTR-04 | `encode(%{"v" => 0.00001}) == "v=1.0e-5"` — locks known behavior so the doc warning cannot silently become false | unit | same | ❌ W0 | ✅ green |
| MTR-04 | `MeterEvent.create/3` does not filter `payload` keys | unit (Mox at transport, assert `req.body`) | `mix test test/lattice_stripe/billing/meter_event_test.exs` | ⚠️ file exists, case ❌ W0 | ✅ green |
| MTR-04 | flat dimensions → 200 **and** nested payload → 400 (only proof of the Stripe-side half; would have caught F-20.2) | integration | `mix test --only integration` | ❌ W0 — needs stripe-mock | ✅ green |
| MTR-04 | ExDoc **placement** assertion extended to Phase 64's five new modules (D-26's structural exception) | unit (config) | `mix test test/lattice_stripe/docs_truth_test.exs` | ⚠️ file exists, case ❌ W0 | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/lattice_stripe/billing/meter_event_summary_test.exs` — MTR-01 (surface, guards, `from_map`, refutations)
- [x] `test/lattice_stripe/billing/meter_event_summary_pagination_test.exs` — MTR-02 (D-30's nine assertions)
- [x] `test/lattice_stripe/billing/meter_error_report_test.exs` — MTR-03 (pure, no transport)
- [x] `test/integration/meter_event_summary_integration_test.exs` — MTR-01 wire behavior + MTR-04's nested-payload 400
- [x] `test/support/fixtures/` — a metering fixture module seeded from the **verbatim published payload**
      (D-32), carrying the `PROMOTION TARGET (Phase 65)` header comment cloned from
      `test/support/fixtures/entitlements.ex`
- [ ] New cases in existing files: `guards_test.exs` / `meter_guards_test.exs` (GUARD-04 matrix),
      `form_encoder_test.exs` (float + decimal, currently zero), `meter_event_test.exs` (no-filter proof),
      `meter_test.exs` (`event_summaries` refutation), `object_types_test.exs` (dead-key refutation),
      `docs_truth_test.exs` (ExDoc placement)
- [ ] Framework install: **none needed** — ExUnit + Mox already present and green

**No new test framework, runner, or helper is required.** `TestHelpers.list_json/3` already supports
`has_more`; `req.body` is already exposed on the transport request map.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live Stripe error-report event shape | MTR-03 | stripe-mock does not emit v2 thin events; requires a real test-mode account with a misconfigured meter | Send a meter event with an unknown `event_name` in test mode; observe the `v1.billing.meter.error_report_triggered` event; compare against the fixture payload |
| Async error-code classification (O-06) | MTR-04 | `archived_meter`, `timestamp_in_future`, `timestamp_too_far_in_past` are documented as sync 400s *and* appear in the async error-report enum; which path fires is not verifiable offline | When rewriting `metering.md`'s error table, do **not** restate the "Silent drop?" column as fact for these three — mark them unverified |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 3s (full suite 2.6s)
- [x] Integration suite run explicitly against a running stripe-mock (not inferred from a green `mix test`)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
