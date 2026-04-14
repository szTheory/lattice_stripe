defmodule LatticeStripe.Billing.MeterEventAdjustment do
  @moduledoc """
  Stripe Billing MeterEventAdjustment — correct a previously-reported
  `MeterEvent` within Stripe's 24-hour cancellation window. Create-only.

  Only the `cancel` action is currently exposed by Stripe; it must contain
  a `cancel.identifier` matching the `identifier` of the event you want to
  cancel. See `guides/metering.md` → "Corrections and adjustments" for the
  dunning worked example.
  """

  alias LatticeStripe.Billing.Guards
  alias LatticeStripe.Billing.MeterEventAdjustment.Cancel
  alias LatticeStripe.{Client, Request, Resource}

  @known_fields ~w(id object event_name status cancel livemode)

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t() | nil,
          event_name: String.t() | nil,
          status: String.t() | nil,
          cancel: Cancel.t() | nil,
          livemode: boolean() | nil,
          extra: map()
        }

  defstruct [:id, :object, :event_name, :status, :cancel, :livemode, extra: %{}]

  @doc """
  Create a meter event adjustment. The `cancel` param MUST be a nested map
  with an `identifier` key — NOT a top-level `identifier`, NOT `cancel.id`,
  NOT `cancel.event_id`. Example:

      MeterEventAdjustment.create(client, %{
        "event_name" => "api_call",
        "cancel" => %{"identifier" => "req_abc"}
      })

  Stripe enforces a 24-hour cancellation window from the original event's
  `created` timestamp; adjustments outside this window return `out_of_window`.
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, LatticeStripe.Error.t()}
  def create(%Client{} = client, params, opts \\ []) when is_map(params) do
    Resource.require_param!(params, "event_name",
      "LatticeStripe.Billing.MeterEventAdjustment.create/3 requires an event_name param")

    Resource.require_param!(params, "cancel",
      "LatticeStripe.Billing.MeterEventAdjustment.create/3 requires a cancel param " <>
        "shaped as %{\"identifier\" => \"<meter_event_identifier>\"}")

    Guards.check_adjustment_cancel_shape!(params)

    %Request{method: :post, path: "/v1/billing/meter_event_adjustments", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Bang variant of `create/3`. Raises `LatticeStripe.Error` on failure."
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(client, params, opts \\ []),
    do: client |> create(params, opts) |> Resource.unwrap_bang!()

  @doc """
  Decode a Stripe-shaped string-keyed map into a `%MeterEventAdjustment{}`.

  The `cancel` sub-object is decoded into `%Cancel{}` via `Cancel.from_map/1`.
  Unknown top-level keys land in `:extra`.
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"],
      event_name: map["event_name"],
      status: map["status"],
      cancel: Cancel.from_map(map["cancel"]),
      livemode: map["livemode"],
      extra: Map.drop(map, @known_fields)
    }
  end
end
