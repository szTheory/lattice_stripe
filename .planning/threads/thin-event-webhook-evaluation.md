# Thin-Event Webhook Evaluation

Updated: 2026-05-27 (v1.5 assessment pass added concrete API surface + reference SDK)

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

## v1.5 assessment additions (2026-05-27)

Concrete shape locked in by the v1.5 next-milestone assessment (see
`v1-5-next-milestone-assessment.md`). Selected as the v1.5 milestone pick.

### Reference SDK

- **stripe-node v49+** exposes `parseEventNotification` which returns
  `Stripe.V2.EventNotification` carrying `relatedObject` plus
  `fetchRelatedObject()` and `fetchEvent()` methods. This is the cleanest
  cross-SDK pattern to mirror in Elixir.
- stripe-python and stripe-go leave fetch-after-verify as separate client
  calls with no thin-event helper — lower DX but simpler. LatticeStripe should
  ship explicit helpers because Elixir-idiomatic ergonomics is part of the
  project's DNA per `prompts/`.

### Concrete API surface to ship

- `Webhook.parse_event_notification/3` — parallel to `construct_event/3` but
  returns a thin-event notification struct.
- `Webhook.fetch_event/2` — typed `Event.t()` retrieval.
- `Webhook.fetch_related_object/2` — returns the underlying typed resource via
  the existing `ObjectTypes` dispatch (reuses v1.2 expand machinery).
- Extend the `Event` struct to surface `context` and `related_object` cleanly
  (`context` already exists; `related_object` is new for the thin-event shape).
- Extend `Testing` helpers to emit thin-event payload shapes alongside snapshot
  payloads.

### Reconciliations / bug fixes required

- **`Webhook.check_tolerance/2` `tolerance: 0` semantics.** Docstring at
  `lib/lattice_stripe/webhook.ex:84` says "Set 0 to disable staleness check"
  but the code path at `lib/lattice_stripe/webhook.ex:268-273` always returns
  `{:error, :timestamp_expired}` for the `0` clause. Fix as part of v1.5 since
  thin-event work touches webhook semantics anyway.
- `construct_event/4` raises on malformed JSON via `Jason.decode!` — document
  the verification-vs-payload-shape failure boundary explicitly in the new
  guide.

### Rate-limit guidance to include in `guides/webhooks-thin-events.md`

- Keep webhook delivery under ~90 events/sec to stay safely below Stripe's
  100 req/sec ceiling, since fetch-after-verify doubles the call rate.
- Show idempotency via app-side dedup keyed on `event.id`, not on the fetched
  resource state (the resource can change between webhook send and fetch).
- Show Connect/context-aware routing using the `event.context` field.

### Estimated effort

Medium — 1 phase with 3-5 plans. Net-new helpers, extended Testing module,
one canonical Phoenix guide, integration test coverage, plus the
`tolerance: 0` reconciliation bundled in.
