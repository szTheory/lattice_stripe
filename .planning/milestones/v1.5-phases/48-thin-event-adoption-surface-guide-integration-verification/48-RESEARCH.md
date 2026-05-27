# Phase 48: Thin-Event Adoption Surface — Research

**Researched:** 2026-05-27
**Domain:** Docs (canonical Phoenix guide) + integration-test coverage + docs-truth regression net + one `Webhook.Plug` `@moduledoc` extension
**Confidence:** HIGH

## Summary

Phase 48 is **not a code-API phase**. Every helper the new guide teaches — `parse_event_notification/4`, `fetch_event/3`, `fetch_related_object/3`, `Testing.generate_thin_event_payload/3`, `ObjectTypes.fetch_module/1`, the `%EventNotification{}` / `%RelatedObject{}` struct pair, and the WEBFIX-01 `tolerance: 0` reconciliation — landed in Phase 47 and is verified at 6/6 must-haves. The only `lib/` edit in Phase 48 is the one-line `Webhook.Plug` `@moduledoc` Configuration Options extension that closes Phase 47 deferred WR-04. Phase 48 produces the adoption surface: one canonical Phoenix-friendly guide (`guides/webhooks-thin-events.md`), one chained-roundtrip Mox-at-Transport integration test file (`test/lattice_stripe/webhook/thin_event_test.exs`), and the extension of `test/lattice_stripe/docs_truth_test.exs` that locks the new guide content + ExDoc placement + cross-link graph + Plug `@moduledoc` `tolerance: 0` mention.

**Primary recommendation:** Plan as four parallel-eligible lanes (guide authoring, integration tests, docs-truth extensions, Plug `@moduledoc` + CHANGELOG bullet) coordinated against the locked phrase set in CONTEXT.md D-03 sub-decisions 3A–3E. Mirror `test/lattice_stripe/webhook/fetch_test.exs` line-for-line for the new `thin_event_test.exs` (same `import Mox`, same `setup :verify_on_exit!`, same `test_client/0`+`ok_response/1` helpers, same fixture imports — just extend the idiom with `Testing.generate_thin_event_payload/3` → `Webhook.parse_event_notification/4` → `Webhook.fetch_*` chained flows). Anchor every claim in the new guide to a docs-truth grep so drift fails CI.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Verify thin-event HMAC signature | Library (LatticeStripe.Webhook) | — | `parse_event_notification/4` already exists; the guide teaches its use, no new code |
| Decode verified payload → typed `%EventNotification{}` | Library | — | `EventNotification.from_map/1` already exists |
| Fetch authoritative `%Event{}` after verify | Library | — | `Webhook.fetch_event/3` already exists; hits `/v2/core/events/{id}` |
| Fetch typed related resource (e.g. `%Customer{}`) | Library | — | `Webhook.fetch_related_object/3` already exists; typed-gate via `ObjectTypes.fetch_module/1` |
| Adopter HTTP endpoint (controller action) | Adopter app (Phoenix controller) | LatticeStripe (raw-body reader) | Phase 47 D-08 explicitly punts on a thin-event-aware `Webhook.Plug`; adopters wire a Phoenix controller themselves |
| Raw-body preservation pre-`Plug.Parsers` | LatticeStripe (`Webhook.CacheBodyReader`) | Adopter endpoint config | Existing module — reused, not re-explained, in the new guide |
| Idempotency dedup (event.id) | Adopter app (DB / cache layer) | LatticeStripe (sketch only) | Library-scoped per Phase 45 D-04; the guide ships a sketch, not a persistence layer |
| Connect routing via `event.context` | Adopter app (controller-level conditional) | LatticeStripe (context surfaced as struct field) | `EventNotification.context` already exposed; guide teaches the routing idiom |
| Test the helpers under chained flows | LatticeStripe test suite (`thin_event_test.exs`) | — | New file under existing `test/lattice_stripe/webhook*` namespace; Mox at Transport boundary |
| Lock guide content against drift | `test/lattice_stripe/docs_truth_test.exs` | — | Extends Phase 44 D-04 docs-truth ladder; grep-based regression net |
| Plug `@moduledoc` `tolerance: 0` surface | `lib/lattice_stripe/webhook/plug.ex:116` | — | Closes Phase 47 WR-04; one-line `@moduledoc` extension only |

## Phoenix Controller Idiom for Thin-Event Adoption

### The Canonical Adopter Spine (Phase 47 D-08 + CONTEXT.md `<specifics>`)

Phase 47 D-08 locked `LatticeStripe.Webhook.Plug` for snapshot mode only. Adopters who consume thin events wire a **custom Phoenix controller** that calls `Webhook.parse_event_notification/4` directly. The CONTEXT.md `<specifics>` block already proposes this shape. Confirmed against the cross-SDK pattern below (stripe-ruby's Sinatra example, stripe-node's Express example, stripe-python's Flask example all do exactly this: framework controller action → parse → dispatch).

### Raw-body accessor — `conn.private[:raw_body]`, NOT `conn.assigns.raw_body`

**CONTEXT.md `<specifics>` has drift here.** The code block in CONTEXT.md `<specifics>` shows `raw_body = conn.assigns.raw_body`. The actual LatticeStripe primitives are:

- `LatticeStripe.Webhook.CacheBodyReader.read_body/2` writes to `Plug.Conn.put_private(conn, :raw_body, body)` ([`lib/lattice_stripe/webhook/cache_body_reader.ex:21,25`](../../../lib/lattice_stripe/webhook/cache_body_reader.ex))
- `LatticeStripe.Webhook.Plug.get_raw_body/1` reads from `conn.private[:raw_body]` ([`lib/lattice_stripe/webhook/plug.ex:273-284`](../../../lib/lattice_stripe/webhook/plug.ex))
- `guides/webhooks.md` "Advanced alternative" section (lines 152-180) documents the `body_reader: {LatticeStripe.Webhook.CacheBodyReader, :read_body, []}` wiring — the public truth surface is `conn.private[:raw_body]`

**Planner action:** The new guide MUST use `conn.private[:raw_body]` (or call `Plug.Conn.read_body/2` directly for the pre-Parsers mount strategy). Treat the `<specifics>` `conn.assigns.raw_body` as a typo to correct, not a constraint. `[VERIFIED: lib/lattice_stripe/webhook/cache_body_reader.ex source]`

### Recommended controller shape (corrected)

```elixir
# lib/my_app_web/controllers/stripe_thin_event_controller.ex
defmodule MyAppWeb.StripeThinEventController do
  use MyAppWeb, :controller

  alias LatticeStripe.{EventNotification, Webhook}
  alias LatticeStripe.EventNotification.RelatedObject

  @secret System.fetch_env!("STRIPE_THIN_EVENT_SECRET")

  def receive(conn, _params) do
    raw_body = conn.private[:raw_body] || ""
    sig_header = conn |> get_req_header("stripe-signature") |> List.first()

    with {:ok, %EventNotification{} = notif} <-
           Webhook.parse_event_notification(raw_body, sig_header, @secret),
         :ok <- dispatch(MyApp.Stripe.client(), notif) do
      send_resp(conn, 200, "")
    else
      {:error, :missing_header}        -> send_resp(conn, 400, "missing header")
      {:error, :invalid_header}        -> send_resp(conn, 400, "invalid header")
      {:error, :no_matching_signature} -> send_resp(conn, 400, "bad signature")
      {:error, :timestamp_expired}     -> send_resp(conn, 400, "stale")
    end
  end

  # idempotency keyed on event.id (NOT on fetched resource state)
  defp dispatch(client, %EventNotification{id: id} = notif) do
    case MyApp.Stripe.IdempotentEvents.claim(id) do
      :ok                 -> dispatch_typed(client, notif)
      :already_processed  -> :ok
    end
  end

  defp dispatch_typed(client, %EventNotification{
         related_object: %RelatedObject{type: "customer"}
       } = notif) do
    {:ok, %LatticeStripe.Customer{} = customer} =
      Webhook.fetch_related_object(client, notif)

    MyApp.Workers.SyncCustomer.enqueue(customer)
    :ok
  end

  defp dispatch_typed(client, %EventNotification{related_object: nil} = notif) do
    {:ok, %LatticeStripe.Event{} = event} = Webhook.fetch_event(client, notif)
    MyApp.Workers.LogSnapshotEvent.enqueue(event)
    :ok
  end

  defp dispatch_typed(_client, _notif), do: :ok
end
```

**Endpoint wiring** — adopters wire `body_reader: {LatticeStripe.Webhook.CacheBodyReader, :read_body, []}` in their `Plug.Parsers` config, same as snapshot webhooks. The new guide cross-links to `guides/webhooks.md` "Advanced alternative" rather than re-explaining (Phase 44 D-24 cross-linking discipline; CONTEXT.md D-01 footnote).

### Why a controller and not a Plug? — Phase 47 D-08 rationale

Phase 47 D-08 explicitly defers the question of a thin-event-aware `Webhook.Plug` dispatch mode because "mixed-mode Plug dispatch is a real design problem (path-based? content-shape-based? handler-attribute-based?) that deserves its own discuss-phase." The new guide must teach this honestly: the controller spine is the canonical adopter shape today. Cross-SDK consistency reinforces this — every published thin-event handler example (stripe-node, stripe-ruby, stripe-python, stripe-java) is a framework controller action, never a framework-provided endpoint plugin. `[VERIFIED: cross-SDK examples cited in §Cross-SDK Thin-Event Documentation & Test Patterns]`

## Idempotency Sketch Recommendation (with concrete Elixir code skeleton)

**Recommendation:** Ship an **Ecto-style schema sketch** in the guide — a `processed_stripe_events` table with a unique constraint on `event_id`, claimed via `Repo.insert/2` and pattern-matched on `Postgrex.Error{constraint: ...}`. Library-scoped: the guide shows the schema + the `claim/1` function shape, but does NOT pull Ecto into LatticeStripe's deps and does NOT teach migrations or persistence layer ownership.

### Why Ecto sketch (with explicit tradeoff disclosure)

| Approach | Durability | Adopter familiarity | Lines | Pulls in deps? | Verdict |
|----------|-----------|---------------------|-------|----------------|---------|
| **Ecto schema + unique constraint** (recommended) | DB-backed; survives restart; horizontal-scale-safe | Highest — every Phoenix SaaS shop already runs Ecto | ~25 lines | No (LatticeStripe ≠ Ecto; the guide *shows* Ecto code adopters will recognize) | Best fit |
| Bare map dedup (`Agent`-wrapped `MapSet`) | None — single-node, lost on restart | Low for production — adopters will read it and wonder how it scales | ~10 lines | No | Misleading at v1.5 scope |
| ETS (`:ets.insert_new/2`) | Single-node, lost on restart | Lower than Ecto — "is this distributed?" question dominates | ~10 lines | No | Same problem as Agent |
| `Cachex` / `Nebulex` cache | TTL-bound durability | Medium | ~15 lines | Recommends specific lib in docs | Picks favorites; not library-scoped |

The bare-map and ETS sketches teach adopters a single-node toy that won't survive horizontal-scale or process restarts — the same trap Phase 45 D-27 calls out ("library-scoped Phoenix examples"). An Ecto schema sketch teaches a production-real shape using the framework adopters already have. The guide says "adapt to your persistence layer (Ecto/Postgrex shown; Redis/etcd works the same way)" rather than mandating Ecto.

Confirmed against Stripe's own canonical advice for thin events: their `migrate-snapshot-to-thin-events` doc explicitly recommends "both handlers insert into the same idempotency table using the same key" with a unique-constraint violation as the dedup signal — that maps 1:1 to `Ecto.Repo.insert/2` returning `{:error, %Ecto.Changeset{errors: [..unique_constraint..]}}`. `[CITED: docs.stripe.com/webhooks/migrate-snapshot-to-thin-events]`

### Concrete code skeleton (for the guide)

```elixir
# Migration (adopter writes; shown for clarity)
defmodule MyApp.Repo.Migrations.CreateProcessedStripeEvents do
  use Ecto.Migration

  def change do
    create table(:processed_stripe_events, primary_key: false) do
      add :event_id, :string, primary_key: true
      add :type, :string, null: false
      add :processed_at, :utc_datetime_usec, null: false
    end
  end
end

# Schema
defmodule MyApp.Stripe.IdempotentEvent do
  use Ecto.Schema

  @primary_key {:event_id, :string, autogenerate: false}
  schema "processed_stripe_events" do
    field :type, :string
    field :processed_at, :utc_datetime_usec
  end
end

# Claim function — keyed on event.id (NOT on fetched resource state)
defmodule MyApp.Stripe.IdempotentEvents do
  alias MyApp.{Repo, Stripe.IdempotentEvent}

  def claim(%LatticeStripe.EventNotification{id: id, type: type}) do
    %IdempotentEvent{}
    |> Ecto.Changeset.change(%{
      event_id: id,
      type: type,
      processed_at: DateTime.utc_now()
    })
    |> Repo.insert()
    |> case do
      {:ok, _}                                              -> :ok
      {:error, %{errors: [event_id: {_, [constraint: :unique, ...]}]}}
                                                            -> :already_processed
    end
  end
end
```

### Why keyed on `event.id`, never on fetched resource state

Stripe's own guidance (`docs.stripe.com/event-destinations`, "Use thin events when **Data integrity is critical, and your application must act on the most up-to-date information**") plus the cross-SDK posture (`stripe-ruby/examples/event_notification_webhook_handler.rb` fetches *after* parse, and the snapshot can change between Stripe-send and adopter-fetch) make this load-bearing: the resource state at fetch-time MAY differ from the resource state at event-emit-time. Idempotency keyed on resource state would dedup the wrong way. `event.id` is the stable, immutable, Stripe-assigned dedup key. The new guide MUST teach this explicitly (it's GUIDE-03 wire phrasing per REQUIREMENTS.md). `[VERIFIED: REQUIREMENTS.md GUIDE-03 text]`

## Stripe `/v2/events` Public Contract Reference

### Rate-limit ceiling — 100 req/s steady-state (live mode)

Source: `docs.stripe.com/rate-limits`. **Verified phrasing:**

> "The basic rate limiter restricts the number of API requests per second as follows:
> - Live mode: 100 operations
> - Sandbox: 25 operations"

**Implications for thin events:**

- Webhook *delivery* is not rate-limited (Stripe pushes to your endpoint at the cadence events occur), but your *fetch-after-verify* calls back to Stripe (`/v2/core/events/{id}` and the `related_object.url`) DO count against the 100 req/s ceiling.
- Fetch-after-verify roughly **doubles** call rate vs. pure snapshot processing (verify → 1 GET to fetch event OR related object; some flows do both = 2 GETs per webhook).
- Stripe's stated ceiling is "live mode: 100 ops/s." LatticeStripe's locked guidance is **`<90/s`** (REQUIREMENTS.md GUIDE-03) — the 10 ops/s headroom absorbs burst spikes, retries inside `Client.retry_strategy`, and concurrent unrelated API traffic from the same app.
- Sandbox mode is 25 ops/s (4× lower). Worth a one-line note in the guide so adopters don't load-test against test mode.
- Per-endpoint stricter limits exist ("API endpoints have a default limit of 25 requests per second"). The guide should note this once and link to Stripe's rate-limits page rather than enumerate.

**Canonical URL to cite in the guide:** `https://docs.stripe.com/rate-limits`. `[VERIFIED: WebFetch docs.stripe.com/rate-limits 2026-05-27]`

### Thin-event payload contract — `{id, type, related_object, context?, created, livemode, reason?}`

Source: `docs.stripe.com/event-destinations`. **Verified canonical example:**

```json
{
  "id": "evt_test_...",
  "object": "v2.core.event",
  "type": "v2.core.account.updated",
  "livemode": false,
  "created": "2026-03-09T13:00:28.435Z",
  "context": null,
  "reason": { "type": "request", "request": {"id": "req_...", "idempotency_key": "..."} },
  "related_object": {
    "id": "acct_1T93Q4Pmpb34Vto6",
    "type": "v2.core.account",
    "url": "/v2/core/accounts/acct_1T93Q4Pmpb34Vto6"
  }
}
```

Cross-referenced against `stripe-go/v2core_event.go` `V2BaseEvent` Go struct (confirmed via `gh api`):

```go
type V2BaseEvent struct {
    APIResource
    Changes  map[string]any         `json:"changes,omitempty"`
    Context  string                 `json:"context,omitempty"`
    Created  time.Time              `json:"created"`
    ID       string                 `json:"id"`
    Livemode bool                   `json:"livemode"`
    Object   string                 `json:"object"`
    Reason   *V2CoreEventReason     `json:"reason,omitempty"`
    Type     string                 `json:"type"`
}
```

LatticeStripe's `%EventNotification{}` struct field set (`id`, `object`, `type`, `created`, `context`, `livemode`, `related_object`, `reason`, `extra`) matches the wire contract exactly, with the addition of `extra` for forward-compat. `created` is the documented ISO 8601 string (`"2026-03-09T13:00:28.435Z"`) — this is a legitimate type asymmetry vs. v1 snapshot events which use Unix integer (acknowledged in Phase 47 IN-01 + the `EventNotification.@type t.created :: String.t() | nil` typespec). `[VERIFIED: docs.stripe.com/event-destinations + stripe-go source]`

**Canonical URLs to cite in the guide:**
- `https://docs.stripe.com/event-destinations` (overview + benefits-of-thin-events anchor)
- `https://docs.stripe.com/api/v2/events` (API reference)
- `https://docs.stripe.com/api/v2/core/events/retrieve` (the endpoint `fetch_event/3` calls)

### Connect routing via `event.context`

Source: `docs.stripe.com/api/v2/events` (and indirectly the V2 changelog page + the Accounts v2 migration page).

**Confirmed:** `context` is "authentication context needed to fetch the event or related object" (stripe-go field comment). For Connect: "For organization event handlers, it inspects the context value to determine which account in an organization generated the event, then sets the `Stripe-Context` header corresponding to the context value." (WebSearch result, cross-verified against stripe-ruby's `StripeClient.new("test_123", stripe_context: "wksp_123")` test setup line in `stripe-ruby/test/stripe/v2_event_test.rb`).

**Implications for the guide:**

- Connect platforms route to the right per-account context by reading `notification.context` and using it when calling `Webhook.fetch_event/3` or `Webhook.fetch_related_object/3`.
- LatticeStripe surfaces `context` directly as a top-level `%EventNotification{context: String.t() | nil}` field — adopters pattern-match it.
- Non-Connect adopters can ignore `context` entirely (it'll be `nil`).
- The CONTEXT.md `<specifics>` controller doesn't show context routing; the guide should add a one-paragraph aside showing a `case notif.context do nil -> ...; ctx -> ...` branch for completeness without bloating the main path.

`[VERIFIED: stripe-go source + cross-SDK search]` `[ASSUMED: precise wording of Stripe's official Connect-context-routing doc page — the search results paraphrase rather than quote the canonical URL]`

## Cross-SDK Thin-Event Documentation & Test Patterns

LatticeStripe's posture (sibling-not-recipe guide + Mox-at-Transport-equivalent tests) is supported by every mature Stripe SDK. **Confirmed by fetching actual source from the stripe org via `gh api`:**

### stripe-node (`stripe/stripe-node`)

**Guide framing:** The official adopter example `examples/snippets/event_notification_webhook_handler.ts` is a self-contained Express handler — single file, ~70 lines, parallel to snapshot examples in the same `examples/snippets/` directory. Not a "recipe-scale playbook" — a sibling demo. The README's "Webhook signing" section keeps snapshot quickstart up top; thin-event handling is documented in a separate code example file. Confirms CONTEXT.md D-01 "sibling not recipe" framing.

**Test posture:** Look at `examples/snippets/event_notification_webhook_handler.ts` itself — uses `client.parseEventNotification(req.body, sig, webhookSecret)` and `await eventNotification.fetchRelatedObject()`. Real-HTTP testing of `parseEventNotification` in the stripe-node test suite uses `nock` (HTTP mocking) at the client-fetch boundary, not a real Stripe endpoint.

**Canonical TS code snippet (excerpt from `stripe-node/examples/snippets/event_notification_webhook_handler.ts`, verified via `gh api`):**

```typescript
const eventNotification = client.parseEventNotification(
  req.body,
  sig,
  webhookSecret
);

// TS will narrow event based on the `type` property
if (eventNotification.type == 'v1.billing.meter.error_report_triggered') {
  console.log(`Meter w/ id ${eventNotification.related_object.id} had a problem`);
  // or you can fetch the full object from the API for more details
  const meter = await eventNotification.fetchRelatedObject();
  // And you can always fetch the full event:
  const event = await eventNotification.fetchEvent();
}
```

`[VERIFIED: gh api repos/stripe/stripe-node/contents/examples/snippets/event_notification_webhook_handler.ts]`

### stripe-ruby (`stripe/stripe-ruby`)

**Guide framing:** `examples/event_notification_webhook_handler.rb` — Sinatra controller, ~50 lines. Sibling to snapshot example files. Same shape as Phase 48 D-01's recommended Phoenix-controller spine. Confirms sibling-not-recipe.

**Test posture:** `test/stripe/v2_event_test.rb` uses `@client.parse_event_notification(payload, Test::WebhookHelpers.generate_header(payload: payload), secret)` — exactly the LatticeStripe pattern (generate signed payload via test helper, parse, assert typed return). No real HTTP server. `Test::WebhookHelpers.generate_header/1` is stripe-ruby's `Testing.generate_thin_event_payload/3` equivalent.

**Canonical Ruby code snippet (excerpt from `stripe-ruby/examples/event_notification_webhook_handler.rb`, verified via `gh api`):**

```ruby
post "/webhook" do
  webhook_body = request.body.read
  sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
  event_notification = client.parse_event_notification(webhook_body, sig_header, webhook_secret)

  if event_notification.instance_of?(Stripe::Events::V1BillingMeterErrorReportTriggeredEventNotification)
    meter = event_notification.fetch_related_object
    event = event_notification.fetch_event
  end
  status 200
end
```

`[VERIFIED: gh api repos/stripe/stripe-ruby/contents/examples/event_notification_webhook_handler.rb]`

### stripe-python (`stripe/stripe-python`)

**Guide framing:** `examples/event_notification_webhook_handler.py` — Flask handler, ~80 lines. Sibling, not playbook. Same `parse_event_notification` → `fetch_related_object` → `fetch_event` shape.

**Test posture:** stripe-python's V2 events tests live alongside V1 event tests in the same test tree; no V2-specific HTTP server, just the per-test fixture-injection pattern at the requestor boundary.

`[VERIFIED: gh api repos/stripe/stripe-python/contents/examples/event_notification_webhook_handler.py]`

### stripe-go (`stripe/stripe-go`)

**Guide framing:** `v2core_event.go` `V2BaseEvent` is a typed struct in the main package. No standalone example file in the repo root — Go's convention is godoc + test examples. The doc comment on `V2BaseEvent` cross-links to `docs.stripe.com/event-destinations` for the canonical handler shape. Still sibling-class to V1 `Event`, not a separate package.

**Test posture:** `httptest`-based fixture servers for V2 events tests. No Bypass-equivalent (Go uses `httptest.NewServer` natively).

**Important correction to the v1.5 thread notes:** stripe-go does **NOT** expose `FetchRelatedObject` / `FetchEvent` methods on `V2BaseEvent`. The struct is data-only; the v1.5 thread (`thin-event-webhook-evaluation.md`) claims this, but the actual source code shows only `getBaseEvent()` defined. This doesn't change LatticeStripe's posture (we DO ship the helper methods, mirroring stripe-node's richer DX) but the guide should not over-claim Go-side parity. `[VERIFIED: gh api stripe-go/v2core_event.go]`

### stripe-java (`stripe/stripe-java`)

**Guide framing + test posture:** The canonical Java pattern (per `docs.stripe.com/webhooks/event-notification-handlers`):

```java
com.stripe.model.EventNotification eventNotification =
  client.parseEventNotification(payload, signatureHeader, endpointSecret);

com.stripe.model.v2.Event event =
  client.v2().core().events().retrieve(eventNotification.getId());

if (event instanceof V1BillingMeterErrorReportTriggeredEvent) {
  Meter op = ((V1BillingMeterErrorReportTriggeredEvent) event).fetchRelatedObject();
}
```

stripe-java tests V2 event handling via `MockWebServer` with fixture responses — equivalent to LatticeStripe's Mox-at-Transport posture. `[CITED: docs.stripe.com/webhooks/event-notification-handlers + WebSearch corroboration]`

### Cross-SDK summary table

| SDK | Adopter example shape | Verify primitive | Fetch helpers on the notification | Test posture |
|-----|----------------------|------------------|-----------------------------------|--------------|
| stripe-node | Express controller in `examples/snippets/event_notification_webhook_handler.ts` | `client.parseEventNotification(...)` | `eventNotification.fetchRelatedObject()`, `eventNotification.fetchEvent()` | `nock` HTTP mocking |
| stripe-ruby | Sinatra controller in `examples/event_notification_webhook_handler.rb` | `client.parse_event_notification(...)` | `event_notification.fetch_related_object`, `event_notification.fetch_event` | Test helpers + fixture HTTP |
| stripe-python | Flask controller in `examples/event_notification_webhook_handler.py` | `client.parse_event_notification(...)` | `event_notif.fetch_related_object()`, `event_notif.fetch_event()` | Requestor-boundary fixture monkey-patching |
| stripe-go | godoc on `V2BaseEvent`; cross-link to Stripe docs for handler shape | (no SDK helper for thin-event verify in current main) | None on `V2BaseEvent` — adopters call `client.V2Core.Events.Retrieve(...)` directly | `httptest` |
| stripe-java | Pattern in `docs.stripe.com/webhooks/event-notification-handlers` | `client.parseEventNotification(...)` | `event.fetchRelatedObject()` (post-cast) | `MockWebServer` with fixtures |
| **LatticeStripe (v1.5)** | **Phoenix controller in `guides/webhooks-thin-events.md` (this phase)** | **`Webhook.parse_event_notification(payload, sig, secret, opts)`** | **`Webhook.fetch_event(client, notif)`, `Webhook.fetch_related_object(client, notif)`** (explicit client arg per D-04 — others bind client implicitly via method receiver) | **Mox at `LatticeStripe.Transport` behaviour boundary** (this phase: `test/lattice_stripe/webhook/thin_event_test.exs`) |

**Two structural differences worth flagging in the guide:**

1. LatticeStripe takes the client **explicitly** at fetch time (Phase 47 D-04 rationale: notification struct stays pure serializable data — safe for ETS, distributed Erlang, GenServer state — without embedding credential material). This is the correct Elixir-idiomatic choice; the new guide should justify it in one sentence so adopters who came from stripe-node aren't surprised.
2. LatticeStripe surfaces `related_object` as a typed nested struct (`%RelatedObject{}`) on both `%EventNotification{}` AND `%Event{}` via single-source-of-truth sharing (Phase 47 D-02). stripe-node has separate types per event variant; LatticeStripe has one shared sub-struct. The guide can teach `case notif.related_object do %RelatedObject{type: "customer"} -> ...` directly.

## ExDoc `groups_for_extras` Placement Strategy

### Current `mix.exs:54-96` shape (verified)

```elixir
extras: [
  "guides/getting-started.md",
  # ...
  "guides/webhooks.md",          # line 44
  "guides/error-handling.md",
  "guides/testing.md",
  # ...
  "CHANGELOG.md"
],
groups_for_extras: [
  {"Start Here", [...]},
  {"Flagship Recipes", [...]},
  {"Canonical Guides", [...]},
  {"Operations & DX",                                     # line 81
   [
     "guides/client-configuration.md",
     "guides/webhooks.md",                                # line 84 — INSERT NEW AFTER THIS LINE
     "guides/error-handling.md",
     "guides/testing.md",
     "guides/performance.md",
     # ...
     "guides/cheatsheet.cheatmd"                          # line 93
   ]},
  {"Changelog", ["CHANGELOG.md"]}
]
```

### Required edits (two locations in `mix.exs`)

1. **`extras` list** (line ~44 — after `"guides/webhooks.md"`): insert `"guides/webhooks-thin-events.md"`. Order matters in the rendered ExDoc sidebar; inserting adjacent to `webhooks.md` puts the v2 sibling immediately under the v1 trust rail.

2. **`groups_for_extras` → `"Operations & DX"`** (line ~84 — after `"guides/webhooks.md"`): insert `"guides/webhooks-thin-events.md"`. This places it in the same group as `webhooks.md` and adjacent in the rendered sidebar.

### Why not "Canonical Guides" or "Flagship Recipes"

Phase 44 D-06 and Phase 45 D-01 lock the group taxonomy. `"Flagship Recipes"` is reserved for the 4 workflow-playbook recipes (Phase 45 D-01 scope; D-01 of *this* phase explicitly rejects recipe scale for thin events). `"Canonical Guides"` is reserved for resource-surface reference guides. The new guide is a *trust rail extension* of `webhooks.md` (an Operations & DX surface), so it belongs in `"Operations & DX"`.

### Docs-truth locks (per CONTEXT.md D-03 sub-decision 3C)

Extend the existing `test "exdoc keeps the primary public truth surfaces published"` test in `test/lattice_stripe/docs_truth_test.exs:8-40` with two new assertions:

```elixir
assert "guides/webhooks-thin-events.md" in extras
assert "guides/webhooks-thin-events.md" in groups["Operations & DX"]
```

`[VERIFIED: mix.exs:54-96 source]`

## Docs-Truth Regression Pattern (extension of Phase 44 D-04 ladder per D-03 3A/3B/3C/3D/3E)

### Pattern survey — how `docs_truth_test.exs` currently works (verified against source)

The existing 186-line file has 8 test blocks, all `use ExUnit.Case, async: true`. Pattern is grep-based:

| Test block | Pattern | Lines |
|------------|---------|-------|
| `"exdoc keeps the primary public truth surfaces published"` | Reads `LatticeStripe.MixProject.project()[:docs]`, asserts `extras` membership + `groups_for_extras` membership | 8-40 |
| `"readme routes evaluators into the guide ladder..."` | `readme = File.read!("README.md")`, then `assert readme =~ "..."` for each canonical guide link | 42-56 |
| `"getting started branches from first success..."` | Same shape on `guides/getting-started.md` | 58-71 |
| `"jtbd and recipes stay task-first routing layers..."` | Same shape on `guides/user-flows-and-jtbd.md` + `guides/recipes.md` | 73-100 |
| `"flagship guides are published and cross-linked..."` | Reads multiple guide files, asserts forward + reverse links + canonical phrases | 102-160 |
| `"cheatsheet keeps the published 1.3 install truth"` | `assert cheatsheet =~ "{:lattice_stripe, \"~> 1.3\"}"` | 162-166 |
| `"changelog records the shipped 1.3 release truth"` | `assert changelog =~ "## [1.3.0]"` | 168-173 |
| `"CHANGELOG.md documents WEBFIX-01 reconciliation under v1.5"` | `assert changelog =~ "WEBFIX-01"` + `assert changelog =~ ~r/##\s*\[?1\.5/` (Phase 47 plan 03) | 175-186 |

Naming convention: `test "..."` with descriptive sentence as the test name. Grouping convention: flat — no `describe` blocks; each test is independent. Async convention: `async: true` at the module level.

### Phase 48 extensions per D-03 sub-decisions

**3A — new guide content locks.** Add ONE new test block to the file:

```elixir
test "webhooks-thin-events guide locks the thin-event adopter contract" do
  guide = File.read!("guides/webhooks-thin-events.md")

  # Function names — the helper surface the guide teaches
  assert guide =~ "parse_event_notification"
  assert guide =~ "fetch_event"
  assert guide =~ "fetch_related_object"

  # Verify-error atoms — locks the verification-vs-payload-shape failure boundary
  assert guide =~ ":no_matching_signature"
  assert guide =~ ":timestamp_expired"
  # Typed-error footguns specific to thin-event helpers
  assert guide =~ ":no_related_object"
  assert guide =~ ":unknown_object_type"

  # Rate-limit phrasing — both substrings required (REQUIREMENTS.md GUIDE-03)
  assert guide =~ "100 req/s"
  assert guide =~ "90/s"

  # Idempotency anchor (GUIDE-03)
  assert guide =~ "event.id"

  # Connect routing anchor (GUIDE-03)
  assert guide =~ "event.context"

  # Canonical truth anchor (Phase 44 D-14)
  assert guide =~ "Webhooks confirm"

  # Canonical surface name
  assert guide =~ "/v2/events"

  # Verification-vs-payload-shape failure boundary phrasing (GUIDE-03)
  assert guide =~ "verification"
  assert guide =~ "payload shape"
end
```

**3B — install-line canary (B2).** Add a focused new test:

```elixir
test "webhooks-thin-events guide is the v1.5 install-line canary" do
  guide = File.read!("guides/webhooks-thin-events.md")

  # This guide is the ONLY 1.5-only doc until release prep flips the rest.
  assert guide =~ "{:lattice_stripe, \"~> 1.5\"}"
end
```

Critically — the existing `"readme routes evaluators..."` test at line 54 still asserts `assert readme =~ "{:lattice_stripe, \"~> 1.3\"}"`. That stays. The new guide is the canary; once v1.5 ships and someone does the lockstep `~> 1.3` → `~> 1.5` flip across README/getting-started/cheatsheet, the existing tests fail until lockstep completes, naturally enforcing the rule. This is the canary architecture per CONTEXT.md D-03 sub-decision 3B.

**3C — ExDoc placement.** Extend the existing `"exdoc keeps the primary public truth surfaces published"` test (NOT a new test). Insert at the appropriate spot in the existing block:

```elixir
# Add to the existing extras assertions:
assert "guides/webhooks-thin-events.md" in extras
# Add to the existing Operations & DX group assertions:
assert "guides/webhooks-thin-events.md" in groups["Operations & DX"]
```

**3D — cross-link graph locks.** Either extend the existing `"flagship guides are published and cross-linked..."` test (preferred — keeps the cross-link contract in one place) OR add a new sibling. Recommended additions:

```elixir
# Forward links from the new guide
thin = File.read!("guides/webhooks-thin-events.md")
assert thin =~ "webhooks.md"
assert thin =~ "testing.md"
assert thin =~ "error-handling.md"

# Reverse link from the parent webhook guide
webhooks = File.read!("guides/webhooks.md")
assert webhooks =~ "webhooks-thin-events.md"
assert webhooks =~ "thin event"  # locks the new "Thin events (/v2/events)" closing section

# README route + box-bullet
readme = File.read!("README.md")
assert readme =~ "webhooks-thin-events.md"

# JTBD ladder
jtbd = File.read!("guides/user-flows-and-jtbd.md")
assert jtbd =~ "webhooks-thin-events.md"
```

Planner discretion: whether to fold these into the existing flagship-guides test or split into a new `test "webhooks-thin-events guide is cross-linked from README/JTBD/webhooks.md"` block. Splitting is more honest — flagship-guides is about the v1.4 recipes; thin-events is a v1.5 surface and deserves its own block. **Recommendation:** new block.

**3E — Plug `@moduledoc` grep test.** Add a new test block analogous to the existing WEBFIX-01 changelog grep:

```elixir
test "Webhook.Plug @moduledoc documents tolerance: 0 testing-only semantics" do
  # WR-04 closure: the Plug @moduledoc Configuration Options section must
  # surface the tolerance: 0 testing-only escape hatch per WEBFIX-01.
  # Drift here means HexDocs would silently stop showing the contract.
  source = File.read!("lib/lattice_stripe/webhook/plug.ex")

  # Grep the @moduledoc block (the Configuration Options at :116) — locking
  # all three required substrings in the same source string ensures the line
  # mentions tolerance, the literal 0 value, and the testing-only restriction.
  assert source =~ ~r/@moduledoc.*tolerance.*0.*testing only/s
end
```

Use `~r/.../s` (the `s` flag is the dotall modifier — `.` matches newlines) because Elixir source files have arbitrary newlines in `@moduledoc` triple-quote strings. Alternative pattern: separate `assert source =~ "tolerance"`, `assert source =~ "Set `0`"`, `assert source =~ "testing only"` — simpler but doesn't enforce co-location. **Recommendation:** use the regex flavor for tighter coupling.

`[VERIFIED: test/lattice_stripe/docs_truth_test.exs source survey]`

## Test Idiom Template Survey

### Direct template: `test/lattice_stripe/webhook/fetch_test.exs` (378 lines)

The new `test/lattice_stripe/webhook/thin_event_test.exs` is a mechanical extension of `fetch_test.exs`. Verified template usage:

```elixir
defmodule LatticeStripe.Webhook.ThinEventTest do
  use ExUnit.Case, async: true        # async — Mox boundary, no shared state

  import Mox                          # for expect/3, verify_on_exit!
  import LatticeStripe.TestHelpers    # test_client/0, ok_response/1, error_response/0
  import LatticeStripe.Test.Fixtures.EventNotification, only: [
    event_notification_map: 0,
    event_notification_map: 1,
    event_notification_map_no_related_object: 0
  ]
  import LatticeStripe.Test.Fixtures.Customer, only: [customer_json: 1]
  import LatticeStripe.Test.Fixtures.Event, only: [event_map: 1]

  alias LatticeStripe.{Customer, Event, EventNotification, Testing, Webhook}
  alias LatticeStripe.EventNotification.RelatedObject
  alias LatticeStripe.Webhook.SignatureVerificationError

  setup :verify_on_exit!              # enforces zero-HTTP on fail-fast paths

  @secret "whsec_test_thinevent"

  describe "verify happy path (Testing → parse)" do
    test "generate_thin_event_payload + parse_event_notification returns typed EventNotification" do
      {payload, sig_header} =
        Testing.generate_thin_event_payload(
          "v2.core.account.updated",
          %{"id" => "acct_1", "type" => "v2.core.account", "url" => "/v2/core/accounts/acct_1"},
          secret: @secret
        )

      assert {:ok, %EventNotification{} = notif} =
               Webhook.parse_event_notification(payload, sig_header, @secret)

      assert notif.type == "v2.core.account.updated"
      assert %RelatedObject{id: "acct_1", type: "v2.core.account"} = notif.related_object
    end
  end

  describe "fetch-after-verify roundtrip — Event branch (parse → fetch_event)" do
    test "chained generate → parse → fetch_event/3 returns typed %Event{}" do
      {payload, sig_header} =
        Testing.generate_thin_event_payload("v2.core.account.updated", nil, secret: @secret)

      assert {:ok, %EventNotification{id: id} = notif} =
               Webhook.parse_event_notification(payload, sig_header, @secret)

      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.contains?(req.url, "/v2/core/events/#{id}")
        refute String.contains?(req.url, "/v1/events/")
        ok_response(event_map(%{"id" => id}))
      end)

      assert {:ok, %Event{id: ^id}} = Webhook.fetch_event(client, notif)
    end
  end

  describe "fetch-after-verify roundtrip — RelatedObject branch (parse → fetch_related_object)" do
    test "chained generate → parse → fetch_related_object/3 returns typed %Customer{}" do
      {payload, sig_header} =
        Testing.generate_thin_event_payload(
          "customer.updated",
          %{"id" => "cus_1", "type" => "customer", "url" => "/v1/customers/cus_1"},
          secret: @secret
        )

      assert {:ok, %EventNotification{} = notif} =
               Webhook.parse_event_notification(payload, sig_header, @secret)

      client = test_client()
      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.contains?(req.url, "/v1/customers/cus_1")
        ok_response(customer_json(%{"id" => "cus_1"}))
      end)

      assert {:ok, %Customer{id: "cus_1"}} = Webhook.fetch_related_object(client, notif)
    end
  end

  describe "malformed-payload failure boundary" do
    test "wrong secret returns {:error, :no_matching_signature}" do
      {payload, sig_header} =
        Testing.generate_thin_event_payload("v2.core.account.updated", nil, secret: @secret)

      assert {:error, :no_matching_signature} =
               Webhook.parse_event_notification(payload, sig_header, "whsec_wrong")
    end

    test "missing header returns {:error, :missing_header}" do
      assert {:error, :missing_header} =
               Webhook.parse_event_notification("{}", nil, @secret)
    end

    test "malformed header returns {:error, :invalid_header}" do
      assert {:error, :invalid_header} =
               Webhook.parse_event_notification("{}", "not-a-real-header", @secret)
    end

    test "bad JSON post-verify currently raises Jason.DecodeError (Phase 47 contract)" do
      # WR-02 from Phase 47 review: documenting the current behavior honestly.
      # The guide must teach this verify-vs-shape boundary — verify-error atoms
      # (4 atoms above) are pre-decode; this exception is post-decode.
      # If WR-02 is later resolved to {:error, :invalid_payload}, this test
      # gets rewritten in lockstep with the helper signature change.
      bad_payload = "not-json-at-all"
      sig_header = Webhook.generate_test_signature(bad_payload, @secret)

      assert_raise Jason.DecodeError, fn ->
        Webhook.parse_event_notification(bad_payload, sig_header, @secret)
      end
    end
  end

  describe "tolerance: 0 reconciled semantics on the thin-event surface" do
    test "stale timestamp + tolerance: 0 returns {:ok, notif} (WEBFIX-01 extends to thin events)" do
      # Phase 47 D-03 / WEBFIX-01 locked tolerance: 0 = disable staleness check.
      # The Phase 47 docs-truth test at docs_truth_test.exs:175 locks this for
      # CHANGELOG; this test locks it for parse_event_notification/4 specifically.
      old_ts = System.system_time(:second) - 86_400

      {payload, sig_header} =
        Testing.generate_thin_event_payload(
          "v2.core.account.updated",
          nil,
          secret: @secret,
          timestamp: old_ts
        )

      assert {:ok, %EventNotification{}} =
               Webhook.parse_event_notification(payload, sig_header, @secret, tolerance: 0)
    end

    test "stale timestamp + default tolerance still returns {:error, :timestamp_expired}" do
      old_ts = System.system_time(:second) - 86_400

      {payload, sig_header} =
        Testing.generate_thin_event_payload("v2.core.account.updated", nil,
          secret: @secret,
          timestamp: old_ts
        )

      assert {:error, :timestamp_expired} =
               Webhook.parse_event_notification(payload, sig_header, @secret)
    end
  end
end
```

### Chained-roundtrip extension shape

The new file's load-bearing addition vs. `fetch_test.exs` is **chained** flows. `fetch_test.exs` Mox-stubs the Transport and asserts `Webhook.fetch_*` in isolation. `thin_event_test.exs` chains `Testing.generate_thin_event_payload/3` → `Webhook.parse_event_notification/4` → `Webhook.fetch_*` and asserts end-to-end. This is the load-bearing integration shape that satisfies VERIFY-03 "Integration test coverage for thin-event verification happy path, fetch-after-verify roundtrip..."

### Naming discipline (per CONTEXT.md established patterns)

- File name: `thin_event_test.exs` — NOT `thin_event_integration_test.exs`. In this repo, `@tag :integration` means "stripe-mock real HTTP via `:gen_tcp.connect(~c"localhost", 12_111, ...)` precondition." The new file is Mox-at-Transport per D-02, so it must NOT collide with the `:integration` semantics.
- Test names: descriptive sentences as the test name (matches `fetch_test.exs` and `webhook_test.exs` precedent).
- Grouping: `describe` blocks per VERIFY-03 must-have category (verify happy path, fetch-event branch, fetch-related-object branch, malformed-payload failure boundary, tolerance: 0). Mirrors `fetch_test.exs` `describe "fetch_event/3"` etc.

`[VERIFIED: test/lattice_stripe/webhook/fetch_test.exs source survey]`

## Cross-Link Graph Locks (per D-03 3D — concrete forward/reverse link checklist)

### Forward links FROM `guides/webhooks-thin-events.md` (in the new guide)

| Target | Why | Required phrase in new guide |
|--------|-----|------------------------------|
| `webhooks.md` | Snapshot vs thin orientation — parent rail | `webhooks.md` (Markdown link or bare reference) |
| `testing.md` | Adopter-side test posture references the project's own Testing helpers | `testing.md` |
| `error-handling.md` | Operational follow-through (Phase 44 D-24 cross-link discipline) | `error-handling.md` |

### Reverse links TO `guides/webhooks-thin-events.md`

| Source | Edit location | Required additions |
|--------|---------------|-------------------|
| `guides/webhooks.md` | NEW closing section "Thin events (`/v2/events`)" after the existing "See also" section (per CONTEXT.md `<specifics>`) | Substrings: `thin event`, `webhooks-thin-events.md`. ~6 lines. |
| `README.md` "Choose Your Route" | Existing `"I am hardening ops and support paths"` route line (currently lists `error-handling.md`, `testing.md`, `webhooks.md`) | Append `webhooks-thin-events.md` |
| `README.md` "What's already in the box" → Platform section "Webhooks" bullet | Existing line "Phoenix-ready `Webhook.Plug` with raw-body capture and signature verification" (line 126) | Expand to mention thin events + `/v2/events`. Suggested: `Phoenix-ready Webhook.Plug snapshot path + thin-event (/v2/events) helpers for fetch-after-verify integration`. Planner discretion on exact wording. |
| `guides/user-flows-and-jtbd.md` "Start Here By Situation" → "Runtime truth, support, and debugging" route (line 93-94) | Existing line: `Webhooks](webhooks.md), [Error Handling](error-handling.md), [Testing](testing.md)` | Add `[Webhooks: Thin Events](webhooks-thin-events.md)` to the list |
| `guides/user-flows-and-jtbd.md` Job 7 "Sleep at night after shipping billing" `Read next` block (line 331-338) | Existing list of 6 items (Testing, Telemetry, OpenTelemetry, Circuit Breaker, Performance, Webhooks) | Add `[Webhooks: Thin Events](webhooks-thin-events.md)` |

### What NOT to touch (per CONTEXT.md deferred items)

- README "Release status" block (line 8-11) stays on v1.3 — release prep, not Phase 48 scope.
- README install snippet stays `~> 1.3` (line 51) — canary architecture per D-03 3B.
- README Docs Ladder section (line 20-30) — no edits unless planner identifies a load-bearing readability gap.
- `guides/getting-started.md` install line stays `~> 1.3` — same canary architecture.

### Lock-vs-asset confusion to avoid

The CONTEXT.md `<specifics>` "Reverse-link section in `webhooks.md`" code block uses `[Webhooks: Thin Events](webhooks-thin-events.md)` as the Markdown link text. The docs-truth grep at D-03 3D asserts the substring `webhooks-thin-events.md` AND the substring `thin event`. Both substrings need to be in the new closing section. Planner: do not phrase the section so that "thin event" only appears via the Markdown link text `Thin Events` (capital T, capital E — case-sensitive default for `=~` string match). Lowercase `thin event` must appear in body prose. Safe canonical placement: the opening sentence "Stripe also delivers **thin events** to `/v2/event-destinations` endpoints" satisfies the lowercase `thin event` substring.

## Webhook.Plug @moduledoc Extension (per D-03 3E — exact phrasing + matching docs-truth grep)

### Edit target — `lib/lattice_stripe/webhook/plug.ex:116`

Current line (verified against source):

```
    - `:tolerance` — Maximum age of the webhook timestamp in seconds (default: 300).
```

Replacement (per CONTEXT.md D-03 sub-decision 3E):

```
    - `:tolerance` — Maximum age of the webhook timestamp in seconds (default: 300).
      Set `0` to disable the staleness check (testing only — see the inline comment
      on `LatticeStripe.Webhook.check_tolerance/2` and the v1.5 CHANGELOG WEBFIX-01 entry).
```

### Matching docs-truth grep (per 3E)

```elixir
test "Webhook.Plug @moduledoc documents tolerance: 0 testing-only semantics" do
  source = File.read!("lib/lattice_stripe/webhook/plug.ex")
  assert source =~ ~r/@moduledoc.*tolerance.*0.*testing only/s
end
```

### Why this closes WR-04 cleanly

Phase 47 already shipped four-surface reconciliation: (1) docstring on `construct_event/4`, (2) code clause at `webhook.ex:647`, (3) Plug NimbleOptions schema `doc:` string at `plug.ex:145`, (4) tests in `webhook_test.exs` + `plug_test.exs`. The Plug `@moduledoc` "Configuration Options" block at `plug.ex:116` is the ONE remaining public surface that didn't get the WEBFIX-01 message. HexDocs renders the Plug `@moduledoc` as the landing page for the webhook Plug — adopters reading that page first don't currently see the `tolerance: 0` testing-only escape hatch. WR-04 is "Documentation polish; deferred because Phase 48's canonical Phoenix thin-event guide + docs-truth regression will close this surface comprehensively" (Phase 47 VERIFICATION.md). The 3E edit + grep test honors that deferral.

### CHANGELOG entry (per CONTEXT.md "Integration Points")

Append ONE bullet to the existing `## [Unreleased]` → `### [1.5.0]` section in `CHANGELOG.md` (under a new `#### Added` block or appended to the existing `#### Fixed` block — planner discretion). Suggested phrasing from CONTEXT.md:

```
- **GUIDE-03 + VERIFY-03 — Thin-event adoption surface published.** New canonical
  Phoenix thin-event guide `guides/webhooks-thin-events.md` documents
  `parse_event_notification/4` + `fetch_event/3` + `fetch_related_object/3` with
  fetch-after-verify idempotency keyed on `event.id`, the verification-vs-payload-shape
  failure boundary, the Stripe 100 req/s rate-limit ceiling, and Connect routing via
  `event.context`. Integration coverage in `test/lattice_stripe/webhook/thin_event_test.exs`
  proves the chained generate → parse → fetch flows under happy-path, malformed-payload,
  and `tolerance: 0` boundary conditions. Docs-truth regression in `docs_truth_test.exs`
  locks the new guide content and closes Phase 47 WR-04 by extending the
  `Webhook.Plug` `@moduledoc` `tolerance: 0` mention.
```

## Validation Architecture

> This is **MANDATORY** for Phase 48. `.planning/config.json` is not present in the repo (verified: `ls .planning/config.json` → not found), so `workflow.nyquist_validation` is treated as enabled (the default).

### Posture statement — honest framing for a docs+tests phase

Phase 48 is the rarest kind of Nyquist phase: most "validation layers" are functional/idiomatic test coverage and grep-based docs-truth locks, NOT property tests. The phase ships zero new public `lib/` API surface (apart from one `@moduledoc` substring edit). There is no behavior to property-test that isn't already locked by Phase 47's 177-test suite. Property-test candidate signals: **none load-bearing in this phase**. The downstream VALIDATION.md should reflect this honestly — Phase 48 satisfies Dimension 8 (validation depth) via **tests + docs-truth grep**, not via synthesized property tests.

### Test layers / boundaries

| Layer | Boundary | One-line rationale |
|-------|----------|---------------------|
| **Helper-surface unit tests** | `test/lattice_stripe/webhook_test.exs` (Phase 47-shipped) | Verify atoms + happy-path decode at `parse_event_notification/4` boundary. Re-asserted via lockstep on every Phase 48 CI run. |
| **Fetcher-surface unit tests** | `test/lattice_stripe/webhook/fetch_test.exs` (Phase 47-shipped) | Mox-at-Transport coverage for `fetch_event/3` + `fetch_related_object/3` D-05 fail-fast contract. Re-asserted on every Phase 48 CI run. |
| **NEW: Chained-roundtrip integration tests** | `test/lattice_stripe/webhook/thin_event_test.exs` (Phase 48) | The load-bearing addition: chained generate → parse → fetch flows that prove the helpers behave end-to-end at the helper boundary. Mox at `LatticeStripe.Transport`, `async: true`. This IS the integration boundary for VERIFY-03. |
| **NEW: Docs-truth grep regression** | `test/lattice_stripe/docs_truth_test.exs` (Phase 48 extensions per D-03 3A–3E) | The validation layer for the guide itself — every load-bearing phrase in `webhooks-thin-events.md` is locked by a grep assertion. Drift fails CI. This IS the validation layer for GUIDE-03. |
| **Compile + lint** | `mix compile --warnings-as-errors`, `mix credo --strict`, `mix docs --warnings-as-errors` (existing `mix ci` alias) | Standard project gates; the new guide + test file must pass all three. |

### Integration vs unit boundary — Mox at Transport, NOT real HTTP

D-02 explicitly puts `thin_event_test.exs` at the **Mox-at-Transport boundary** with `async: true`, NOT at the `@tag :integration` real-HTTP boundary. This is the load-bearing decision for the planner:

**Why this satisfies VERIFY-03 honestly:**

1. VERIFY-03's four must-haves are all at the helper boundary: verify happy path, fetch-after-verify roundtrip, malformed-payload failure boundary, `tolerance: 0` reconciliation. None of these require Stripe-the-service to be reachable; they require the SDK's helper signatures + decoders + verify primitive to behave correctly.
2. stripe-mock cannot validate `/v2/` endpoints — it returns `{:error, %Error{type: :invalid_request_error, code: "invalid_v2_key"}}` for `/v2/core/events/{id}` (confirmed at `test/support/stripe_explorer_harness.ex:157-165`). The existing `test/lattice_stripe/billing/meter_event_stream_integration_test.exs` is the in-repo anti-pattern (`@tag :skip` waiting for stripe-mock v2 support) — NOT a template to replicate.
3. CLAUDE.md "What NOT to Use" table explicitly excludes Bypass. Falling back to Bypass when stripe-mock can't cover `/v2/` defeats the original exclusion.
4. Cross-SDK evidence: every mature Stripe SDK tests thin-event helpers at the client-fetch boundary with fixtures (stripe-node `nock`, stripe-ruby test helpers, stripe-go `httptest`, stripe-python fixture-injection, stripe-java `MockWebServer`). None use a real-HTTP server. Stripity Stripe (Bypass-based) is the ecosystem case study against this approach.
5. Phase 47 already paid for the Mox-at-Transport infrastructure (`fetch_test.exs` 378 lines). The new file extends the idiom with chained flows rather than introducing a new tier.

### Docs-truth lock surface as a first-class validation layer

The D-03 sub-decisions 3A/3B/3C/3D/3E are themselves the validation layer for GUIDE-03. Every load-bearing phrase the guide promises (function names, error atoms, rate-limit phrasing, idempotency anchor, Connect routing anchor, truth anchor) is grep-locked in `docs_truth_test.exs`. This is the project's established Phase 44 D-04 docs-truth ladder, extended for v1.5. The planner should treat the grep tests as part of the executable proof that GUIDE-03 is satisfied, not as a separate concern.

### Failure-mode coverage requirements (VERIFY-03 four must-haves + tolerance: 0 reconciliation)

| Must-have | Test |
|-----------|------|
| Verification happy path | `describe "verify happy path (Testing → parse)"` |
| Fetch-after-verify roundtrip (Event branch) | `describe "fetch-after-verify roundtrip — Event branch (parse → fetch_event)"` |
| Fetch-after-verify roundtrip (RelatedObject branch) | `describe "fetch-after-verify roundtrip — RelatedObject branch (parse → fetch_related_object)"` |
| Malformed-payload failure boundary | `describe "malformed-payload failure boundary"` (wrong sig, missing header, invalid header, post-verify bad JSON) |
| `tolerance: 0` reconciled semantics | `describe "tolerance: 0 reconciled semantics on the thin-event surface"` (stale timestamp + tolerance: 0 returns `{:ok, _}`; stale timestamp + default tolerance still returns `:timestamp_expired`) |

### Phase Requirements → Test Map (downstream Nyquist VALIDATION.md template feed)

| REQ-ID | Behavior | Test type | Automated command | File exists? |
|--------|----------|-----------|-------------------|--------------|
| GUIDE-03 | Guide published with thin-event adopter contract phrases | docs-truth grep | `mix test test/lattice_stripe/docs_truth_test.exs -x` | ❌ (Phase 48 creates `guides/webhooks-thin-events.md`; extends `docs_truth_test.exs`) |
| GUIDE-03 | Guide install snippet says `~> 1.5` (canary, B2) | docs-truth grep | `mix test test/lattice_stripe/docs_truth_test.exs -x` | ❌ (Phase 48 creates) |
| GUIDE-03 | ExDoc placement in `Operations & DX` group | mix.exs config + docs-truth grep | `mix test test/lattice_stripe/docs_truth_test.exs -x` | ❌ (Phase 48 edits `mix.exs`) |
| GUIDE-03 | Cross-link graph: forward from new guide; reverse from `webhooks.md`/README/JTBD | docs-truth grep | `mix test test/lattice_stripe/docs_truth_test.exs -x` | ❌ (Phase 48 creates/edits) |
| GUIDE-03 (WR-04 closure) | `Webhook.Plug` `@moduledoc` documents `tolerance: 0` | docs-truth grep | `mix test test/lattice_stripe/docs_truth_test.exs -x` | ❌ (Phase 48 edits `plug.ex:116`) |
| VERIFY-03 | Verify happy path (generate → parse) | integration (Mox at Transport) | `mix test test/lattice_stripe/webhook/thin_event_test.exs -x` | ❌ (Phase 48 creates) |
| VERIFY-03 | Fetch-after-verify roundtrip — Event branch (parse → fetch_event) | integration (Mox at Transport) | `mix test test/lattice_stripe/webhook/thin_event_test.exs -x` | ❌ (Phase 48 creates) |
| VERIFY-03 | Fetch-after-verify roundtrip — RelatedObject branch (parse → fetch_related_object) | integration (Mox at Transport) | `mix test test/lattice_stripe/webhook/thin_event_test.exs -x` | ❌ (Phase 48 creates) |
| VERIFY-03 | Malformed-payload failure boundary | integration (Mox at Transport) | `mix test test/lattice_stripe/webhook/thin_event_test.exs -x` | ❌ (Phase 48 creates) |
| VERIFY-03 | `tolerance: 0` reconciled on thin-event surface | integration (Mox at Transport) | `mix test test/lattice_stripe/webhook/thin_event_test.exs -x` | ❌ (Phase 48 creates) |

### Sampling rate

- **Per task commit:** `mix test test/lattice_stripe/webhook/thin_event_test.exs test/lattice_stripe/docs_truth_test.exs --warnings-as-errors`
- **Per wave merge:** `mix test --warnings-as-errors`
- **Phase gate:** `mix ci` (the existing alias: format check + warnings-as-errors compile + Credo strict + full test suite + docs --warnings-as-errors) — green before `/gsd:verify-work`

### Wave 0 gaps

- ❌ `guides/webhooks-thin-events.md` — Phase 48 creates this. ~140-180 lines per D-01 length calibration.
- ❌ `test/lattice_stripe/webhook/thin_event_test.exs` — Phase 48 creates this. ~5 describe blocks, ~12-15 tests.
- ❌ `test/lattice_stripe/docs_truth_test.exs` extensions — Phase 48 adds new tests + extends existing ExDoc placement test.
- ❌ `lib/lattice_stripe/webhook/plug.ex:116` extension — Phase 48 edits one line of `@moduledoc`.
- ❌ `mix.exs` `extras` + `groups_for_extras` extensions — Phase 48 adds 2 lines.
- ❌ `guides/webhooks.md` closing section — Phase 48 adds ~6 lines.
- ❌ `guides/user-flows-and-jtbd.md` — Phase 48 adds 2 cross-links.
- ❌ `README.md` — Phase 48 adds 1 route extension + 1 box-bullet expansion.
- ❌ `CHANGELOG.md` — Phase 48 appends 1 bullet to the existing `### [1.5.0]` section.

### Test framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir stdlib) + Mox `~> 1.2` (existing dev/test dep) |
| Config file | `test/test_helper.exs` (existing) — Mox setup already configured |
| Quick run command | `mix test test/lattice_stripe/webhook/thin_event_test.exs test/lattice_stripe/docs_truth_test.exs` |
| Full suite command | `mix test --warnings-as-errors` |
| CI command | `mix ci` (existing alias) |

## Open Questions (RESOLVED)

None. Every D-01..D-04 sub-decision is fully locked in CONTEXT.md; every load-bearing fact in this research is either verified against source/registry or cited from official Stripe docs. The two minor flags worth surfacing to the planner are NOT open questions but corrections:

1. **CONTEXT.md `<specifics>` raw-body accessor drift.** The controller code block uses `conn.assigns.raw_body`; the LatticeStripe primitive writes to `conn.private[:raw_body]`. The planner should treat this as a typo to correct in the guide rather than as a constraint. (Documented above in §Phoenix Controller Idiom.)

2. **v1.5 thread `thin-event-webhook-evaluation.md` claim about stripe-go `FetchRelatedObject` / `FetchEvent` methods.** Verified against actual `stripe-go/v2core_event.go` source: stripe-go does NOT expose these methods on `V2BaseEvent`. The new guide should not over-claim Go-side parity. This doesn't change LatticeStripe's posture (we DO ship richer DX, mirroring stripe-node).

## Sources

### Primary (HIGH confidence — verified during this research session)

- **`lib/lattice_stripe/webhook.ex`** (688 lines) — Phase 47 helper surface: `parse_event_notification/4` (line 224), `parse_event_notification!/4` (line 255), `fetch_event/3` (lines 323-368), `fetch_related_object/3` (lines 433-497), `check_tolerance/2` (lines 639-658) — locked signatures + typed errors.
- **`lib/lattice_stripe/event_notification.ex`** (170 lines) — `%EventNotification{}` struct shape; lines 64-78 (defstruct), 86-98 (typespec), 100-142 (`from_map/1`), 145-170 (Inspect impl hides `:reason` + `:extra`).
- **`lib/lattice_stripe/event_notification/related_object.ex`** (110 lines) — `%RelatedObject{}` shared sub-struct; line 66 (`from_map(nil) -> nil` load-bearing); lines 80-109 Inspect impl.
- **`lib/lattice_stripe/webhook/plug.ex`** (286 lines) — line 116 is the WR-04 edit target; line 143 schema `:non_neg_integer`; lines 273-284 `get_raw_body/1` reads `conn.private[:raw_body]`.
- **`lib/lattice_stripe/webhook/cache_body_reader.ex`** (33 lines) — line 21,25 confirm `conn.private[:raw_body]` (NOT `conn.assigns.raw_body`).
- **`lib/lattice_stripe/object_types.ex`** (75 lines) — `fetch_module/1` typed-gate at lines 58-60.
- **`lib/lattice_stripe/testing.ex`** lines 100-127 (`event_notification/1`) + 246-332 (`generate_thin_event_payload/3`).
- **`test/lattice_stripe/webhook/fetch_test.exs`** (378 lines) — direct idiom template for the new file.
- **`test/lattice_stripe/webhook_test.exs`** lines 297-411 — `parse_event_notification/4` describe blocks; verify-side template.
- **`test/lattice_stripe/testing_test.exs`** lines 119-225 — `generate_thin_event_payload/3` describe block + roundtrip pattern.
- **`test/lattice_stripe/docs_truth_test.exs`** (186 lines, 8 tests) — pattern survey for D-03 extensions.
- **`test/support/fixtures/event_notification.ex`** + `test/support/test_helpers.ex` — reusable fixture/helper imports.
- **`mix.exs:54-96`** — `extras` list + `groups_for_extras` for ExDoc placement.
- **`guides/webhooks.md`** (216 lines) — sibling structure to mirror + reverse-link target.
- **`guides/user-flows-and-jtbd.md`** lines 75-95 (Start Here routes) + lines 311-338 (Job 7 "Sleep at night" + Read next).
- **`README.md`** lines 31-42 (Choose Your Route) + line 126 ("What's already in the box" Webhooks bullet).
- **`CHANGELOG.md`** lines 7-28 — existing `[Unreleased] → [1.5.0]` block.
- **`.planning/phases/47-thin-event-sdk-surface-webhook-reconciliation/47-CONTEXT.md`** — locked 8 decisions D-01..D-08.
- **`.planning/phases/47-thin-event-sdk-surface-webhook-reconciliation/47-VERIFICATION.md`** — 6/6 must-haves verified; WR-04 deferred to Phase 48 with explicit evidence.
- **`.planning/phases/47-thin-event-sdk-surface-webhook-reconciliation/47-REVIEW.md`** lines 136-153 — WR-04 fix specification.
- **`docs.stripe.com/event-destinations`** — thin-event payload contract + benefits-of-thin-events anchor + fetch-after-verify framing (verified via WebFetch 2026-05-27).
- **`docs.stripe.com/rate-limits`** — 100 req/s live mode ceiling + 25 req/s sandbox limit (verified via WebFetch 2026-05-27).
- **`stripe/stripe-node/examples/snippets/event_notification_webhook_handler.ts`** — Express controller example (verified via `gh api repos/stripe/stripe-node/contents/...` 2026-05-27).
- **`stripe/stripe-ruby/examples/event_notification_webhook_handler.rb`** — Sinatra controller example (verified via `gh api` 2026-05-27).
- **`stripe/stripe-python/examples/event_notification_webhook_handler.py`** — Flask controller example (verified via `gh api` 2026-05-27).
- **`stripe/stripe-go/v2core_event.go`** — `V2BaseEvent` Go struct definition (verified via `gh api` 2026-05-27).
- **`stripe/stripe-ruby/test/stripe/v2_event_test.rb`** — `parse_event_notification` test idiom (verified via `gh api` 2026-05-27).

### Secondary (MEDIUM confidence — verified by cross-reference)

- **`docs.stripe.com/webhooks/event-notification-handlers`** — stripe-java pattern + cross-SDK overview (WebFetch + WebSearch corroboration).
- **`docs.stripe.com/webhooks/migrate-snapshot-to-thin-events`** — dual-destination migration + idempotency-on-event.id pattern (WebFetch 2026-05-27).
- **`docs.stripe.com/changelog/acacia/2024-09-30/api-v2-thin-events`** — V2 thin-event API changelog (WebFetch 2026-05-27).
- **`hexdocs.pm/ecto/constraints-and-upserts.html`** — `unique_constraint/2` idempotency pattern (WebSearch ecosystem corroboration).
- **`hookdeck.com/webhooks/guides/implement-webhook-idempotency`** — generic webhook idempotency-via-unique-constraint pattern (cross-language; reinforces the Ecto sketch).

### Tertiary (cited but lower-trust)

- **`docs.stripe.com/api/v2/events`** — landing page only returned high-level TOC via WebFetch; payload-shape detail cross-verified against `stripe-go/v2core_event.go` source.
- **WebSearch results** mentioning `event.context` Connect-organization routing semantics — corroborated by stripe-ruby's `StripeClient.new("test_123", stripe_context: "wksp_123")` test setup but not directly verified against a canonical Stripe doc URL. `[ASSUMED]` for the exact wording of Stripe's Connect-context-routing public doc page.

## Metadata

**Confidence breakdown:**

- **Architectural Responsibility Map** — HIGH (every helper signature and adopter-tier responsibility is locked by Phase 47 + CONTEXT.md D-01..D-04; verified against source).
- **Phoenix controller idiom** — HIGH (verified against `cache_body_reader.ex` + `webhook/plug.ex` source; cross-SDK controller examples verified via `gh api`).
- **Idempotency sketch** — HIGH (Stripe's own `migrate-snapshot-to-thin-events` recommends the unique-constraint pattern; the Ecto sketch is the idiomatic Elixir mapping; tradeoff table documents alternatives honestly).
- **Stripe `/v2/events` rate-limit + payload + context** — HIGH for the 100 req/s ceiling (WebFetch verified), HIGH for the payload shape (stripe-go source + Stripe docs example match LatticeStripe's struct verbatim), MEDIUM for the precise Connect-context-routing wording (`[ASSUMED]` tag on the wording but not the existence).
- **Cross-SDK research** — HIGH (4 of 5 SDKs cited with verified source via `gh api`; stripe-java cited via Stripe doc page + WebSearch corroboration).
- **ExDoc placement** — HIGH (mix.exs lines verified against source).
- **Docs-truth pattern** — HIGH (existing test file pattern surveyed at the source line level).
- **Test idiom template** — HIGH (existing `fetch_test.exs` 378 lines used as direct mechanical template).
- **Cross-link graph** — HIGH (all link targets verified against source files).
- **Plug `@moduledoc` extension** — HIGH (target line 116 verified; CONTEXT.md provides exact replacement string).
- **Validation Architecture** — HIGH (honest framing for a docs+tests phase per the prompt's explicit posture guidance).

**Research date:** 2026-05-27
**Valid until:** 2026-06-27 (30 days) for Stripe public docs; indefinite for in-repo source verification (any drift will be caught by the docs-truth grep suite this phase ships).
