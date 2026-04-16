defmodule LatticeStripe.Billing.Meter do
  @moduledoc """
  Stripe Billing Meter resource — usage-based billing schema.

  See `guides/metering.md` (landed in Plan 20-06) for the full usage story,
  including the two-layer idempotency contract, the 35-day backdating window,
  and the `v1.billing.meter.error_report_triggered` webhook.

  ## Lifecycle

  Meters are created once per usage concept, reported against via
  `LatticeStripe.Billing.MeterEvent.create/3`, and eventually retired via
  `deactivate/3`. A deactivated meter can be brought back with `reactivate/3`;
  deletion is not exposed by the Stripe API.

  ## Usage

      client = LatticeStripe.Client.new!(api_key: "sk_live_...", finch: MyApp.Finch)

      # Create a meter with sum aggregation
      {:ok, meter} = LatticeStripe.Billing.Meter.create(client, %{
        "display_name" => "API Calls",
        "event_name" => "api_call",
        "default_aggregation" => %{"formula" => "sum"},
        "value_settings" => %{"event_payload_key" => "value"}
      })

      # Deactivate when no longer needed
      {:ok, _meter} = LatticeStripe.Billing.Meter.deactivate(client, meter.id)
  """

  alias LatticeStripe.Billing

  alias LatticeStripe.Billing.Meter.{
    CustomerMapping,
    DefaultAggregation,
    StatusTransitions,
    ValueSettings
  }

  alias LatticeStripe.{Client, Request, Resource}

  @known_fields ~w(id object display_name event_name status default_aggregation
                   customer_mapping value_settings status_transitions created
                   updated livemode)

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t() | nil,
          display_name: String.t() | nil,
          event_name: String.t() | nil,
          status: atom() | String.t() | nil,
          default_aggregation: DefaultAggregation.t() | nil,
          customer_mapping: CustomerMapping.t() | nil,
          value_settings: ValueSettings.t() | nil,
          status_transitions: StatusTransitions.t() | nil,
          created: integer() | nil,
          updated: integer() | nil,
          livemode: boolean() | nil,
          extra: map()
        }

  defstruct [
    :id,
    object: "billing.meter",
    :display_name,
    :event_name,
    :status,
    :default_aggregation,
    :customer_mapping,
    :value_settings,
    :status_transitions,
    :created,
    :updated,
    :livemode,
    extra: %{}
  ]

  # ---------------------------------------------------------------------------
  # CREATE
  # ---------------------------------------------------------------------------

  @doc """
  Create a billing meter.

  Requires `display_name`, `event_name`, and `default_aggregation` params
  (string keys — Stripe wire format). After param validation, a pre-flight
  guard raises `ArgumentError` on present-but-malformed `value_settings` for
  sum/last formulas (T-20-01 silent-zero trap).
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, LatticeStripe.Error.t()}
  def create(%Client{} = client, params, opts \\ []) when is_map(params) do
    Resource.require_param!(
      params,
      "display_name",
      "LatticeStripe.Billing.Meter.create/3 requires a display_name param"
    )

    Resource.require_param!(
      params,
      "event_name",
      "LatticeStripe.Billing.Meter.create/3 requires an event_name param"
    )

    Resource.require_param!(
      params,
      "default_aggregation",
      "LatticeStripe.Billing.Meter.create/3 requires a default_aggregation param"
    )

    Billing.Guards.check_meter_value_settings!(params)

    %Request{method: :post, path: "/v1/billing/meters", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Bang variant of `create/3`. Raises `LatticeStripe.Error` on failure."
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(client, params, opts \\ []),
    do: client |> create(params, opts) |> Resource.unwrap_bang!()

  # ---------------------------------------------------------------------------
  # RETRIEVE
  # ---------------------------------------------------------------------------

  @doc """
  Retrieve a billing meter by ID.
  """
  @spec retrieve(Client.t(), String.t(), keyword()) ::
          {:ok, t()} | {:error, LatticeStripe.Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/billing/meters/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Bang variant of `retrieve/3`. Raises `LatticeStripe.Error` on failure."
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(client, id, opts \\ []),
    do: client |> retrieve(id, opts) |> Resource.unwrap_bang!()

  # ---------------------------------------------------------------------------
  # UPDATE
  # ---------------------------------------------------------------------------

  @doc """
  Update a billing meter.

  At time of writing, Stripe only mutates `display_name`; other keys in
  `params` are passed through to the API for forward compatibility. If Stripe
  later exposes additional mutable fields, this function will begin accepting
  them automatically without a library change.
  """
  @spec update(Client.t(), String.t(), map(), keyword()) ::
          {:ok, t()} | {:error, LatticeStripe.Error.t()}
  def update(%Client{} = client, id, params, opts \\ [])
      when is_binary(id) and is_map(params) do
    %Request{method: :post, path: "/v1/billing/meters/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Bang variant of `update/4`. Raises `LatticeStripe.Error` on failure."
  @spec update!(Client.t(), String.t(), map(), keyword()) :: t()
  def update!(client, id, params, opts \\ []),
    do: client |> update(id, params, opts) |> Resource.unwrap_bang!()

  # ---------------------------------------------------------------------------
  # LIST + STREAM
  # ---------------------------------------------------------------------------

  @doc """
  List billing meters. Supports cursor-based pagination via `starting_after`
  and `ending_before`, and filtering via `status` (`"active"` | `"inactive"`).
  """
  @spec list(Client.t(), map(), keyword()) ::
          {:ok, LatticeStripe.Response.t()} | {:error, LatticeStripe.Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/billing/meters", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc "Bang variant of `list/3`. Raises `LatticeStripe.Error` on failure."
  @spec list!(Client.t(), map(), keyword()) :: LatticeStripe.Response.t()
  def list!(client, params \\ %{}, opts \\ []),
    do: client |> list(params, opts) |> Resource.unwrap_bang!()

  @doc """
  Returns a lazy stream of all billing meters (auto-pagination).

  Emits individual `%Meter{}` structs, fetching additional pages as needed.
  Raises `LatticeStripe.Error` if any page fetch fails.
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/billing/meters", params: params, opts: opts}
    LatticeStripe.List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # LIFECYCLE VERBS
  # ---------------------------------------------------------------------------

  @doc """
  Deactivate a meter — POST `/v1/billing/meters/{id}/deactivate`.

  Use this instead of `update/4` with a `status` param (Stripe does not
  accept that shape). Deactivated meters reject new events with the
  `archived_meter` error code.
  """
  @spec deactivate(Client.t(), String.t(), keyword()) ::
          {:ok, t()} | {:error, LatticeStripe.Error.t()}
  def deactivate(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/billing/meters/#{id}/deactivate", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Bang variant of `deactivate/3`. Raises `LatticeStripe.Error` on failure."
  @spec deactivate!(Client.t(), String.t(), keyword()) :: t()
  def deactivate!(client, id, opts \\ []),
    do: client |> deactivate(id, opts) |> Resource.unwrap_bang!()

  @doc """
  Reactivate a previously-deactivated meter — POST `/v1/billing/meters/{id}/reactivate`.
  """
  @spec reactivate(Client.t(), String.t(), keyword()) ::
          {:ok, t()} | {:error, LatticeStripe.Error.t()}
  def reactivate(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/billing/meters/#{id}/reactivate", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Bang variant of `reactivate/3`. Raises `LatticeStripe.Error` on failure."
  @spec reactivate!(Client.t(), String.t(), keyword()) :: t()
  def reactivate!(client, id, opts \\ []),
    do: client |> reactivate(id, opts) |> Resource.unwrap_bang!()

  # ---------------------------------------------------------------------------
  # DECODE + STATUS HELPER
  # ---------------------------------------------------------------------------

  @doc """
  Decode a Stripe-shaped string-keyed map into a `%Meter{}`.

  Nested sub-objects (`default_aggregation`, `customer_mapping`,
  `value_settings`, `status_transitions`) are decoded via their respective
  `from_map/1` callbacks. Unknown top-level keys land in `:extra`.
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "billing.meter",
      display_name: known["display_name"],
      event_name: known["event_name"],
      status: atomize_status(known["status"]),
      default_aggregation: DefaultAggregation.from_map(known["default_aggregation"]),
      customer_mapping: CustomerMapping.from_map(known["customer_mapping"]),
      value_settings: ValueSettings.from_map(known["value_settings"]),
      status_transitions: StatusTransitions.from_map(known["status_transitions"]),
      created: known["created"],
      updated: known["updated"],
      livemode: known["livemode"],
      extra: extra
    }
  end

  # ---------------------------------------------------------------------------
  # Private: atomization helpers
  # ---------------------------------------------------------------------------

  defp atomize_status("active"),   do: :active
  defp atomize_status("inactive"), do: :inactive
  defp atomize_status(other),      do: other

  @deprecated "Status is now automatically atomized in from_map/1. Access meter.status directly."
  @spec status_atom(t() | String.t() | nil) :: atom()
  def status_atom(%__MODULE__{status: s}), do: s
  def status_atom(nil), do: nil
  def status_atom(s) when is_atom(s), do: s
  def status_atom(s), do: atomize_status(s)
end
