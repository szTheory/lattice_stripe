# Phase 20: Billing Metering - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `20-CONTEXT.md` — this log preserves the alternatives considered
> and the research rationale from the 4 parallel gsd-advisor-researcher agents.

**Date:** 2026-04-14
**Phase:** 20 — Billing Metering
**Areas discussed:** GUARD-01 scope & severity; MeterEvent Inspect masking; Plan wave structure & splits; guides/metering.md depth
**Research method:** 4 parallel `gsd-advisor-researcher` agents, one per gray area, each given full context on the other 3 for coherence

---

## Gray Area A — GUARD-01 scope, severity, and formula input surface

**Research question:** How should `LatticeStripe.Billing.Meter.create/3` handle the value_settings silent-zero trap? What severity, what scope, what implementation location, and does it also normalize atom formula values on write?

**Options considered:**

| Option | Description | Selected |
|---|---|---|
| A. Strict `ArgumentError`, sum+last, nested check, inline in `Meter.create/3` (literal ROADMAP reading) | Hard fail whenever `value_settings` is absent for sum/last formulas | |
| B. Soft `IO.warn/2`, sum+last, inline | Non-blocking dev-time nudge | |
| C. Hybrid: hard `ArgumentError` only for present-but-malformed value_settings + `Logger.warning/1` for count + value_settings + accept omitted value_settings silently; helper in `Billing.Guards` | Honors Stripe's `"value"` default; raises only on genuinely broken shapes | ✓ |
| D. NimbleOptions schema for entire create params | Declarative validation | |

**Research finding (critical correction):** Stripe's API documents `value_settings.event_payload_key` defaulting to `"value"` when `value_settings` is omitted. The REQUIREMENT text and ROADMAP success criterion 2 are therefore **over-strict relative to Stripe's wire semantics** — a guard that raises on omission would reject legal code paths and break parity with stripe-node/ruby/python/stripity_stripe. The silent-zero trap only fires when `value_settings` is present-but-malformed (empty or missing `event_payload_key` inside).

**User's choice:** Option C (hybrid)
**Notes:** CONTEXT.md D-01 amends ROADMAP success criterion 2 accordingly. Logger.warning chosen over IO.warn to avoid stacktrace noise in test output. String keys only on the wire; atom-keyed params bypass the guard and Stripe's HTTP layer handles them cleanly (single-representation discipline per Phase 17 D-04c). Helper lives in existing `LatticeStripe.Billing.Guards` namespace alongside `check_proration_required/2`.

**Ecosystem lessons that shaped the decision:**
- **Ecto.Changeset `validate_required/3`** raises `ArgumentError` only for programmer errors (missing field in schema), never for user data — analogous principle: raise on "you wrote broken Elixir", return error on "server will reject this"
- **Plug.Parsers** raises on malformed input at boundary, lets well-formed pass through untouched
- **Finch / NimbleOptions** validates only finite closed client-config schemas, never per-request params
- **stripe-node / stripe-ruby / stripe-python** — none of them client-side-validate `value_settings` presence for meters; they pass params through and let the API respond
- **Phase 15 `Subscription.pause_collection/5`** atom-guard — positional closed-enum pattern, **does not apply** to nested map params (Phase 17 D-04c already ruled)

---

## Gray Area B — MeterEvent Inspect masking

**Research question:** Should `%MeterEvent{}.payload` be masked when the struct is inspected? If so, how?

**Options considered:**

| Option | Description | Selected |
|---|---|---|
| A. Allowlist Inspect, hide payload entirely | Render `#LatticeStripe.Billing.MeterEvent<event_name:, identifier:, timestamp:, created:, livemode:>`; hide payload and any field outside the allowlist | ✓ |
| B. Show payload keys, mask the customer-mapping value | `payload: %{"stripe_customer_id" => "[FILTERED]", "value" => 1.5}` | |
| C. Don't mask; payload is user-owned data | Rely on Logger `filter_parameters` at application level | |
| D. Compile-time `Mix.env()` switch | Mask in prod, visible in dev | |

**Research finding (key correction):** The existing LatticeStripe Inspect pattern (`customer.ex:467+`, `checkout/session.ex`) is **allowlist-based**, not field-level substitution. It renders a curated set of structural fields and hides everything else. Option A is the natural extension of this pattern; Option B would be a net-new pattern with ongoing drift risk as Stripe adds customer-mapping key variants.

**User's choice:** Option A (allowlist)
**Notes:** Masks the entire `:payload` field. Debugging escape hatches (`IO.inspect(event, structs: false)` and `event.payload`) are documented in `guides/metering.md` per D-05. GUARD-01 ensures `%MeterEvent{}` reaching Inspect has a populated payload (so masking is never vacuous). Phase 21 will apply the same pattern to `BillingPortal.Session.url`, completing the pattern across v1.1.

**Ecosystem lessons:**
- **Ecto** does NOT mask changeset fields (no `defimpl Inspect` on `Ecto.Changeset`)
- **Plug.Conn.body_params** is unmasked; Phoenix handles via `config :phoenix, :filter_parameters` at Logger level
- **Swoosh.Email** does not mask recipients
- **Finch.Request / Req.Request** do not mask bodies
- **Guardian / Phoenix.Token** DO treat tokens as opaque — LatticeStripe sits closer to this end of the spectrum than the Plug.Conn end

---

## Gray Area C — Plan wave structure & splits

**Research question:** Confirm or adjust the 6-plan wave structure from research SUMMARY.md. Should 20-04 split MeterEvent from MeterEventAdjustment? Parallelize 20-03 and 20-04? Build a full MeterEventAdjustment struct or return raw map?

**Options considered:**

| Dimension | Option | Selected |
|---|---|---|
| Split 20-04? | (a) Keep MeterEvent + Adjustment in one plan | ✓ |
| | (b) Split into 20-04a + 20-04b | |
| | (c) Merge Adjustment into 20-03 | |
| Parallelize 20-03 ↔ 20-04? | (a) Sequential | ✓ |
| | (b) Parallel in two worktrees | |
| Adjustment struct depth? | (a) Full typed struct with `from_map/1`, `@known_fields`, `:extra`, nested `Cancel` struct | ✓ |
| | (b) Return raw map | |
| Split 20-01 wave 0? | (a) Keep as one plan (3 fixtures + 3 probes) | ✓ |
| | (b) Split fixtures from probe | |
| Absorb 20-05 into 20-03/20-04? | (a) Keep separate | ✓ |
| | (b) Absorb into resource plans | |
| Split 20-06 guide from ExDoc? | (a) Keep together | ✓ |
| | (b) Split | |

**User's choice:** All (a) options — the 6-plan wave structure from research is confirmed with no splits and no parallelization. Sequential execution, 5 waves.
**Notes:** Phase 20 mirrors Phase 17's shape exactly. Divergences are all content-level (what goes inside each plan), not structure-level. MeterEventAdjustment getting a full struct (~40 LOC cost) is the correct tradeoff to avoid the inconsistency tax of returning `{:ok, map()}` from exactly one endpoint. Parallelism savings (~20 min) are not worth fixture-file collision coordination cost.

**LOC sanity check:** 6 plans, ~660 LOC src + ~1280 LOC test + ~360 LOC doc = ~60% of Phase 17's size. No plan below ~200 LOC (avoiding trivial-plan anti-pattern); no plan exceeds ~700 LOC.

**Ecosystem lessons:**
- **Ecto** multi-resource PRs bundle "new module + tests + docs" as one unit
- **Phoenix LiveView** adds new components as single-PR "concept + implementation + guide + changelog" bundles
- **Swoosh** adapter additions: one PR per adapter with adapter module + test + README section
- **stripity_stripe** ships resources as monolithic files with no equivalent planning structure — Phase 20 sets the precedent

---

## Gray Area D — guides/metering.md depth

**Research question:** How exhaustive should `guides/metering.md` be? Error-code catalog breadth, dunning-correction worked example, batch-flush anti-pattern section, hot-path recipe depth, cross-links, formula semantics depth, GUARD-01 escape hatch, length target.

**Options considered and selected (all 8 sub-questions):**

| Q | Sub-question | Decision |
|---|---|---|
| 1 | Error code breadth | Exhaustive compact table (7 rows) — only Elixir reference for metering |
| 2 | Dunning worked example | Include full ~45-line example (not 100) showing exact `cancel.identifier` shape |
| 3 | Batch-flush anti-pattern | Include, with wrong-way code in `> **Warning:**` box followed by right way |
| 4 | Hot-path recipe depth | Full `AccrueLike.UsageReporter` module (~40 lines), not a 20-line function |
| 5 | Cross-links out | All 5: subscriptions, webhooks, telemetry, error-handling, testing |
| 6 | Formula semantics depth | Deep dive — 1 paragraph per formula + when-to-use + one example each |
| 7 | GUARD-01 escape hatch | Document both — why the guard exists + one-line `Client.request/4` bypass with "only for porting" framing |
| 8 | Length target | 580 lines ± 40 — matches `invoices.md` (556), exceeds `subscriptions.md` (407) |

**User's choice:** All comprehensive options (as recommended by advisor agent)
**Notes:** Metering is the single differentiator over stripity_stripe (which has no metering guide at all). Undersizing means every downstream consumer reinvents the retry classifier and rediscovers `cancel.identifier` the hard way. Hard stops: if draft >700 lines, cut dunning example to reference-only; if <450, error-code table or formula section is too shallow.

**Ecosystem lessons:**
- **stripe-node "Record usage" docs** — structured (create → send → aggregate → bill) but weak on errors; adopt mental-model opener, exceed on reconciliation
- **stripe-python metered billing** — heavy prose, no two-layer idempotency explanation; treat our two-layer block as a unique contribution
- **stripity_stripe** — no metering guide at all; confirmed gap we own
- **Laravel Cashier** — exposes `reportUsage()` one-liner; document the hot-path recipe because Accrue (Cashier-analogue) will wrap it into a one-liner
- **Ecto migration guides** — use `> **Warning:**` for destructive/irreversible operations; adopt exactly

**Key snippets committed to the guide (full drafts in research agent output, reproduced as code in CONTEXT.md §D-05):**
- Snippet A: `AccrueLike.UsageReporter` hot-path module with Task.Supervisor + telemetry + error classification
- Snippet B: Two-layer idempotency side-by-side (`identifier` body field vs `idempotency_key:` opt)
- Snippet C: Batch-flush anti-pattern (wrong way → right way)
- Snippet D: 7-row error code reconciliation table

---

## Claude's Discretion

Left to planner/executor judgment (see CONTEXT.md Claude's Discretion section for full list):
- Exact field order in nested structs (follow Stripe API doc order)
- Exact moduledoc wording and examples (follow Phase 14-17 conventions)
- Test fixture shapes (follow existing fixture module conventions)
- stripe-mock integration test coverage depth (mirror Phase 17/18)
- ExDoc group placement ("Billing Metering" after "Billing", before "Connect")
- Whether integration tests split into 1 or 3 files (recommend 3 per research)
- Whether hot-path `UsageReporter` appears as moduledoc doctest (recommend guide-only)

---

## Deferred Ideas

- **D-07: `customer_mapping` presence guard** — not in Phase 20; track as post-ship candidate
- **Formula atom normalization on write** — rejected in D-06; revisit as uniform SDK policy if Accrue feedback surfaces it
- **MeterEventAdjustment webhook reconcile example** — extend guide post-ship if requested
- **Hot-path `UsageReporter` as moduledoc doctest** — Claude's discretion; currently guide-only
- **Meter EventSummary aggregate queries** — v1.2+ scope (separate Stripe API family)
- **`/v2/billing/meter_event_stream`** — v1.1 D3 locked deferral
- **Property-based tests for MeterEvent idempotency** — v1.2+ scope with broader StreamData rollout
- **Parallelization of Plan 20-03 and 20-04** — technically valid, deferred for commit-log cleanliness

---

*Generated: 2026-04-14*
*4 parallel advisor research agents, one per gray area, run concurrently with cross-awareness of sibling decisions*
