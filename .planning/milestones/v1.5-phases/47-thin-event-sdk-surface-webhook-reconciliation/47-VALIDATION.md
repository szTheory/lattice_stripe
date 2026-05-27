---
phase: 47
slug: thin-event-sdk-surface-webhook-reconciliation
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-27
---

# Phase 47 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (stdlib) + Mox ~> 1.2 |
| **Config file** | `test/test_helper.exs` (existing — declares `LatticeStripe.MockTransport`, `LatticeStripe.MockJson`, `LatticeStripe.MockRetryStrategy`) |
| **Quick run command** | `mix test test/lattice_stripe/webhook_test.exs test/lattice_stripe/event_notification_test.exs test/lattice_stripe/webhook/fetch_test.exs test/lattice_stripe/testing_test.exs test/lattice_stripe/event_test.exs test/lattice_stripe/object_types_test.exs test/lattice_stripe/webhook/plug_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~5s (quick) / ~30s (full) |
| **CI alias** | `mix ci` (format check + compile --warnings-as-errors + credo --strict + test + docs --warnings-as-errors) |

---

## Sampling Rate

- **After every task commit:** Run the **quick run command**
- **After every plan wave:** Run `mix test` (full suite)
- **Before `/gsd:verify-work`:** `mix ci` must be green
- **Max feedback latency:** ~5 seconds (quick) / ~30 seconds (full)

---

## Per-Task Verification Map

> Concrete Task IDs populate during `/gsd:execute-phase`; this table lists the per-requirement test obligations the planner must encode into task `acceptance_criteria`. See `47-RESEARCH.md` §Validation Architecture for the source.

| Req ID | Behavior | Test Type | Automated Command | File Exists | Status |
|--------|----------|-----------|-------------------|-------------|--------|
| THIN-01 | `parse_event_notification/4` happy path returns `{:ok, %EventNotification{}}` | unit | `mix test test/lattice_stripe/webhook_test.exs` | ❌ W0 | ⬜ pending |
| THIN-01 | `parse_event_notification/4` returns each verify_error atom (`:missing_header`, `:invalid_header`, `:no_matching_signature`, `:timestamp_expired`) | unit | (same) | ❌ W0 | ⬜ pending |
| THIN-01 | `parse_event_notification!/4` raises `SignatureVerificationError` on failure | unit | (same) | ❌ W0 | ⬜ pending |
| THIN-02 | `fetch_event/3` accepts `%EventNotification{}` and returns `{:ok, %Event{}}` via Mox transport | unit | `mix test test/lattice_stripe/webhook/fetch_test.exs` | ❌ W0 | ⬜ pending |
| THIN-02 | `fetch_event/3` accepts bare `String.t()` id form | unit | (same) | ❌ W0 | ⬜ pending |
| THIN-02 | `fetch_event/3` builds `/v2/core/events/{id}` URL (regression: NOT `/v1/events/`) | unit | (same) | ❌ W0 | ⬜ pending |
| THIN-02 | `fetch_event/3` honors `:api_version` + `:idempotency_key` opts | unit | (same) | ❌ W0 | ⬜ pending |
| THIN-02 | `fetch_event!/3` raises `LatticeStripe.Error` on HTTP error | unit | (same) | ❌ W0 | ⬜ pending |
| THIN-03 | `fetch_related_object/3` returns `{:ok, struct()}` typed via ObjectTypes dispatch for known type | unit | (same) | ❌ W0 | ⬜ pending |
| THIN-03 | `fetch_related_object/3` returns `{:error, {:unknown_object_type, type}}` BEFORE any HTTP call (Mox expectation count = 0) | unit | (same) | ❌ W0 | ⬜ pending |
| THIN-03 | `fetch_related_object/3` returns `{:error, :no_related_object}` when `related_object == nil` | unit | (same) | ❌ W0 | ⬜ pending |
| THIN-03 | `fetch_related_object/3` honors `:expand` opt | unit | (same) | ❌ W0 | ⬜ pending |
| THIN-03 | `fetch_related_object/3` uses `related_object.url` verbatim as request path | unit | (same) | ❌ W0 | ⬜ pending |
| THIN-04 | `Event.from_map/1` decodes v2 payload with `related_object` map → `%RelatedObject{}` struct | unit | `mix test test/lattice_stripe/event_test.exs` | ✅ extend | ⬜ pending |
| THIN-04 | `Event.t().related_object` is `nil` on snapshot v1 events (backwards compat) | unit | (same) | ✅ extend | ⬜ pending |
| THIN-04 | `EventNotification.from_map/1` decodes thin-event JSON shape (all known fields + extra) | unit | `mix test test/lattice_stripe/event_notification_test.exs` | ❌ W0 | ⬜ pending |
| THIN-04 | `Inspect` impl on `EventNotification` hides `:extra`, shows `id`/`type`/`created`/`livemode`/`related_object` | unit | (same) | ❌ W0 | ⬜ pending |
| WEBFIX-01 | `Webhook.verify_signature/4` with `tolerance: 0` returns `{:ok, ts}` for any-age timestamp | unit | `mix test test/lattice_stripe/webhook_test.exs` | ✅ rewrite :121 | ⬜ pending |
| WEBFIX-01 | `Webhook.Plug.init/1` accepts `tolerance: 0` (schema `:non_neg_integer`) | unit | `mix test test/lattice_stripe/webhook/plug_test.exs` | ✅ add | ⬜ pending |
| WEBFIX-01 | `Webhook.Plug.init/1` rejects `tolerance: -1` (`:non_neg_integer` still rejects negatives) | unit | (same) | ❌ W0 | ⬜ pending |
| WEBFIX-01 | `Webhook.Plug` end-to-end with `tolerance: 0` and an old timestamp returns 200 (not 400) | unit (Plug.Test) | (same) | ❌ W0 | ⬜ pending |
| WEBFIX-01 | CHANGELOG entry exists for v1.5 documenting the reconciliation | docs-truth regression | grep test in `test/lattice_stripe/docs_truth_test.exs` | ✅ extend | ⬜ pending |
| TESTING-01 | `Testing.generate_thin_event_payload/3` produces `{payload, sig_header}` that passes `parse_event_notification/4` | unit | `mix test test/lattice_stripe/testing_test.exs` | ✅ extend | ⬜ pending |
| TESTING-01 | `Testing.generate_thin_event_payload/3` accepts `nil` for `related_object_data` (snapshot-style v2 event) | unit | (same) | ❌ W0 | ⬜ pending |
| TESTING-01 | `Testing.event_notification/1` builds `%EventNotification{}` from a fixture map without signing | unit | (same) | ❌ W0 | ⬜ pending |
| TESTING-01 | `Testing.generate_webhook_payload/3` (existing snapshot helper) is unchanged | unit (regression) | (same) | ✅ exists | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/lattice_stripe/event_notification_test.exs` — new file. Covers THIN-04 `EventNotification` + `RelatedObject` from_map + Inspect.
- [ ] `test/lattice_stripe/webhook/fetch_test.exs` — new file. Covers THIN-02 + THIN-03 with Mox-driven `LatticeStripe.MockTransport`.
- [ ] `test/support/fixtures/event_notification.ex` — new fixture module. Canonical thin-event JSON maps (with/without `related_object`, with/without `context`).
- [ ] Extension to `test/lattice_stripe/webhook_test.exs` — new `describe "parse_event_notification/4"` block + rewrite of `:121` (tolerance: 0 semantics).
- [ ] Extension to `test/lattice_stripe/webhook/plug_test.exs` — `tolerance: 0` Plug-level case + negative-tolerance rejection case.
- [ ] Extension to `test/lattice_stripe/testing_test.exs` — `generate_thin_event_payload/3` + `event_notification/1` cases.
- [ ] Extension to `test/lattice_stripe/object_types_test.exs` — `fetch_module/1` `{:ok, _}` and `:error` cases.
- [ ] Extension to `test/lattice_stripe/event_test.exs` — `related_object` decode case + backwards-compat (nil on snapshot events) case.
- [ ] Extension to `test/lattice_stripe/docs_truth_test.exs` — CHANGELOG WEBFIX-01 grep regression.

*Framework install: none — all deps already in `mix.lock`.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| End-to-end against the real Stripe `/v2/events` endpoint | VERIFY-03 | Requires live Stripe API + thin-event-configured Event Destination | **Deferred to Phase 48** per ROADMAP scope split (GUIDE-03 + VERIFY-03 explicitly out of Phase 47) |

*All Phase-47 in-scope behaviors have automated verification.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies — 47-01..47-05 each include `<automated>` verify blocks (mix compile / mix test); Wave 0 file scaffolding is created in 47-01 task 3 (fixture) and the new test files are created in 47-02/47-04/47-05 as part of those plans.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify — every task across 47-01..47-05 runs either `mix compile --warnings-as-errors` or `mix test ...` at task completion.
- [x] Wave 0 covers all MISSING references (9 items above) — fixture file in 47-01; `event_notification_test.exs` in 47-01; `webhook/fetch_test.exs` in 47-04; `parse_event_notification/4` describe block + tolerance:0 test rewrite in 47-02/47-03; Plug schema + negative-tolerance cases in 47-03; testing helpers + cases in 47-05; object_types extension in 47-01; event_test extension in 47-01; docs_truth CHANGELOG regression in 47-03.
- [x] No watch-mode flags — all verify commands are one-shot (`mix test ...`, `mix compile --warnings-as-errors`); no `--listen-on-stdin`, `--stale`, or watcher invocations.
- [x] Feedback latency < ~5s (quick) / ~30s (full) — quick run is the 7-file mix test command above (~5s); full suite is `mix test` (~30s).
- [x] `nyquist_compliant: true` set in frontmatter after planner closes the per-task verify map — set above; per-task verify map is fully populated across all 5 plans.

**Approval:** approved 2026-05-27
