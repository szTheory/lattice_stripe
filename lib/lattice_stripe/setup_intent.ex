defmodule LatticeStripe.SetupIntent do
  @moduledoc """
  Operations on Stripe SetupIntent objects.

  A SetupIntent guides you through the process of setting up and saving a customer's
  payment method for future payments. Use SetupIntents when you want to save a payment
  method without immediately collecting payment.

  Common use cases include:
  - Saving a card for subscription billing (usage: `"off_session"`)
  - Saving a card to charge at a later date
  - Migrating existing payment method data

  ## Usage

      client = LatticeStripe.Client.new!(api_key: "sk_live_...", finch: MyApp.Finch)

      # Create a SetupIntent to save a payment method for future use
      {:ok, si} = LatticeStripe.SetupIntent.create(client, %{
        "customer" => "cus_123",
        "usage" => "off_session",
        "payment_method_types" => ["card"]
      })

      # Confirm the SetupIntent with a payment method
      {:ok, si} = LatticeStripe.SetupIntent.confirm(client, si.id, %{
        "payment_method" => "pm_card_visa"
      })

      # Cancel a SetupIntent that is no longer needed
      {:ok, si} = LatticeStripe.SetupIntent.cancel(client, si.id, %{
        "cancellation_reason" => "abandoned"
      })

      # Verify microdeposits for bank account payment methods (e.g., ACH/BECS)
      {:ok, si} = LatticeStripe.SetupIntent.verify_microdeposits(client, si.id, %{
        "amounts" => [32, 45]
      })

      # List SetupIntents with filters
      {:ok, resp} = LatticeStripe.SetupIntent.list(client, %{"customer" => "cus_123"})
      setup_intents = resp.data.data  # [%SetupIntent{}, ...]

      # Stream all SetupIntents lazily (auto-pagination)
      client
      |> LatticeStripe.SetupIntent.stream!()
      |> Stream.take(100)
      |> Enum.each(&process_setup_intent/1)

  ## Security and Inspect

  The `Inspect` implementation hides `client_secret` — this value must never
  appear in logs. Only `id`, `object`, `status`, and `usage` are shown in
  inspect output.

  Note: SetupIntents cannot be deleted. There is no `delete/3` function.
  """

  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}

  # Known top-level fields from the Stripe SetupIntent object.
  # Used to build the struct and separate known from extra (unknown) fields.
  # String sigil (no `a`) matches Jason's default string-key output.
  @known_fields ~w[
    id object application attach_to_self automatic_payment_methods
    cancellation_reason client_secret created customer customer_account
    description excluded_payment_method_types flow_directions
    last_setup_error latest_attempt livemode mandate metadata
    next_action on_behalf_of payment_method payment_method_configuration_details
    payment_method_options payment_method_types single_use_mandate status usage
  ]

  defstruct [
    :id,
    :application,
    :attach_to_self,
    :automatic_payment_methods,
    :cancellation_reason,
    :client_secret,
    :created,
    :customer,
    :customer_account,
    :description,
    :excluded_payment_method_types,
    :flow_directions,
    :last_setup_error,
    :latest_attempt,
    :livemode,
    :mandate,
    :metadata,
    :next_action,
    :on_behalf_of,
    :payment_method,
    :payment_method_configuration_details,
    :payment_method_options,
    :payment_method_types,
    :single_use_mandate,
    :status,
    :usage,
    object: "setup_intent",
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          application: String.t() | nil,
          attach_to_self: boolean() | nil,
          automatic_payment_methods: map() | nil,
          cancellation_reason: String.t() | nil,
          client_secret: String.t() | nil,
          created: integer() | nil,
          customer: String.t() | nil,
          customer_account: map() | nil,
          description: String.t() | nil,
          excluded_payment_method_types: [String.t()] | nil,
          flow_directions: [String.t()] | nil,
          last_setup_error: map() | nil,
          latest_attempt: String.t() | map() | nil,
          livemode: boolean() | nil,
          mandate: String.t() | nil,
          metadata: map() | nil,
          next_action: map() | nil,
          on_behalf_of: String.t() | nil,
          payment_method: String.t() | nil,
          payment_method_configuration_details: map() | nil,
          payment_method_options: map() | nil,
          payment_method_types: [String.t()] | nil,
          single_use_mandate: String.t() | nil,
          status: String.t() | nil,
          usage: String.t() | nil,
          extra: map()
        }

  # ---------------------------------------------------------------------------
  # Public API: CRUD operations
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new SetupIntent.

  Sends `POST /v1/setup_intents` with the given params and returns
  `{:ok, %SetupIntent{}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Map of SetupIntent attributes (e.g., `%{"customer" => "cus_123", "usage" => "off_session"}`)
  - `opts` - Per-request overrides (e.g., `[idempotency_key: "..."]`)

  ## Returns

  - `{:ok, %SetupIntent{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, si} = LatticeStripe.SetupIntent.create(client, %{
        "customer" => "cus_123",
        "payment_method_types" => ["card"]
      })
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: "/v1/setup_intents", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Retrieves a SetupIntent by ID.

  Sends `GET /v1/setup_intents/:id` and returns `{:ok, %SetupIntent{}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The SetupIntent ID string (e.g., `"seti_123"`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %SetupIntent{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/setup_intents/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Updates a SetupIntent by ID.

  Sends `POST /v1/setup_intents/:id` with the given params and returns
  `{:ok, %SetupIntent{}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The SetupIntent ID string
  - `params` - Map of fields to update
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %SetupIntent{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/setup_intents/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Confirms a SetupIntent, attempting to save the payment method.

  Sends `POST /v1/setup_intents/:id/confirm` with optional params and returns
  `{:ok, %SetupIntent{}}`. After confirmation, the SetupIntent will have a
  `status` indicating whether the setup succeeded or requires additional steps.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The SetupIntent ID string
  - `params` - Optional confirmation params (e.g., `%{"payment_method" => "pm_..."}`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %SetupIntent{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, si} = LatticeStripe.SetupIntent.confirm(client, si.id, %{
        "payment_method" => "pm_card_visa"
      })
  """
  @spec confirm(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def confirm(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/setup_intents/#{id}/confirm", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Cancels a SetupIntent.

  Sends `POST /v1/setup_intents/:id/cancel` with optional params and returns
  `{:ok, %SetupIntent{status: "canceled"}}`. A SetupIntent can be canceled when
  it is in `requires_payment_method`, `requires_confirmation`, or
  `requires_action` status.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The SetupIntent ID string
  - `params` - Optional cancel params (e.g., `%{"cancellation_reason" => "abandoned"}`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %SetupIntent{status: "canceled"}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, si} = LatticeStripe.SetupIntent.cancel(client, si.id, %{
        "cancellation_reason" => "abandoned"
      })
  """
  @spec cancel(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def cancel(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/setup_intents/#{id}/cancel", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Verifies microdeposits on a SetupIntent for bank account payment methods.

  Sends `POST /v1/setup_intents/:id/verify_microdeposits` with the deposit amounts
  or descriptor code and returns `{:ok, %SetupIntent{}}`. Used for ACH, BECS, and
  similar bank transfer payment methods that require microdeposit verification.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The SetupIntent ID string
  - `params` - Verification params:
    - `%{"amounts" => [32, 45]}` for amount-based verification
    - `%{"descriptor_code" => "SM11AA"}` for descriptor-based verification
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %SetupIntent{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, si} = LatticeStripe.SetupIntent.verify_microdeposits(client, si.id, %{
        "amounts" => [32, 45]
      })
  """
  @spec verify_microdeposits(Client.t(), String.t(), map(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def verify_microdeposits(%Client{} = client, id, params \\ %{}, opts \\ [])
      when is_binary(id) do
    %Request{
      method: :post,
      path: "/v1/setup_intents/#{id}/verify_microdeposits",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Lists SetupIntents with optional filters.

  Sends `GET /v1/setup_intents` and returns `{:ok, %Response{data: %List{}}}` with
  typed `%SetupIntent{}` items.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Filter params (e.g., `%{"customer" => "cus_123", "limit" => "10"}`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Response{data: %List{data: [%SetupIntent{}, ...]}}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, resp} = LatticeStripe.SetupIntent.list(client, %{"customer" => "cus_123"})
      Enum.each(resp.data.data, &IO.inspect/1)
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/setup_intents", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Returns a lazy stream of all SetupIntents matching the given params (auto-pagination).

  Emits individual `%SetupIntent{}` structs, fetching additional pages as needed.
  Raises `LatticeStripe.Error` if any page fetch fails.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Filter params (e.g., `%{"limit" => "100"}`)
  - `opts` - Per-request overrides

  ## Returns

  An `Enumerable.t()` of `%SetupIntent{}` structs.

  ## Example

      client
      |> LatticeStripe.SetupIntent.stream!()
      |> Stream.take(500)
      |> Enum.to_list()
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/setup_intents", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # Public API: Bang variants
  # ---------------------------------------------------------------------------

  @doc """
  Like `create/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(%Client{} = client, params \\ %{}, opts \\ []) do
    create(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `retrieve/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    retrieve(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `update/4` but raises `LatticeStripe.Error` on failure.
  """
  @spec update!(Client.t(), String.t(), map(), keyword()) :: t()
  def update!(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    update(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `confirm/4` but raises `LatticeStripe.Error` on failure.
  """
  @spec confirm!(Client.t(), String.t(), map(), keyword()) :: t()
  def confirm!(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    confirm(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `cancel/4` but raises `LatticeStripe.Error` on failure.
  """
  @spec cancel!(Client.t(), String.t(), map(), keyword()) :: t()
  def cancel!(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    cancel(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `verify_microdeposits/4` but raises `LatticeStripe.Error` on failure.
  """
  @spec verify_microdeposits!(Client.t(), String.t(), map(), keyword()) :: t()
  def verify_microdeposits!(%Client{} = client, id, params \\ %{}, opts \\ [])
      when is_binary(id) do
    verify_microdeposits(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `list/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) do
    list(client, params, opts) |> Resource.unwrap_bang!()
  end

  # ---------------------------------------------------------------------------
  # Public: from_map/1
  # ---------------------------------------------------------------------------

  @doc """
  Converts a decoded Stripe API map to a `%SetupIntent{}` struct.

  Maps all known Stripe SetupIntent fields. Any unrecognized fields are
  collected into the `extra` map so no data is silently lost.

  ## Example

      si = LatticeStripe.SetupIntent.from_map(%{
        "id" => "seti_123",
        "status" => "requires_payment_method",
        "usage" => "off_session"
      })
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "setup_intent",
      application: map["application"],
      attach_to_self: map["attach_to_self"],
      automatic_payment_methods: map["automatic_payment_methods"],
      cancellation_reason: map["cancellation_reason"],
      client_secret: map["client_secret"],
      created: map["created"],
      customer: map["customer"],
      customer_account: map["customer_account"],
      description: map["description"],
      excluded_payment_method_types: map["excluded_payment_method_types"],
      flow_directions: map["flow_directions"],
      last_setup_error: map["last_setup_error"],
      latest_attempt: map["latest_attempt"],
      livemode: map["livemode"],
      mandate: map["mandate"],
      metadata: map["metadata"],
      next_action: map["next_action"],
      on_behalf_of: map["on_behalf_of"],
      payment_method: map["payment_method"],
      payment_method_configuration_details: map["payment_method_configuration_details"],
      payment_method_options: map["payment_method_options"],
      payment_method_types: map["payment_method_types"],
      single_use_mandate: map["single_use_mandate"],
      status: map["status"],
      usage: map["usage"],
      extra: Map.drop(map, @known_fields)
    }
  end
end

defimpl Inspect, for: LatticeStripe.SetupIntent do
  import Inspect.Algebra

  def inspect(si, opts) do
    # Show only structural/non-sensitive fields.
    # CRITICAL: client_secret MUST be hidden — it grants ability to confirm setup.
    fields = [
      id: si.id,
      object: si.object,
      status: si.status,
      usage: si.usage
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.SetupIntent<" | pairs] ++ [">"])
  end
end
