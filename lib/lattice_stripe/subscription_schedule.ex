defmodule LatticeStripe.SubscriptionSchedule do
  @moduledoc """
  Operations on Stripe Subscription Schedule objects.

  A Subscription Schedule lets you define a phased billing timeline — each
  phase describes the prices, quantities, proration behavior, and trial
  settings for a slice of time. When one phase ends, the schedule transitions
  to the next and applies the new configuration to the underlying Subscription.

  ## Creation modes

  Stripe accepts two mutually-exclusive parameter shapes on create:

  ### Mode 1: `from_subscription`

  Convert an existing Subscription into a schedule whose first phase captures
  the subscription's current state.

      LatticeStripe.SubscriptionSchedule.create(client, %{
        "from_subscription" => "sub_1234567890"
      })

  ### Mode 2: `customer` + `phases`

  Build a new schedule from scratch with an explicit phase timeline.

      LatticeStripe.SubscriptionSchedule.create(client, %{
        "customer" => "cus_1234567890",
        "start_date" => "now",
        "end_behavior" => "release",
        "phases" => [
          %{
            "items" => [%{"price" => "price_1234567890", "quantity" => 1}],
            "iterations" => 12,
            "proration_behavior" => "create_prorations"
          }
        ]
      })

  Mixing fields from both modes in a single call raises a Stripe 400 that
  surfaces as `{:error, %LatticeStripe.Error{type: :invalid_request_error}}`.
  LatticeStripe does not client-side-validate the mode — Stripe's own error
  is already actionable.

  ## cancel vs release

  - `cancel/4` (added in Plan 16-02) terminates **both** the schedule AND the
    underlying Subscription.
  - `release/4` (added in Plan 16-02) detaches the schedule from its
    Subscription; the Subscription remains active and billable but is no
    longer governed by phases. This is irreversible.

  ## Search

  Stripe does not expose a `search` endpoint for Subscription Schedules
  (unlike Subscriptions). This module therefore has no `search/3` or
  `search_stream!/3`.

  ## Proration guard

  When a client has `require_explicit_proration: true`, `update/4` requires
  `proration_behavior` at either the top level of `params` or inside any
  element of `params["phases"][]`. Stripe does not accept
  `proration_behavior` at `phases[].items[]`, so the guard does not walk
  that deep. (Wiring is added in Plan 16-02 — this plan ships the resource
  shape unguarded.)

  ## Telemetry

  SubscriptionSchedule operations piggyback on the general
  `[:lattice_stripe, :request, *]` events emitted by `Client.request/2`. No
  schedule-specific events are emitted — state transitions belong to webhook
  handlers, not the SDK layer.

  ## Stripe API Reference

  See the [Stripe Subscription Schedules API](https://docs.stripe.com/api/subscription_schedules).
  """

  alias LatticeStripe.{Client, Error, Request, Resource, Response}
  alias LatticeStripe.SubscriptionSchedule.{CurrentPhase, Phase}

  @known_fields ~w[
    id object application billing_mode canceled_at completed_at created current_phase
    customer customer_account default_settings end_behavior livemode metadata phases
    released_at released_subscription status subscription test_clock
  ]

  defstruct [
    :id,
    :application,
    :billing_mode,
    :canceled_at,
    :completed_at,
    :created,
    :current_phase,
    :customer,
    :customer_account,
    :default_settings,
    :end_behavior,
    :livemode,
    :metadata,
    :phases,
    :released_at,
    :released_subscription,
    :status,
    :subscription,
    :test_clock,
    object: "subscription_schedule",
    extra: %{}
  ]

  @typedoc """
  A Stripe Subscription Schedule.

  See the [Stripe SubscriptionSchedule object](https://docs.stripe.com/api/subscription_schedules/object)
  for field definitions.
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          application: String.t() | nil,
          billing_mode: String.t() | nil,
          canceled_at: integer() | nil,
          completed_at: integer() | nil,
          created: integer() | nil,
          current_phase: CurrentPhase.t() | nil,
          customer: String.t() | nil,
          customer_account: String.t() | nil,
          default_settings: Phase.t() | nil,
          end_behavior: String.t() | nil,
          livemode: boolean() | nil,
          metadata: map() | nil,
          phases: [Phase.t()] | nil,
          released_at: integer() | nil,
          released_subscription: String.t() | nil,
          status: String.t() | nil,
          subscription: String.t() | nil,
          test_clock: String.t() | nil,
          extra: map()
        }

  # ---------------------------------------------------------------------------
  # Public API: CRUD
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new Subscription Schedule.

  Sends `POST /v1/subscription_schedules`. See the module `@moduledoc` for the
  two mutually-exclusive parameter shapes (`from_subscription` vs
  `customer` + `phases`).

  Stripe does not accept `proration_behavior` on create — schedules prorate
  based on `start_date` mode, not an explicit field — so this function does
  NOT run the proration guard.
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ [])
      when is_map(params) and is_list(opts) do
    %Request{method: :post, path: "/v1/subscription_schedules", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `create/3` but raises on failure."
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(%Client{} = client, params \\ %{}, opts \\ [])
      when is_map(params) and is_list(opts),
      do: client |> create(params, opts) |> Resource.unwrap_bang!()

  @doc """
  Retrieves a Subscription Schedule by ID.

  Sends `GET /v1/subscription_schedules/:id`.
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) and is_list(opts) do
    %Request{method: :get, path: "/v1/subscription_schedules/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `retrieve/3` but raises on failure."
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) and is_list(opts),
    do: client |> retrieve(id, opts) |> Resource.unwrap_bang!()

  @doc """
  Updates a Subscription Schedule by ID.

  Sends `POST /v1/subscription_schedules/:id`.

  > #### Proration guard {: .info}
  >
  > Plan 16-02 wires `LatticeStripe.Billing.Guards.check_proration_required/2`
  > into this function. Until then, `update/4` does not enforce
  > `require_explicit_proration: true` on this resource.
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, id, params \\ %{}, opts \\ [])
      when is_binary(id) and is_map(params) and is_list(opts) do
    # NOTE: Plan 16-02 Task 3 adds Billing.Guards.check_proration_required/2 here.
    # Keep this call path narrow so that wiring is a single-line diff.
    %Request{method: :post, path: "/v1/subscription_schedules/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `update/4` but raises on failure."
  @spec update!(Client.t(), String.t(), map(), keyword()) :: t()
  def update!(%Client{} = client, id, params \\ %{}, opts \\ [])
      when is_binary(id) and is_map(params) and is_list(opts),
      do: client |> update(id, params, opts) |> Resource.unwrap_bang!()

  @doc """
  Lists Subscription Schedules with optional filters.

  Sends `GET /v1/subscription_schedules`.
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) when is_map(params) and is_list(opts) do
    %Request{method: :get, path: "/v1/subscription_schedules", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc "Like `list/3` but raises on failure."
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) when is_map(params) and is_list(opts),
    do: client |> list(params, opts) |> Resource.unwrap_bang!()

  @doc """
  Returns a lazy stream of all Subscription Schedules matching the given params.

  Auto-paginates via `LatticeStripe.List.stream!/2`. Raises on fetch failure.
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ [])
      when is_map(params) and is_list(opts) do
    req = %Request{method: :get, path: "/v1/subscription_schedules", params: params, opts: opts}
    LatticeStripe.List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # Public API: Action verbs (cancel/release)
  # ---------------------------------------------------------------------------

  @doc """
  Cancels a Subscription Schedule.

  Terminates the schedule AND the underlying Subscription. Both entities move
  to `canceled` status. This is irreversible.

  ## Wire shape

  Dispatches `POST /v1/subscription_schedules/:id/cancel` — unlike
  `LatticeStripe.Subscription.cancel/4` which uses DELETE. Do not mix them up.

  ## Params

  - `"invoice_now"` (boolean) — whether to generate a final invoice
    immediately for any prorations
  - `"prorate"` (boolean) — whether to prorate the cancellation

  Note: the `prorate` param here is unrelated to `proration_behavior`. It
  controls whether a proration invoice is generated on cancel, not which
  proration strategy applies to a future item change. LatticeStripe does NOT
  run `check_proration_required/2` on this call.

  ## Contrast with `release/4`

  - `cancel/4` terminates both schedule and subscription.
  - `release/4` detaches the schedule; the subscription stays active.

  ## Examples

      iex> LatticeStripe.SubscriptionSchedule.cancel(client, "sub_sched_123", %{"invoice_now" => true})
      {:ok, %LatticeStripe.SubscriptionSchedule{status: "canceled"}}
  """
  @spec cancel(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def cancel(%Client{} = client, id, params \\ %{}, opts \\ [])
      when is_binary(id) and is_map(params) and is_list(opts) do
    %Request{
      method: :post,
      path: "/v1/subscription_schedules/#{id}/cancel",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `cancel/4` but raises on failure."
  @spec cancel!(Client.t(), String.t(), map(), keyword()) :: t()
  def cancel!(%Client{} = client, id, params \\ %{}, opts \\ [])
      when is_binary(id) and is_map(params) and is_list(opts),
      do: client |> cancel(id, params, opts) |> Resource.unwrap_bang!()

  @doc """
  Releases a Subscription Schedule.

  Detaches the schedule from its Subscription. The Subscription remains
  active and billable but is no longer governed by phases — subsequent
  configuration changes must go through `LatticeStripe.Subscription.update/4`
  directly.

  **This is irreversible.** Once a schedule is released, there is no API to
  re-attach it. If you need to regain phase-based control, you must create a
  new schedule from the now-detached subscription (if policy allows).

  ## Contrast with `cancel/4`

  - `release/4` detaches the schedule; the subscription continues billing
    but is no longer phase-governed.
  - `cancel/4` terminates BOTH the schedule AND the underlying subscription.

  Use `release/4` when you want to graduate a subscription off a phased plan
  into a flat ongoing subscription. Use `cancel/4` when you want to end
  billing entirely.

  ## Wire shape

  Dispatches `POST /v1/subscription_schedules/:id/release`.

  ## Params

  - `"preserve_cancel_date"` (boolean) — if the underlying subscription had
    a scheduled cancellation date, whether to preserve it on release

  ## Examples

      iex> LatticeStripe.SubscriptionSchedule.release(client, "sub_sched_123")
      {:ok, %LatticeStripe.SubscriptionSchedule{status: "released"}}
  """
  @spec release(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def release(%Client{} = client, id, params \\ %{}, opts \\ [])
      when is_binary(id) and is_map(params) and is_list(opts) do
    %Request{
      method: :post,
      path: "/v1/subscription_schedules/#{id}/release",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `release/4` but raises on failure."
  @spec release!(Client.t(), String.t(), map(), keyword()) :: t()
  def release!(%Client{} = client, id, params \\ %{}, opts \\ [])
      when is_binary(id) and is_map(params) and is_list(opts),
      do: client |> release(id, params, opts) |> Resource.unwrap_bang!()

  # ---------------------------------------------------------------------------
  # Public: from_map/1
  # ---------------------------------------------------------------------------

  @doc """
  Converts a decoded Stripe API map to a `%SubscriptionSchedule{}` struct.

  Decodes nested typed structs:
  - `current_phase` → `%LatticeStripe.SubscriptionSchedule.CurrentPhase{}`
  - `default_settings` → `%LatticeStripe.SubscriptionSchedule.Phase{}` (reused)
  - `phases` → `[%LatticeStripe.SubscriptionSchedule.Phase{}]`

  Unknown top-level fields are collected into `:extra`.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "subscription_schedule",
      application: known["application"],
      billing_mode: known["billing_mode"],
      canceled_at: known["canceled_at"],
      completed_at: known["completed_at"],
      created: known["created"],
      current_phase: CurrentPhase.from_map(known["current_phase"]),
      customer: known["customer"],
      customer_account: known["customer_account"],
      default_settings: Phase.from_map(known["default_settings"]),
      end_behavior: known["end_behavior"],
      livemode: known["livemode"],
      metadata: known["metadata"],
      phases: decode_phases(known["phases"]),
      released_at: known["released_at"],
      released_subscription: known["released_subscription"],
      status: known["status"],
      subscription: known["subscription"],
      test_clock: known["test_clock"],
      extra: extra
    }
  end

  defp decode_phases(nil), do: nil
  defp decode_phases(phases) when is_list(phases), do: Enum.map(phases, &Phase.from_map/1)
  defp decode_phases(other), do: other
end

defimpl Inspect, for: LatticeStripe.SubscriptionSchedule do
  import Inspect.Algebra

  # PII-safe Inspect. Mirrors LatticeStripe.Subscription (lib/lattice_stripe/subscription.ex
  # lines 520-547). This is the ONLY defimpl Inspect block in all of Phase 16.
  #
  # Masking strategy: never surface nested collections (`phases`, `default_settings`,
  # `customer`, `subscription`, `released_subscription`). Emit presence booleans and a
  # `phase_count` integer instead. This prevents `default_payment_method` from leaking
  # via default derived Inspect on the nested `Phase` struct (which intentionally has
  # no custom Inspect impl per locked D1).
  def inspect(sched, opts) do
    base = [
      id: sched.id,
      object: sched.object,
      status: sched.status,
      end_behavior: sched.end_behavior,
      current_phase: sched.current_phase,
      livemode: sched.livemode,
      has_customer?: not is_nil(sched.customer),
      has_subscription?: not is_nil(sched.subscription),
      has_released_subscription?: not is_nil(sched.released_subscription),
      has_default_settings?: not is_nil(sched.default_settings),
      phase_count: if(is_list(sched.phases), do: length(sched.phases), else: 0)
    ]

    fields = if sched.extra == %{}, do: base, else: base ++ [extra: sched.extra]

    pairs =
      fields
      |> Enum.map(fn {k, v} -> concat([Atom.to_string(k), ": ", to_doc(v, opts)]) end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.SubscriptionSchedule<" | pairs] ++ [">"])
  end
end
