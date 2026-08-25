# Webhooks: Thin Events

Stripe's `/v2/events` path delivers **thin events** — lightweight payloads that carry
only `{id, type, related_object}`. Your app verifies the signature, then fetches
authoritative state from Stripe before acting. This is the fetch-after-verify pattern.

If you only keep one rule from this guide, keep this one:

**Your app starts work. Webhooks confirm reality.**

Thin events are how Stripe confirms reality at the `/v2/events` surface. Add
LatticeStripe to your project:

```elixir
{:lattice_stripe, "~> 2.2"}
```

For Stripe's full thin-event reference, see [Stripe Event Destinations](https://docs.stripe.com/event-destinations).

## The verification-vs-payload-shape failure boundary

`Webhook.parse_event_notification/4` performs HMAC signature **verification** before
decoding JSON. Two distinct failure modes:

**Verification errors (returned as tagged tuples, before JSON decode):**
`:missing_header`, `:invalid_header`, `:no_matching_signature`, `:timestamp_expired`.

**Payload shape errors (raised, after verify passes):**
If the body is not valid JSON, `Jason.decode!` raises `Jason.DecodeError`. Verify
errors are returned; **payload shape** errors raise. Handle both in your controller.

When calling `fetch_related_object/3`, two additional typed errors surface:

- `{:error, :no_related_object}` — `related_object` is `nil`; use `fetch_event/3` instead
- `{:error, {:unknown_object_type, type}}` — `related_object.type` is not a known dispatch target

## The Phoenix controller spine

Thin events arrive at a **custom Phoenix controller**, not through `LatticeStripe.Webhook.Plug`
(which handles the snapshot `/v1` path). Wire the raw-body reader in `endpoint.ex` the same
way as snapshot webhooks — see [Webhooks](webhooks.md) for the `Plug.Parsers` + `CacheBodyReader`
setup. Your thin-event controller reads from `conn.private[:raw_body]`:

```elixir
defmodule MyAppWeb.StripeThinEventController do
  use MyAppWeb, :controller

  alias LatticeStripe.{EventNotification, Webhook}
  alias LatticeStripe.EventNotification.RelatedObject

  def receive(conn, _params) do
    secret = Application.fetch_env!(:my_app, :stripe_thin_event_secret)
    raw_body = conn.private[:raw_body] || ""
    sig_header = conn |> get_req_header("stripe-signature") |> List.first()

    with {:ok, %EventNotification{} = notif} <-
           Webhook.parse_event_notification(raw_body, sig_header, secret),
         :ok <- dispatch(MyApp.Stripe.client(), notif) do
      send_resp(conn, 200, "")
    else
      {:error, :missing_header}        -> send_resp(conn, 400, "missing header")
      {:error, :invalid_header}        -> send_resp(conn, 400, "invalid header")
      {:error, :no_matching_signature} -> send_resp(conn, 400, "bad signature")
      {:error, :timestamp_expired}     -> send_resp(conn, 400, "stale")
      # fetch_related_object/3 or fetch_event/3 returned an error
      {:error, _reason}                -> send_resp(conn, 500, "")
    end
  end

  defp dispatch(client, %EventNotification{} = notif) do
    case MyApp.Stripe.IdempotentEvents.claim(notif) do
      :ok                -> dispatch_typed(client, notif)
      :already_processed -> :ok
    end
  end

  defp dispatch_typed(client, %EventNotification{
         related_object: %RelatedObject{type: "customer"}
       } = notif) do
    case Webhook.fetch_related_object(client, notif) do
      {:ok, %LatticeStripe.Customer{} = customer} ->
        MyApp.Workers.SyncCustomer.enqueue(customer)
        :ok
      {:error, reason} ->
        # Log and propagate — Stripe will retry on non-2xx response
        {:error, reason}
    end
  end

  defp dispatch_typed(client, %EventNotification{related_object: nil} = notif) do
    case Webhook.fetch_event(client, notif) do
      {:ok, %LatticeStripe.Event{} = event} ->
        MyApp.Workers.LogSnapshotEvent.enqueue(event)
        :ok
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp dispatch_typed(_client, _notif), do: :ok
end
```

LatticeStripe takes the client explicitly at fetch time so `%EventNotification{}` stays
pure serializable data — safe for ETS, GenServer state, and distributed Erlang.

## Fetch-after-verify worked example

After `parse_event_notification/4` returns `{:ok, %EventNotification{} = notif}`, choose
a fetch path:

**`Webhook.fetch_event/3`** — retrieves the full `%Event{}` from `/v2/core/events/{id}`.
Use when `related_object` is `nil` or you need the full v2 event snapshot:

```elixir
{:ok, %LatticeStripe.Event{} = event} = Webhook.fetch_event(client, notif)
```

**`Webhook.fetch_related_object/3`** — fetches the typed resource directly (e.g.,
`%Customer{}`, `%Invoice{}`), dispatched via `ObjectTypes` based on `related_object.type`:

```elixir
{:ok, %LatticeStripe.Customer{} = customer} = Webhook.fetch_related_object(client, notif)
```

Watch for: `{:error, :no_related_object}` (use `fetch_event/3` for snapshot-style v2 events)
and `{:error, {:unknown_object_type, type}}` (typed-gate fail-fast).

## Idempotency keyed on `event.id`

Stripe may deliver a thin event more than once. Key idempotency on `event.id` — NOT on
fetched resource state. Resource state can change between Stripe's send and your fetch;
resource-state-keyed dedup would double-process or skip valid updates.

An Ecto-style dedup sketch (adapt to your persistence layer; LatticeStripe does not pull
Ecto as a dependency):

```elixir
# Table: create table(:processed_stripe_events, primary_key: false) do
#          add :event_id, :string, primary_key: true
#          add :type, :string, null: false
#          add :processed_at, :utc_datetime_usec, null: false
#        end

defmodule MyApp.Stripe.IdempotentEvents do
  alias MyApp.{Repo, Stripe.IdempotentEvent}

  # Keyed on event.id — the stable Stripe-assigned dedup key
  def claim(%LatticeStripe.EventNotification{id: id, type: type}) do
    %IdempotentEvent{}
    |> Ecto.Changeset.change(%{event_id: id, type: type, processed_at: DateTime.utc_now()})
    |> Repo.insert()
    |> case do
      {:ok, _}                                                        -> :ok
      {:error, %{errors: [event_id: {_, [constraint: :unique, _]}]}} -> :already_processed
    end
  end
end
```

Redis, etcd, or any unique-constraint-capable store works the same way. Ecto/Postgrex is
shown because it matches what Phoenix shops already have.

## Rate-limit posture

Fetch-after-verify roughly doubles your API call rate vs. snapshot processing — each thin
event triggers at least one GET. Some flows do both `fetch_event/3` and `fetch_related_object/3`,
so plan for two GETs per webhook.

Stripe's live-mode ceiling is **100 req/s** steady-state. Stay below **90/s** to absorb
burst spikes, retries, and concurrent API calls. Sandbox mode is 25 req/s — four times lower.
See Stripe's [Rate Limits](https://docs.stripe.com/rate-limits) for per-endpoint details.

## Connect / context-aware routing via `event.context`

For Connect platforms, `notif.context` identifies which connected account generated the
event. Non-Connect adopters can ignore it — `context` is `nil` for platform-level events.
`event.context` is a top-level `%EventNotification{}` field; pattern-match it directly:

```elixir
case notif.context do
  nil -> dispatch_typed(client, notif)
  ctx -> dispatch_typed(MyApp.Stripe.account_client(ctx), notif)
end
```

## Testing

[stripe-mock](https://github.com/stripe/stripe-mock) is a basic request-shape sanity check,
not a model of Stripe behavior. Do not use it as proof of thin-event `/v2` delivery or fetch
semantics. Test your handler with
`LatticeStripe.Testing.generate_thin_event_payload/3` plus `Mox` at the
`LatticeStripe.Transport` behaviour boundary. The [Testing](testing.md) guide shows the
fixture layering and which behaviors still require Stripe test mode.

## See also

- [Webhooks](webhooks.md) — snapshot webhooks, raw-body invariant, `Webhook.Plug` quickstart
- [Testing](testing.md) — `generate_thin_event_payload/3`, `generate_webhook_payload/3`, fixture builders
- [Error Handling](error-handling.md) — `LatticeStripe.Error`, retry strategy, circuit breaker
- [Event Debugging](event-debugging.md) — production diagnosis for thin vs snapshot wrong-entry-point failures
