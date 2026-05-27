# Phase 53: Operator Guides - Research

**Researched:** 2026-05-27
**Domain:** Documentation (operator playbooks) + docs-truth regression + ExDoc/README/JTBD discovery wiring
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Asymmetric trust-rail pair — `production-checklist.md` ~180–220 lines; `event-debugging.md` ~220–280 lines; Phase 48 `webhooks-thin-events.md` tone and posture.
- **D-02:** Hybrid checklist spine with inline essentials only where launch fails silently; 9+ sections + quick checklist; cross-link to canonical guides.
- **D-03:** Hybrid symptom spine for event debugging; build vs diagnose boundary; snapshot vs thin decision table; symptom index; no duplicate of webhooks.md setup prose.
- **D-04:** Phase 48 docs-truth pattern only (no adoption_contract_test); ExDoc order `client-configuration → production-checklist → webhooks → webhooks-thin-events → event-debugging → error-handling → …`; README/JTBD wiring; v1.7 install canary on both guides only.
- **D-05:** Bounded Charge references — shared guardrail verbatim; support subsection in checklist; one paragraph in event-debugging; no `guides/charges.md`.

### Claude's Discretion
- Exact anchor strings for docs-truth grep blocks
- Whether to assert ExDoc ordering within group (membership sufficient)
- Symptom index table row wording
- Optional `webhooks-thin-events.md` forward link

### Deferred Ideas (OUT OF SCOPE)
- `guides/charges.md`, README Charge adoption ladder, global `~> 1.7` flip (Phase 54), adoption_contract_test, LiveBook inspector, DLQ/worker topologies, comprehensive 500+ line runbooks
</user_constraints>

<architectural_responsibility_map>
## Architectural Responsibility Map

Single-tier documentation phase — all capabilities reside in the docs/discovery layer.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Pre-launch operator checklist prose | `guides/production-checklist.md` | Canonical ops guides (linked) | Composes trust rails; does not own behavior truth |
| Post-incident event debugging prose | `guides/event-debugging.md` | webhooks.md, webhooks-thin-events.md | Diagnose boundary; build stays in sibling guides |
| ExDoc discovery | `mix.exs` extras + `groups_for_extras` | — | Operations & DX group membership |
| README/JTBD ladder | README.md, user-flows-and-jtbd.md | — | Intent-based routing |
| Regression locks | `test/lattice_stripe/docs_truth_test.exs` | — | Phase 48 3A–3E pattern extended |
</architectural_responsibility_map>

<research_summary>
## Summary

Phase 53 is a **pure documentation and discovery phase** — no new `lib/` API surface. It mirrors Phase 48's proven playbook: write two trust-rail guides, wire them into ExDoc `Operations & DX`, extend the README hardening route and JTBD Job 7 Read next, add reverse cross-links from `webhooks.md`, `error-handling.md`, and `testing.md`, and lock anchors via `docs_truth_test.exs`.

The codebase already has everything the guides teach: `Client.new!/1`, Finch supervision patterns in `client-configuration.md` and `performance.md`, `Webhook.Plug` + `CacheBodyReader`, `parse_event_notification/4` / `fetch_event/3`, `%LatticeStripe.Error{request_id: _}`, telemetry events including `[:lattice_stripe, :webhook, :verify, :stop]`, and Phase 52 `Charge.list/3` / `Charge.search/3` for support lookups. The planner should **compose and route**, not re-document.

**Primary recommendation:** Plan as four plans in two waves — Wave 1 parallel guide authoring (53-01 production-checklist, 53-02 event-debugging); Wave 2 discovery wiring (53-03) then docs-truth locks (53-04, depends on 53-03). Copy Phase 48's docs-truth test structure verbatim: extend the ExDoc group test, add per-guide content locks, v1.7 install canary, and cross-link graph test.
</research_summary>

<standard_stack>
## Standard Stack

### Core (this phase)
| Asset | Location | Purpose |
|-------|----------|---------|
| Trust-rail template | `guides/webhooks-thin-events.md` (~199 lines) | Tone, anchor opener, install canary, cross-link discipline |
| Docs-truth pattern | `test/lattice_stripe/docs_truth_test.exs` | Grep locks for ExDoc, content anchors, cross-links |
| ExDoc grouping | `mix.exs` `Operations & DX` | Layered ops guide discovery |
| Phase 48 research | `.planning/milestones/v1.5-phases/48-*/48-RESEARCH.md` | Prior art for guide + test planning |

### Canonical guides to link (do not duplicate)
| Guide | Lines (approx) | Checklist uses | Debugging uses |
|-------|----------------|----------------|----------------|
| `client-configuration.md` | — | Client.new!, idempotency | — |
| `webhooks.md` | — | Plug order, raw body | Signature failures (link) |
| `webhooks-thin-events.md` | 199 | /v2/events pointer | Snapshot vs thin table |
| `error-handling.md` | — | request_id support | fetch-after-verify errors |
| `telemetry.md` | — | observability checklist | verify event names |
| `performance.md` | — | Finch pool, supervision | — |
| `testing.md` | 577 | smoke tests link | See also reverse link |
| `connect-money-movement.md` | — | Connect fee reconciliation | — |

### Alternatives Considered
| Instead of | Could use | Why not |
|------------|-----------|---------|
| Two thin link indexes | Full runbooks | CONTEXT D-01 rejects; competes with testing.md |
| adoption_contract_test | docs_truth only | No new wire-path surface (CONTEXT D-04) |
| Global `~> 1.7` flip now | Per-guide v1.7 canary | Phase 54 lockstep (Phase 48 B2 pattern) |
</standard_stack>

<architecture_patterns>
## Architecture Patterns

### Discovery ladder flow
```
README hardening route → operator guides → canonical ops guides → moduledoc/deep refs
JTBD Runtime truth + Job 7 Read next → same cluster
ExDoc Operations & DX → ordered group (membership + hybrid position)
```

### Phase 48 docs-truth extension map (3A–3E analog for Phase 53)
| Lock | Test target | Anchors |
|------|-------------|---------|
| 3A | Extend `"exdoc keeps the primary public truth surfaces published"` | Both guides in `extras` + `Operations & DX` |
| 3B | `production-checklist` content lock | keys, webhook, idempotency, Finch, telemetry, D-14 phrase, cross-links |
| 3C | `event-debugging` content lock | snapshot/thin, verify vocab, fetch-after-verify, `request_id`, `event.id` |
| 3D | v1.7 install canary | `{:lattice_stripe, "~> 1.7"}` on both guides only |
| 3E | Cross-link graph | forward + reverse + README + JTBD |

### ExDoc insertion (locked in CONTEXT D-04)
Current `mix.exs` Operations & DX order:
```
client-configuration → webhooks → webhooks-thin-events → error-handling → testing → …
```
Target order:
```
client-configuration → production-checklist → webhooks → webhooks-thin-events →
event-debugging → error-handling → testing → … (remainder unchanged)
```

### README insertion points (verified)
- Line 43–44 hardening route: add Production Checklist first, Event Debugging after Thin Events
- Docs ladder / ops feature section / HexDocs index: add both guides + thin-events index gap if missing

### JTBD insertion points (verified)
- Line 95–96 Runtime truth route: add both guides alongside webhooks cluster
- Line 334–342 Job 7 Read next: Production Checklist + Event Debugging at top

### Charge reference pattern (D-05)
Shared guardrail (verbatim both guides):
> Charge is the **result record** of a payment attempt, not payment initiation. Use `PaymentIntent` for payment flows; use `Charge` to read/reconcile existing charges.

Checklist: ~8–12 line "Support & audit lookups" — `Charge.list/3`, `Charge.search/3`, search lag caveat, link `connect-money-movement.md`.
Debugging: ~1 paragraph under `charge.*` events — follow `payment_intent` when present; anti-pattern: no `Charge.search/3` for fresh payments.

### Anti-Patterns to Avoid
- **Re-documenting webhook setup:** Link `webhooks.md` / `webhooks-thin-events.md`
- **IO.inspect on payloads:** PII/credential leak (Phase 48 WR-05)
- **Locking tunable defaults in docs-truth:** Lock topic anchors only (retry counts, pool sizes)
- **Teaching Charge.capture in operator guides:** Out of scope per D-05
</architecture_patterns>

<dont_hand_roll>
## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Webhook verification logic | New prose in operator guides | Link `webhooks.md` | Single source of truth |
| Idempotency implementation | Full Ecto recipe in checklist | Inline one-liner + link `client-configuration.md` | Checklist is gate, not manual |
| Charge API teaching | `guides/charges.md` | `LatticeStripe.Charge` moduledoc + bounded refs | Phase 52 deferred |
| Ops regression surface | adoption_contract_test | docs_truth_test.exs grep blocks | Phase 48 precedent |
| Install version truth globally | Flip README to 1.7 now | Per-guide canary until Phase 54 | B2 architecture |
</dont_hand_roll>

<common_pitfalls>
## Common Pitfalls

### Pitfall 1: Checklist becomes second webhooks.md
**What goes wrong:** production-checklist duplicates Plug setup, rate limits, Ecto idempotency sketch.
**How to avoid:** One minimal snippet per phase; cross-link for depth (D-02).
**Warning signs:** Guide exceeds ~220 lines or repeats webhooks.md headings verbatim.

### Pitfall 2: event-debugging teaches build not diagnose
**What goes wrong:** Full Phoenix controller spine duplicated from webhooks-thin-events.md.
**How to avoid:** Symptom → cause → fix table at top; link to build guides (D-03 boundary).
**Warning signs:** New controller code blocks >15 lines.

### Pitfall 3: Cross-link graph incomplete
**What goes wrong:** Guides exist but README/JTBD/reverse links missing — silent discovery regression.
**How to avoid:** Single docs-truth test locking full graph (Phase 48 3D pattern).
**Warning signs:** `mix test test/lattice_stripe/docs_truth_test.exs` passes but README grep fails.

### Pitfall 4: Install canary leaks globally
**What goes wrong:** Accidentally changing README `~> 1.3` during Phase 53.
**How to avoid:** Docs-truth asserts 1.7 only on new guides; existing 1.3 tests unchanged (D-04).
</common_pitfalls>

<code_examples>
## Code Examples

### Minimal checklist snippets (inline essentials only)
```elixir
# Client — env-based keys (link client-configuration.md for full options)
client = LatticeStripe.Client.new!(api_key: System.fetch_env!("STRIPE_SECRET_KEY"))
```

```elixir
# endpoint.ex — Webhook.Plug BEFORE Plug.Parsers (one canonical snippet)
plug LatticeStripe.Webhook.Plug, handler: MyApp.StripeWebhookHandler
plug Plug.Parsers, ...
```

```elixir
# Support path — request_id from errors (link error-handling.md)
%LatticeStripe.Error{request_id: request_id} = error
```

### event-debugging diagnostic vocabulary (grep-lock targets)
- Verify errors: `:missing_header`, `:invalid_header`, `:no_matching_signature`, `:timestamp_expired`
- Fetch path: `request_id`, `event.id`, `Webhook.fetch_event`, `parse_event_notification`
- Replay: `stripe events resend`, at-least-once, Dashboard Resend footgun
- Telemetry: `[:lattice_stripe, :webhook, :verify, :stop]`

### docs-truth test skeleton (from Phase 48)
```elixir
test "production-checklist guide locks the operator pre-launch contract" do
  guide = File.read!("guides/production-checklist.md")
  assert guide =~ "Client.new!"
  assert guide =~ "Webhook.Plug"
  # ... D-02 anchor set from CONTEXT
end
```
</code_examples>

## Validation Architecture

| Requirement | Automated Command | File Exists | Notes |
|-------------|-------------------|-------------|-------|
| OPS-01 guide exists + anchors | `mix test test/lattice_stripe/docs_truth_test.exs --only production_checklist` (or full file) | Wave 2+ | Content lock test name TBD in plan |
| OPS-02 guide exists + anchors | same | Wave 2+ | event-debugging content lock |
| ExDoc placement | `"exdoc keeps the primary public truth surfaces published"` | ✅ | Extend assertions |
| Cross-link graph | dedicated test | Wave 2+ | README + JTBD + reverse links |
| No lib regression | `mix test` (full or docs_truth subset) | ✅ | Docs-only phase — no new lib code |

**Wave 0:** Not required — test infrastructure exists.
**Sampling:** After each plan wave, run `mix test test/lattice_stripe/docs_truth_test.exs`.

<sota_updates>
## State of the Art

| Pattern | LatticeStripe precedent | Phase 53 action |
|---------|------------------------|-----------------|
| Trust-rail guide ~200 lines | Phase 48 webhooks-thin-events | Same for operator pair |
| Install canary per milestone | 1.5 on thin-events only | 1.7 on both operator guides |
| Ops persona JTBD Gap 2 | THREAD assessment | Close with operator spine |
| Charge support lookups | Phase 52 list/search | Bounded refs only (D-05) |
</sota_updates>

<open_questions>
## Open Questions

1. **ExDoc ordering assertion strictness**
   - Recommendation: Assert group membership only; optional order comment in plan discretion.

2. **webhooks-thin-events forward link**
   - Recommendation: Add if low-cost; not required for phase success.

3. **JTBD-MAP.md matrix update**
   - Recommendation: Planning artifact update in 53-03 if time permits; not docs-truth gated.
</open_questions>

<sources>
## Sources

### Primary (HIGH confidence)
- `.planning/phases/53-operator-guides/53-CONTEXT.md` — locked decisions
- `guides/webhooks-thin-events.md` — template
- `test/lattice_stripe/docs_truth_test.exs` — Phase 48 locks
- `mix.exs` — ExDoc groups
- `.planning/milestones/v1.5-phases/48-*/48-RESEARCH.md` — prior phase pattern

### Secondary (MEDIUM confidence)
- Stripe docs: integration checklist vs troubleshooting split (operator spine rationale in CONTEXT)
- Oban production hexdoc structure (checklist calibration per DISCUSSION-LOG)
</sources>

<metadata>
## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all files exist in repo
- Architecture: HIGH — Phase 48 direct precedent
- Pitfalls: HIGH — from CONTEXT + Phase 48 retrospective
- Code examples: HIGH — from existing guides and tests

**Research date:** 2026-05-27
**Valid until:** 2026-06-27
</metadata>

---

## RESEARCH COMPLETE

*Phase: 53-operator-guides*
*Research completed: 2026-05-27*
*Ready for planning: yes*
