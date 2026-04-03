defmodule LatticeStripe.Event do
  @moduledoc """
  Operations on Stripe Event objects.

  Events represent actions that occurred in your Stripe account — payment succeeded,
  customer created, subscription cancelled, etc. Events are read-only (you cannot
  create or modify them via the API). LatticeStripe delivers webhook events as typed
  `%Event{}` structs via `LatticeStripe.Webhook.construct_event/3`.

  ## Usage

      client = LatticeStripe.Client.new!(api_key: "sk_live_...", finch: MyApp.Finch)

      # Retrieve a specific event
      {:ok, event} = LatticeStripe.Event.retrieve(client, "evt_1NxGkW2eZvKYlo2CvN93zMW1")

      # List recent events
      {:ok, resp} = LatticeStripe.Event.list(client, %{"limit" => "10", "type" => "payment_intent.succeeded"})
      events = resp.data.data  # [%Event{}, ...]

      # Stream all events lazily (auto-pagination)
      client
      |> LatticeStripe.Event.stream!(%{"type" => "customer.created"})
      |> Stream.take(100)
      |> Enum.each(&handle_event/1)

  ## Inspect

  The `Inspect` implementation hides `data`, `request`, `account`, and `extra` fields
  to keep inspect output concise. Only `id`, `type`, `object`, `created`, and `livemode`
  are shown.

  ## Stripe API Reference

  See the [Stripe Events API](https://docs.stripe.com/api/events) for the full object
  reference, and the [event types catalog](https://docs.stripe.com/api/events/types)
  for all available event type strings.
  """

  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}

  # Known top-level fields from the Stripe Event object.
  # Used to build the struct and separate known from extra (unknown) fields.
  # String sigil (no `a`) matches Jason's default string-key output.
  # Includes `context` — newer Stripe field (added in the 2022-11-15+ API era).
  @known_fields ~w[
    id object account api_version context created data livemode
    pending_webhooks request type
  ]

  defstruct [
    :id,
    :account,
    :api_version,
    :context,
    :created,
    :data,
    :livemode,
    :pending_webhooks,
    :request,
    :type,
    object: "event",
    extra: %{}
  ]

  @typedoc """
  A Stripe Event object.

  Events represent actions in your Stripe account. Delivered as webhook payloads
  or retrieved via the Events API. The `data.object` map contains the full Stripe
  object snapshot at the time of the event — its shape varies by `type`.

  See the [Stripe Events API](https://docs.stripe.com/api/events/object) for field definitions
  and the [event catalog](https://docs.stripe.com/api/events/types) for all event types.

  - `id` - Event ID (e.g., `"evt_1NxGkW2eZvKYlo2CvN93zMW1"`)
  - `type` - Event type string (e.g., `"payment_intent.succeeded"`, `"customer.created"`)
  - `data` - Raw map with `"object"` key containing the Stripe object snapshot
  - `created` - Unix timestamp when the event was created
  - `livemode` - `true` for live mode, `false` for test mode
  - `api_version` - Stripe API version the event was rendered with
  - `pending_webhooks` - Number of webhook endpoints yet to receive this event
  - `request` - Original request that triggered the event (raw map), or `nil`
  - `account` - Connected account ID for Connect events, or `nil`
  - `extra` - Any unknown fields from the Stripe response
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          account: String.t() | nil,
          api_version: String.t() | nil,
          context: String.t() | nil,
          created: integer() | nil,
          data: map() | nil,
          livemode: boolean() | nil,
          pending_webhooks: integer() | nil,
          request: map() | nil,
          type: String.t() | nil,
          extra: map()
        }

  # ---------------------------------------------------------------------------
  # Public API: Read-only resource operations (Events are immutable)
  # ---------------------------------------------------------------------------

  @doc """
  Retrieves an Event by ID.

  Sends `GET /v1/events/:id` and returns `{:ok, %Event{}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The event ID string (e.g., `"evt_1NxGkW2eZvKYlo2CvN93zMW1"`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Event{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/events/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Like `retrieve/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    retrieve(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Lists Events with optional filters.

  Sends `GET /v1/events` and returns `{:ok, %Response{data: %List{}}}` with
  typed `%Event{}` items.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Filter params (e.g., `%{"limit" => "10", "type" => "payment_intent.succeeded"}`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Response{data: %List{data: [%Event{}, ...]}}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/events", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Like `list/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) do
    list(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Returns a lazy stream of all Events matching the given params (auto-pagination).

  Emits individual `%Event{}` structs, fetching additional pages as needed.
  Raises `LatticeStripe.Error` if any page fetch fails.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Filter params (e.g., `%{"type" => "customer.created", "limit" => "100"}`)
  - `opts` - Per-request overrides

  ## Returns

  An `Enumerable.t()` of `%Event{}` structs.
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/events", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # Public: from_map/1
  # ---------------------------------------------------------------------------

  @doc """
  Converts a decoded Stripe API map to a `%Event{}` struct.

  Maps all known Stripe Event fields. Any unrecognized fields are collected
  into the `extra` map so no data is silently lost. Always succeeds (infallible).

  The `data` and `request` fields are kept as raw maps — no further typing is
  applied since event data varies by event type.

  ## Example

      event = LatticeStripe.Event.from_map(%{
        "id" => "evt_1NxGkW2eZvKYlo2CvN93zMW1",
        "type" => "payment_intent.succeeded",
        "object" => "event",
        "data" => %{"object" => %{"id" => "pi_abc123"}}
      })
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "event",
      account: map["account"],
      api_version: map["api_version"],
      context: map["context"],
      created: map["created"],
      data: map["data"],
      livemode: map["livemode"],
      pending_webhooks: map["pending_webhooks"],
      request: map["request"],
      type: map["type"],
      extra: Map.drop(map, @known_fields)
    }
  end
end

defimpl Inspect, for: LatticeStripe.Event do
  import Inspect.Algebra

  def inspect(event, opts) do
    # Show only structural / safe fields for quick identification.
    # Hide: data (may be large/sensitive), request, account, extra.
    fields = [
      id: event.id,
      type: event.type,
      object: event.object,
      created: event.created,
      livemode: event.livemode
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Event<" | pairs] ++ [">"])
  end
end
