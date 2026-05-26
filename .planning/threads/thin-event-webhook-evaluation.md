# Thin-Event Webhook Evaluation

Updated: 2026-05-25

## Why this thread exists

The next serious engineering wedge after adoption closure is not generic `/v2`
support. LatticeStripe already ships `/v2` metering event stream support. The
real remaining webhook/platform gap is thin-event handling: how a modern Stripe
integrator verifies, acknowledges, resolves, and documents thin events without
confusing them with snapshot-style webhook payloads.

## Repo-truth findings to preserve

- The webhook foundation is already real and well-covered:
  - `LatticeStripe.Webhook` provides signature verification, secret rotation, and
    typed event construction.
  - `LatticeStripe.Webhook.Plug` provides Phoenix-friendly endpoint/router mounting,
    pass-through and handler modes, and raw-body handling.
  - `LatticeStripe.Event` already supports retrieve/list/stream APIs.
- The repo already ships `/v2` Billing Meter Event Stream support via
  `LatticeStripe.Billing.MeterEventStream`, so "support `/v2`" is not the actual wedge.
- Current docs and examples are still snapshot-biased: they assume
  `event.data["object"]` is the authoritative object shape and do not yet teach a
  thin-event fetch-after-verify path.

## Recommended wedge shape

Treat thin-event support as a focused webhook-platform milestone with these slices:

1. clarify the event model boundary: snapshot events versus thin events
2. add the minimal helper surface needed to resolve/fetch authoritative state after verification
3. extend tests and public testing helpers to cover thin-event-style payloads
4. publish the canonical Phoenix guidance for thin-event processing and Connect/context-aware follow-through

## Key footguns

- Snapshot-biased docs can cause adopters to treat thin-event payloads as if they
  contained authoritative full object state.
- `tolerance: 0` is currently documented as disabling staleness checks in
  `LatticeStripe.Webhook`, but current behavior/tests reject that path. This should
  be reconciled before expanding webhook semantics.
- `construct_event/4` currently raises on malformed JSON via `Jason.decode!`; any
  thin-event guidance should be explicit about which failures are verification
  failures versus payload-shape failures.
- There is no webhook integration proof yet for a thin-event-style fetch-after-verify path.

## Scope discipline

- Keep this work in LatticeStripe as low-level Stripe coverage and developer ergonomics.
- Do not move business workflow orchestration, entitlement state transitions, or
  dunning/operator policy into this repo.
- Prefer primitive-first helpers plus docs over a high-level workflow facade.

## Ordering

- Adoption closure stays first because public truth and first-run trust still lag shipped surface.
- Thin-event support is the first post-adoption code wedge.
- Tax remains the next serious breadth candidate after thin events unless fresh adopter evidence changes the order.
