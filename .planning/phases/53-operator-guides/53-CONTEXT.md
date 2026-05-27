# Phase 53: Operator Guides - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship two operator playbooks — `guides/production-checklist.md` (OPS-01) and `guides/event-debugging.md` (OPS-02) — and wire them into ExDoc `Operations & DX`, the README discovery ladder, JTBD-MAP operator routes, and docs-truth regression locks.

**In scope:** Prose operator guides that **compose** existing Operations & DX trust rails (webhooks, error-handling, testing, telemetry, client-configuration, performance) into scannable pre-launch and post-incident playbooks. Docs-truth grep locks (Phase 48 pattern). Cross-link graph updates to sibling guides.

**Explicitly out of scope:** New SDK API surface; `guides/charges.md` or Charge adoption-ladder entries (Phase 52 deferred); README/getting-started global install-line flip to `~> 1.7` (Phase 54); `adoption_contract_test.exs` (Phase 51 pattern reserved for resource-family wire-path UAT); Accrue territory (DLQ/worker topologies, dunning replay, entitlement orchestration); LiveBook event inspector; Flagship Recipe elevation.

</domain>

<decisions>
## Implementation Decisions

### Guide shape & depth — asymmetric trust-rail pair (D-01)
- **D-01:** Adopt **Option B with Option A's discipline** — asymmetric trust-rail siblings, not comprehensive runbooks (Option C) or link-only indexes (Option D).
- **`production-checklist.md`:** **~180–220 lines.** Pre-launch gate with one anchor rule, phased checklist sections, **one minimal inline snippet per phase**, heavy cross-links to canonical guides.
- **`event-debugging.md`:** **~220–280 lines.** Symptom → cause → fix spine with decision table at top; LatticeStripe-specific diagnostic traces; link into canonical guides for implementation depth.
- **Anchor openers:**
  - Checklist: *"Production Stripe integrations fail at boundaries — keys, raw bodies, idempotency, and observability."*
  - Debugging: *"Debug from the delivery boundary inward: Dashboard → HTTP status → signature → payload shape → dispatch."* Reuse D-14 lineage: *"Your app starts work. Webhooks confirm reality."*
- **Tone:** Assertive, low-magic, Phase 48 `webhooks-thin-events.md` posture — trust rail, not Flagship Recipe workflow playbook.
- **Do not:** Re-document full webhook setup, duplicate telemetry handler recipes, or compete with `testing.md` (577 lines) as a second ops manual.

### Production checklist composition — hybrid spine (D-02)
- **D-02:** **Hybrid checklist spine + minimal inline essentials + deep links** (not pure cross-link index, not consolidated standalone repeating content).
- **Inline essentials only where launch fails silently:**
  - Env-based `Client.new!` (not hardcoded keys)
  - Finch in supervision tree before first API call
  - `Webhook.Plug` before `Plug.Parsers` (minimal `endpoint.ex` snippet — canonical path only)
  - D-14 webhook truth rule (API responses = accepted now; webhooks = confirmed truth)
  - `%LatticeStripe.Error{request_id: _}` in logs/support path
  - Idempotency: SDK auto-keys on POST + explicit keys for money-moving writes
- **Section outline (9 sections + quick checklist):**
  1. Audience and scope (SDK integration hygiene; Stripe Dashboard account setup → link Stripe account checklist; post-launch → `event-debugging.md`)
  2. Quick checklist (12–16 one-line printable items covering all six ROADMAP topics)
  3. API keys and environments → `client-configuration.md`, `getting-started.md`
  4. Client and Finch production wiring → `performance.md`
  5. Webhook verification and endpoints → `webhooks.md`, `webhooks-thin-events.md` (if using `/v2/events`)
  6. Idempotency and safe retries → `client-configuration.md`, `error-handling.md`, `metering.md`
  7. Error handling and support posture → `error-handling.md`
  8. Telemetry and observability → `telemetry.md`, `opentelemetry.md`
  9. Resilience (recommended before scale) → `performance.md`, `circuit-breaker.md`
  10. Connect platforms (if applicable) → `connect.md`
  11. Final smoke tests → `testing.md`
  12. Read next → `event-debugging.md` + sibling ops guides
- **Depth ownership:** Canonical guides own behavior truth; checklist composes and routes. Do not lock tunable defaults (retry counts, pool sizes) in docs-truth — lock topic anchors only.

### Event debugging guide — hybrid symptom spine (D-03)
- **D-03:** **Hybrid symptom spine** (~220–280 lines) — not a troubleshooting link index (Option A) or net-new integration workflows duplicating Phase 48 (Option B).
- **Boundary rule:** *How to build* → `webhooks.md` / `webhooks-thin-events.md`; *how to diagnose production pain* → `event-debugging.md`.
- **Must-add vs existing guides (JTBD Gap 2 closure):**
  - Snapshot vs thin decision table + wrong-entry-point symptom (mostly-nil struct from `construct_event` on thin payload)
  - Symptom index table (400 verify fail, 500 after verify, duplicates, missing events, handler timeouts)
  - Signature verification diagnostic checklist (CLI vs Dashboard secret, raw body, Plug order, `:timestamp_expired`)
  - Fetch-after-verify failures: log `request_id` from `%LatticeStripe.Error{}`; rate-limit 429 symptoms; fetch races (idempotency on `event.id`, not resource state)
  - Replay semantics: at-least-once delivery; Stripe automatic retries; local `stripe events resend` vs Dashboard Resend footgun
  - Telemetry wiring: `[:lattice_stripe, :webhook, :verify, :stop]` + request events with `request_id`
  - Dispatch pattern debug lens (2xx-after-enqueue, 5xx retry storm, Connect `event.context` routing)
- **Must not duplicate:** Full thin Phoenix controller, Ecto idempotency sketch, rate-limit tables, Plug setup prose from `webhooks.md`.
- **Section outline:** Start here (snapshot vs thin) → Symptom index → Signature verification failures → Fetch-after-verify debugging → Delivery/replay/Stripe retries → Common dispatch patterns → Observability checklist → See also.

### Discovery wiring & docs-truth contract (D-04)
- **D-04:** **Phase 48 operator-guide pattern** — docs-truth grep in `docs_truth_test.exs` only; no `adoption_contract_test.exs`.
- **ExDoc hybrid placement** in `mix.exs` `Operations & DX`:
  ```
  client-configuration → production-checklist → webhooks → webhooks-thin-events →
  event-debugging → error-handling → testing → … (remainder unchanged)
  ```
  Rationale: checklist is cross-cutting operator entry; event debugging is webhook trust-rail sibling.
- **README wiring (augment, do not replace):**
  - Hardening route: add Production Checklist first, Event Debugging after Thin Events
  - Docs ladder ops bullet: add both guides
  - Operations and diagnostics feature section: mention operator playbooks
  - HexDocs index: add thin-events (existing gap) + both operator guides
  - Do NOT change README install block (`~> 1.3`) until Phase 54
- **JTBD wiring:**
  - Runtime truth route: add both guides alongside existing webhooks/error/testing cluster
  - Job 7 Read next: add Production Checklist + Event Debugging at top (pre-launch framing)
  - No new Job 8 — same scope discipline as Phase 48 D-04
- **Reverse cross-links:**
  - `webhooks.md` closing section → `event-debugging.md` (mirror thin-events closing pattern)
  - `error-handling.md` See also → both operator guides
  - `testing.md` See also → `event-debugging.md`
  - Optional: `webhooks-thin-events.md` → `event-debugging.md`
- **Install-line canary (Phase 48 B2 pattern extended):** Both new guides include `{:lattice_stripe, "~> 1.7"}` install snippet early. Docs-truth test locks `~> 1.7` on both guides only. README/getting-started/cheatsheet/thin-events canary stay unchanged until Phase 54 lockstep flip.
- **Docs-truth test structure (4 new + 1 extend):**
  - Extend `"exdoc keeps the primary public truth surfaces published"` — both guides in extras + Operations & DX group
  - New: production-checklist content lock (keys, webhook, idempotency, Finch, telemetry, D-14 phrase, cross-links)
  - New: event-debugging content lock (snapshot/thin, verify failure vocab, fetch-after-verify, `request_id`, `event.id`, cross-links)
  - New: v1.7 install canary on both guides
  - New: cross-link graph (forward from guides + reverse from webhooks/error-handling + README + JTBD)

### Charge reconciliation references — bounded asymmetric (D-05)
- **D-05:** **Asymmetric bounded references** — not zero Charge mentions (wastes Phase 52), not full list/search teaching in both guides (de facto `guides/charges.md`).
- **Shared guardrail** (verbatim in both guides): Charge is the **result record** of a payment attempt, not payment initiation. Use `PaymentIntent` for payment flows; use `Charge` to read/reconcile existing charges. Full API: `LatticeStripe.Charge` moduledoc (no separate Charge guide in v1.7).
- **`production-checklist.md`:** ~8–12 line "Support & audit lookups" subsection — PI-first routing; when to use `Charge.list/3` / `Charge.search/3`; search eventual-consistency caveat; link to `connect-money-movement.md` for Connect fee reconciliation (do not duplicate fee walk). Omit `capture`, `update`, `stream!` from checklist.
- **`event-debugging.md`:** ~1 paragraph under `charge.*` events — follow `payment_intent` when present; `Charge.retrieve/3` for charge-specific fields; **anti-pattern**: do not use `Charge.search/3` for fresh payments (search lags).
- **Do not:** Add Charge to README/JTBD adoption ladder; create `guides/charges.md`; teach `Charge.capture/4` in operator guides.

### Claude's Discretion
- Exact anchor strings for docs-truth grep blocks (implementation detail)
- Whether to assert ExDoc ordering within Operations & DX group (fragile — group membership sufficient)
- Exact wording of symptom index table rows
- Optional `webhooks-thin-events.md` forward link to event-debugging
- `.planning/JTBD-MAP.md` coverage matrix update timing (planning artifact; not docs-truth gated unless planner chooses)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope & requirements
- `.planning/ROADMAP.md` — Phase 53 goal, success criteria OPS-01/OPS-02
- `.planning/REQUIREMENTS.md` — OPS-01, OPS-02; out-of-scope table
- `.planning/threads/v1-7-next-milestone-assessment.md` — Gap 2 operator spine; Gap 1 Charge wedge
- `.planning/JTBD-MAP.md` — Gap 2 production operator spine; planned guide paths

### Prior phase decisions (guide-family pattern)
- `.planning/milestones/v1.5-phases/48-thin-event-adoption-surface-guide-integration-verification/48-CONTEXT.md` — D-01 guide shape (~140–220 lines, Operations & DX sibling), D-03 docs-truth 3A–3E pattern, D-04 discovery wiring, B2 install canary
- `.planning/phases/52-charge-surface-expansion/52-CONTEXT.md` — no `guides/charges.md`; Charge may appear in operator context; PI-first D-06 reframed
- `.planning/RETROSPECTIVE.md` — layered ExDoc grouping; docs-truth as regression surface; scope fence in canonical guides

### Domain & ops research (prompts/)
- `prompts/stripe-sdk-api-surface-area-deep-research.md` — webhook ops, snapshot vs thin, raw-body invariant
- `prompts/stripe-lib-priority-user-flows-deep-research.md` — webhooks as Tier-4 first-class surface; ops persona
- `prompts/payments_domain_field_guide.md` — raw-body #1 pain point; at-least-once delivery; critical event taxonomy
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — layered guides/extras; minimal stable public API
- `prompts/phoenix-best-practices-deep-research.md` — secrets, endpoint ordering, thin web layer

### Implementation templates (existing guides)
- `guides/webhooks-thin-events.md` — tone, length (~199 lines), anchor opener, trust-rail posture (primary template)
- `guides/webhooks.md` — raw-body invariant, Plug setup, troubleshooting bullets to link (not duplicate)
- `guides/error-handling.md` — `request_id` support escalation primitive
- `guides/telemetry.md` — default logger + webhook verify events
- `guides/client-configuration.md` — Client.new!, Finch, idempotency keys
- `guides/performance.md` — Finch pool sizing, supervision tree
- `guides/connect-money-movement.md` — Connect fee reconciliation via Charge.retrieve (link target)
- `lib/lattice_stripe/charge.ex` — PI-first moduledoc; list/search/update/capture surface reference
- `test/lattice_stripe/docs_truth_test.exs` — docs-truth grep pattern (webhooks-thin-events locks as template)
- `mix.exs` — ExDoc `Operations & DX` group definition

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- 29 existing guides; Operations & DX siblings range ~119–577 lines (median ~280)
- Phase 48 `webhooks-thin-events.md` (199 lines) — proven trust-rail template
- `docs_truth_test.exs` — 12+ existing tests; webhooks-thin-events 3A–3E pattern to extend
- README hardening route (line 43–44) and Job 7 Read next (lines 334–342) — discovery insertion points
- `Charge.list/search/update/capture` (Phase 52) — support subsection reference only

### Established Patterns
- Discovery ladder: README route-by-intent → JTBD → canonical/ops guides → deep references
- Docs-truth locks **anchors** (module names, topic phrases, cross-links), not full prose snapshots
- Phase 48 B2 install canary: new version-gated guide claims honest version; global flip deferred to capstone
- Accrue fence: SDK documents Stripe mechanics + observability hooks, not billing-engine orchestration
- Four-surface triangulation for code (moduledoc + code + tests + docs-truth); prose guides use docs-truth + cross-link graph only

### Integration Points
- `mix.exs` extras + `groups_for_extras` — add two guides at hybrid positions
- `README.md` — hardening route, docs ladder, ops feature section, HexDocs index
- `guides/user-flows-and-jtbd.md` — Runtime truth route + Job 7 Read next
- `guides/webhooks.md`, `guides/error-handling.md`, `guides/testing.md` — reverse cross-links
- Phase 54 will consume v1.7 canaries for lockstep install-line flip

</code_context>

<specifics>
## Specific Ideas

- Stripe official pattern: integration quickstarts separate from signature troubleshooting and undelivered-event operations — LatticeStripe mirrors with build guides vs debug playbook
- Oban `Ready for Production` hexdoc: short essential sections + copy-paste config + links — good checklist calibration for Elixir OSS
- stripe-node: `constructEvent` verify-vs-JSON-parse split mirrors LatticeStripe tuple-vs-raise boundary — debug doc names symptom, links to API
- Dashboard Resend vs `stripe events resend` CLI footgun — must appear in event-debugging replay section
- Do not teach `IO.inspect/1` on webhook payloads — PII/credential leak risk (Phase 48 WR-05)
- Search eventual-consistency caveat for Charge.search — explicit anti-pattern for fresh-payment debugging

</specifics>

<deferred>
## Deferred Ideas

- **`guides/charges.md` canonical guide** — Phase 52 deferred; operator guides route to moduledoc only
- **README/JTBD Charge adoption ladder entry** — not Phase 53; Charge discoverable via operator support subsection + moduledoc
- **Global `~> 1.7` install-line flip** — Phase 54 REL-03 capstone
- **`adoption_contract_test.exs` for operator guides** — no new wire-path surface; docs-truth sufficient
- **LiveBook event inspector** — Phase 48 deferred polish candidate
- **DLQ/worker topologies, Oban replay recipes** — Accrue territory
- **Comprehensive ops runbooks** (~500+ lines each) — wrong tier; would compete with testing.md/telemetry.md

</deferred>

---

*Phase: 53-operator-guides*
*Context gathered: 2026-05-27*
