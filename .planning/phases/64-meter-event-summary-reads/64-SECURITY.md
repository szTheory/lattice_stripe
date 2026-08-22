---
phase: 64
slug: meter-event-summary-reads
status: verified
# threats_open counts OPEN threats at or above workflow.security_block_on severity.
threats_open: 0
asvs_level: 1
block_on: high
created: 2026-08-22
---

# Phase 64 — Security

> Per-phase security contract for meter event summary reads, metering error reports,
> pagination, documentation truth, and the differential release gate.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Caller → `MeterEventSummary.list/4` and `stream!/4` | Adopter-controlled meter IDs and time-window parameters enter request construction | Stripe resource IDs and Unix timestamps |
| Caller → `MeterEvent.create/3` | An adopter-controlled payload map enters form encoding | Customer mapping and billable values |
| `LatticeStripe.List` → Stripe API | The library reconstructs requests after page 1 | Tenant header, filters, cursor, and request options |
| Stripe webhook → adopter handler | A delivered thin-event body is attacker-reachable and contains no trusted event data | Notification metadata |
| `Webhook.fetch_event/3` → Stripe API | The handler re-fetches the versioned event over an authenticated channel | Authoritative event payload |
| `MeterErrorReport` → adopter logs | Default inspection can expose diagnostic idempotency keys | Auth-adjacent identifiers |
| Documentation → adopter implementation | Shipped examples and API claims guide production integrations | Trust and encoding assumptions |
| Integration tests → stripe-mock | Tests use a local, unauthenticated first-party mock with no live credentials | Synthetic API requests and fixtures |
| Phase gate → release decision | Recorded commands and baselines determine whether the phase advances | Verification evidence |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-64-01 | Tampering | Meter ID path interpolation | medium | mitigate | `validate_id!/2` rejects invalid IDs before request construction in both list and stream entry points; guard and ordering tests are recorded in 64-01/03/05 summaries. | closed |
| T-64-02 | Information Disclosure / Elevation | Tenant header on page 2+ | high | mitigate | Pagination delegates to `LatticeStripe.List`, and `meter_event_summary_pagination_test.exs` directly asserts preservation of `stripe-account`. | closed |
| T-64-03 | Information Disclosure | Customer filter on page 2+ | high | mitigate | Base parameters survive pagination; a per-filter assertion and mutation check cover the otherwise-undetectable customer-filter drop. | closed |
| T-64-04 | Tampering | Idempotency-key replay on paginated GETs | medium | mitigate | Pagination tests prove the page-1 key is stripped from page-2 options. | closed |
| T-64-05 | Information Disclosure | Idempotency keys in default `Inspect` output | medium | accept | The keys are the diagnostic payload; module and guide documentation explicitly warn that raw inspection emits them so adopters can control logging. See AR-64-01. | closed |
| T-64-06 | Denial of Service | Atom creation from server-controlled error codes | high | mitigate | Error codes remain binaries; `meter_error_report_test.exs` asserts `is_binary/1`, with a negative source grep for atom conversion. | closed |
| T-64-07 | Denial of Service | Wide-window pagination and memory use | medium | mitigate | Single-page reads are Stripe-limit bounded; stream documentation points to `Stream.take/2`, and pagination tests prove `Stream.take(1)` makes one request. | closed |
| T-64-08 | Spoofing / Tampering | Trusting data from a delivered thin event | high | mitigate | `MeterErrorReport.from_event/1` accepts the fetched `Event` shape, and both shipped handlers now call `Webhook.fetch_event/3` before decoding. | closed |
| T-64-09 | Tampering | Float stringification changing a billed value | medium | mitigate | `form_encoder_test.exs` locks behavior on both sides of the `1.0e-5` exponent boundary; documentation warns users to send exact decimals as strings. | closed |
| T-64-10 | Tampering | Nested event payload rejected by Stripe | low | mitigate | The explicit stripe-mock integration suite proves nested payload rejection; the earlier accepted limitation is superseded by test evidence. | closed |
| T-64-11 | Tampering | Registry entry for an unreachable payload | low | mitigate | Refutation tests cover dispatch behavior and the phase gate proves `lib/lattice_stripe/object_types.ex` is unchanged from the pre-phase commit. | closed |
| T-64-12 | Tampering | Misaligned summary window returning the wrong total | medium | mitigate | `check_summary_window!/2` raises before network access and reports the arithmetic without silently choosing floor or ceil. | closed |
| T-64-13 | Denial of Service | Guard rejects a future Stripe grouping value | low | mitigate | Unknown grouping-window values pass through; a named test locks the forward-compatible behavior. | closed |
| T-64-14 | Tampering | Nil cursor silently truncates pagination | high | mitigate | Pagination assertions require an `mtrusg_`-prefixed binary cursor and mutation-check cursor derivation ordering. | closed |
| T-64-15 | Tampering | False encoding documentation causes wrong billed values | high | mitigate | Both false number/string claims were replaced with the actual float hazard and tied to encoder assertions. | closed |
| T-64-16 | Repudiation | Unverified error classification presented as fact | medium | mitigate | The three affected rows are explicitly labelled unverified and explain the evidence boundary. | closed |
| T-64-17 | Repudiation | Scope documentation omits an API limitation | medium | mitigate | `guides/scope.md` now records that dimensions are write-only on the generally available API; docs-truth checks cover the statement. | closed |
| T-64-18 | Repudiation | Skipped integration suite mistaken for evidence | medium | mitigate | Integration `setup_all` raises when stripe-mock is absent, and the phase gate records an explicit run with 10 tests, 0 failures, and 0 excluded. | closed |
| T-64-19 | Repudiation | New modules omitted from published documentation | low | mitigate | Structural assertions cover all five modules and both guide registrations; the final gate also parses generated sidebar output. | closed |
| T-64-20 | Repudiation | Documentation-warning baseline silently raised | medium | mitigate | The differential gate records 38 warnings, documents both decreases, and forbids raising the baseline to pass. | closed |
| T-64-21 | Tampering | Unnoticed dependency change | medium | mitigate | The final gate compares `mix.lock` to pre-phase commit `a22e197` and records no changes. | closed |
| T-64-SC | Tampering | Package installs / local stripe-mock image | high | accept | No runtime or development packages were installed and `mix.lock` is unchanged; the only image is Stripe's first-party mock used locally with synthetic data. See AR-64-02. | closed |

*Status: open · closed · open — below high threshold (non-blocking)*

*Severity: critical > high > medium > low; only open threats at or above `high` count toward `threats_open`.*

*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party).*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-64-01 | T-64-05 | Idempotency keys are necessary diagnostic correlation data. Suppressing them from the value object would defeat the feature; explicit documentation lets adopters keep raw values out of inappropriate logs. | Phase 64 plan (D-19) | 2026-07-28 |
| AR-64-02 | T-64-SC | The phase added no packages. The official `stripe/stripe-mock` image is isolated to local integration tests, carries no production credentials or account data, and is absent from the shipped dependency graph. | Phase 64 plans and differential gate | 2026-07-28 |

*Accepted risks do not resurface in future audit runs unless their assumptions change.*

---

## Security Audit 2026-08-22

| Metric | Count |
|--------|-------|
| Threats found | 22 |
| Closed | 22 |
| Open | 0 |

The register was authored at plan time and every plan has a completed summary. At configured
ASVS level 1, summary claims and targeted source/test grep evidence are sufficient. The
secure-phase short-circuit applies because no open threat remains; no L2/L3 auditor was run.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-08-22 | 22 | 22 | 0 | Codex secure-phase orchestrator (ASVS L1) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-08-22
