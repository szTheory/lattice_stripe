defmodule LatticeStripe.Billing.MeterEvent do
  @moduledoc """
  Stripe Billing MeterEvent — hot-path usage reporting. Create-only; Stripe
  exposes no retrieve/list operations for events. See `guides/metering.md`
  for the full `AccrueLike.UsageReporter` recipe and the two-layer
  idempotency contract.
  """

  alias LatticeStripe.{Client, Request, Resource}

  @type t :: %__MODULE__{
          event_name: String.t() | nil,
          identifier: String.t() | nil,
          payload: map() | nil,
          timestamp: integer() | nil,
          created: integer() | nil,
          livemode: boolean() | nil
        }

  defstruct [:event_name, :identifier, :payload, :timestamp, :created, :livemode]

  @doc """
  Report a metered usage event to Stripe.

  ## Params

  - `event_name` (required, string) — must match a `Billing.Meter.event_name`
  - `payload` (required, map) — customer-mapping key plus the numeric value (for
    sum/last meters); the payload key that carries the value is the meter's
    `value_settings.event_payload_key` (default `"value"`)
  - `timestamp` (optional, integer — Unix seconds) — when the usage occurred;
    must be within the 35-day backdating window and no more than 5 minutes in
    the future
  - `identifier` (optional, string, ≤100 chars) — **body-level (business-layer)
    idempotency**; Stripe dedups on this for 24 hours. Use a stable
    domain-derived value (e.g. `"inv_123:item_456"`)

  ## Opts

  - `idempotency_key:` (optional, string) — **transport-layer (HTTP header)
    idempotency**; replays the exact previous response for the same key on
    network retries. **Orthogonal to body `identifier`.** Set BOTH in production
    for full safety: `identifier` protects against duplicate domain events,
    `idempotency_key:` protects against network-level retries.
  - `stripe_account:` (optional, string) — `acct_*` for Connect scenarios

  ## Return value — IMPORTANT

  `{:ok, %MeterEvent{}}` means Stripe **accepted for processing**
  — it does **not** mean the event has been recorded against a customer.
  Customer-mapping validation happens **asynchronously** in Stripe's billing
  pipeline. The ONLY way to detect customer-mapping failures, invalid values,
  or a missing payload key is to subscribe to the
  `v1.billing.meter.error_report_triggered` webhook. See
  `guides/metering.md` → "Reconciliation via webhooks" for the error code
  table and remediation patterns.

  ## Example

      {:ok, event} = LatticeStripe.Billing.MeterEvent.create(client, %{
        "event_name" => "api_call",
        "payload" => %{"stripe_customer_id" => "cus_123", "value" => "1"},
        "identifier" => "req_abc"
      }, idempotency_key: "req_abc")
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, LatticeStripe.Error.t()}
  def create(%Client{} = client, params, opts \\ []) when is_map(params) do
    Resource.require_param!(params, "event_name",
      "LatticeStripe.Billing.MeterEvent.create/3 requires an event_name param")

    Resource.require_param!(params, "payload",
      "LatticeStripe.Billing.MeterEvent.create/3 requires a payload param")

    %Request{method: :post, path: "/v1/billing/meter_events", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Bang variant of `create/3`. Raises `LatticeStripe.Error` on failure."
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(client, params, opts \\ []),
    do: client |> create(params, opts) |> Resource.unwrap_bang!()

  @doc """
  Decode a Stripe-shaped string-keyed map into a `%MeterEvent{}`.

  MeterEvent has no nested sub-objects. Unknown keys are silently dropped
  (no `:extra` field) per EVENT-05 minimal-struct contract.
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      event_name: map["event_name"],
      identifier: map["identifier"],
      payload: map["payload"],
      timestamp: map["timestamp"],
      created: map["created"],
      livemode: map["livemode"]
    }
  end
end

defimpl Inspect, for: LatticeStripe.Billing.MeterEvent do
  import Inspect.Algebra

  def inspect(event, opts) do
    # Allowlist structural fields only. `:payload` is hidden because it
    # carries the customer-mapping key (e.g. stripe_customer_id) and the
    # metered value, both commercially sensitive when surfaced in Logger
    # output, crash dumps, or telemetry handlers.
    #
    # To see the payload during debugging:
    #     IO.inspect(event, structs: false)
    #     # or
    #     event.payload
    fields = [
      event_name: event.event_name,
      identifier: event.identifier,
      timestamp: event.timestamp,
      created: event.created,
      livemode: event.livemode
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Billing.MeterEvent<" | pairs] ++ [">"])
  end
end
