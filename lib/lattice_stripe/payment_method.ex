defmodule LatticeStripe.PaymentMethod do
  @moduledoc """
  Operations on Stripe PaymentMethod objects.

  A PaymentMethod represents a customer's payment instrument. PaymentMethods
  are used with PaymentIntents to collect payments or with SetupIntents to save
  payment details for future use.

  ## Key behaviors

  - **`list/3` requires a `"customer"` param** — Stripe only supports
    customer-scoped listing. Calling `list/3` without `%{"customer" => "cus_..."}` in
    params will raise `ArgumentError` before any network call is made. Example:
    `PaymentMethod.list(client, %{"customer" => "cus_123"})`.

  - **`stream!/3` also requires `"customer"`** — Same constraint applies to
    the auto-pagination stream.

  - **PaymentMethods cannot be deleted** — Use `detach/4` to remove a
    PaymentMethod from a customer. The PaymentMethod object will still exist in
    Stripe but `customer` will be set to `nil`.

  - **Type-specific nested objects** — Fields like `card`, `us_bank_account`,
    `sepa_debit`, etc. are `nil` unless the PaymentMethod's `type` matches. For
    example, a card PaymentMethod will have a populated `card` map but `nil`
    `us_bank_account`.

  ## Usage

      client = LatticeStripe.Client.new!(api_key: "sk_live_...", finch: MyApp.Finch)

      # Create a PaymentMethod (card token from frontend)
      {:ok, pm} = LatticeStripe.PaymentMethod.create(client, %{
        "type" => "card",
        "card" => %{"token" => "tok_visa"}
      })

      # Attach it to a customer for reuse
      {:ok, pm} = LatticeStripe.PaymentMethod.attach(client, pm.id, %{
        "customer" => "cus_123"
      })

      # List a customer's PaymentMethods (customer param is required)
      {:ok, resp} = LatticeStripe.PaymentMethod.list(client, %{"customer" => "cus_123"})
      payment_methods = resp.data.data  # [%PaymentMethod{}, ...]

      # Stream all of a customer's PaymentMethods lazily (auto-pagination)
      client
      |> LatticeStripe.PaymentMethod.stream!(%{"customer" => "cus_123"})
      |> Enum.to_list()

      # Detach a PaymentMethod from a customer (does not delete the object)
      {:ok, pm} = LatticeStripe.PaymentMethod.detach(client, pm.id)

  ## Security and Inspect

  The `Inspect` implementation hides all sensitive billing and card details.
  Only `id`, `object`, and `type` are shown. When `type` is `"card"`, the
  `card_brand` and `card_last4` are also shown (safe to log).

  ## Stripe API Reference

  See the [Stripe PaymentMethod API](https://docs.stripe.com/api/payment_methods) for the full
  object reference and available parameters.
  """

  alias LatticeStripe.{Client, Error, List, ObjectTypes, Request, Resource, Response}

  # Known top-level fields from the Stripe PaymentMethod object.
  # Used to build the struct and separate known from extra (unknown) fields.
  # String sigil (no `a`) matches Jason's default string-key output.
  # Includes all type-specific nested objects — they are nil unless type matches.
  @known_fields ~w[
    id object type created livemode customer metadata
    allow_redisplay billing_details radar_options
    card card_present us_bank_account sepa_debit au_becs_debit bacs_debit
    acss_debit nz_bank_account paypal alipay wechat_pay kakao_pay naver_pay
    samsung_pay link ideal fpx eps klarna affirm afterpay_clearpay
    alma billie boleto sofort cashapp p24 giropay bancontact oxxo
    konbini grabpay paynow promptpay zip revolut_pay swish twint
    mobilepay multibanco customer_balance interac_present
  ]

  # credo:disable-for-next-line Credo.Check.Warning.StructFieldAmount
  defstruct [
    :id,
    :type,
    :created,
    :livemode,
    :customer,
    :metadata,
    :allow_redisplay,
    :billing_details,
    :radar_options,
    :card,
    :card_present,
    :us_bank_account,
    :sepa_debit,
    :au_becs_debit,
    :bacs_debit,
    :acss_debit,
    :nz_bank_account,
    :paypal,
    :alipay,
    :wechat_pay,
    :kakao_pay,
    :naver_pay,
    :samsung_pay,
    :link,
    :ideal,
    :fpx,
    :eps,
    :klarna,
    :affirm,
    :afterpay_clearpay,
    :alma,
    :billie,
    :boleto,
    :sofort,
    :cashapp,
    :p24,
    :giropay,
    :bancontact,
    :oxxo,
    :konbini,
    :grabpay,
    :paynow,
    :promptpay,
    :zip,
    :revolut_pay,
    :swish,
    :twint,
    :mobilepay,
    :multibanco,
    :customer_balance,
    :interac_present,
    object: "payment_method",
    extra: %{}
  ]

  @typedoc """
  A Stripe PaymentMethod object.

  See the [Stripe PaymentMethod API](https://docs.stripe.com/api/payment_methods/object) for field definitions.
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          type: String.t() | nil,
          created: integer() | nil,
          livemode: boolean() | nil,
          customer: LatticeStripe.Customer.t() | String.t() | nil,
          metadata: map() | nil,
          allow_redisplay: String.t() | nil,
          billing_details: map() | nil,
          radar_options: map() | nil,
          card: map() | nil,
          card_present: map() | nil,
          us_bank_account: map() | nil,
          sepa_debit: map() | nil,
          au_becs_debit: map() | nil,
          bacs_debit: map() | nil,
          acss_debit: map() | nil,
          nz_bank_account: map() | nil,
          paypal: map() | nil,
          alipay: map() | nil,
          wechat_pay: map() | nil,
          kakao_pay: map() | nil,
          naver_pay: map() | nil,
          samsung_pay: map() | nil,
          link: map() | nil,
          ideal: map() | nil,
          fpx: map() | nil,
          eps: map() | nil,
          klarna: map() | nil,
          affirm: map() | nil,
          afterpay_clearpay: map() | nil,
          alma: map() | nil,
          billie: map() | nil,
          boleto: map() | nil,
          sofort: map() | nil,
          cashapp: map() | nil,
          p24: map() | nil,
          giropay: map() | nil,
          bancontact: map() | nil,
          oxxo: map() | nil,
          konbini: map() | nil,
          grabpay: map() | nil,
          paynow: map() | nil,
          promptpay: map() | nil,
          zip: map() | nil,
          revolut_pay: map() | nil,
          swish: map() | nil,
          twint: map() | nil,
          mobilepay: map() | nil,
          multibanco: map() | nil,
          customer_balance: map() | nil,
          interac_present: map() | nil,
          extra: map()
        }

  # ---------------------------------------------------------------------------
  # Public API: CRUD operations
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new PaymentMethod.

  Sends `POST /v1/payment_methods` with the given params and returns
  `{:ok, %PaymentMethod{}}`. This does not attach the PaymentMethod to a
  customer — use `attach/4` after creating.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Map of PaymentMethod attributes (e.g., `%{"type" => "card", "card" => %{"token" => "tok_visa"}}`)
  - `opts` - Per-request overrides (e.g., `[idempotency_key: "..."]`)

  ## Returns

  - `{:ok, %PaymentMethod{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, pm} = LatticeStripe.PaymentMethod.create(client, %{
        "type" => "card",
        "card" => %{"token" => "tok_visa"}
      })
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: "/v1/payment_methods", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Retrieves a PaymentMethod by ID.

  Sends `GET /v1/payment_methods/:id` and returns `{:ok, %PaymentMethod{}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The PaymentMethod ID string (e.g., `"pm_123"`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %PaymentMethod{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/payment_methods/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Updates a PaymentMethod by ID.

  Sends `POST /v1/payment_methods/:id` with the given params and returns
  `{:ok, %PaymentMethod{}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The PaymentMethod ID string
  - `params` - Map of fields to update (e.g., `%{"billing_details" => %{"name" => "John"}}`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %PaymentMethod{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/payment_methods/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Lists PaymentMethods for a customer.

  Sends `GET /v1/payment_methods` and returns
  `{:ok, %Response{data: %List{}}}` with typed `%PaymentMethod{}` items.

  **Requires `"customer"` in params.** Stripe only supports customer-scoped
  listing. This function raises `ArgumentError` before making any network call
  if `"customer"` is missing from params.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - Filter params — MUST include `%{"customer" => "cus_..."}`.
    Optional: `"type"`, `"limit"`, `"starting_after"`, `"ending_before"`.
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %Response{data: %List{data: [%PaymentMethod{}, ...]}}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, resp} = LatticeStripe.PaymentMethod.list(client, %{
        "customer" => "cus_123",
        "type" => "card"
      })
      payment_methods = resp.data.data
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params, opts \\ []) do
    Resource.require_param!(
      params,
      "customer",
      ~s|PaymentMethod.list/3 requires a "customer" key in params. | <>
        ~s|Stripe requires customer-scoped listing. | <>
        ~s|Example: PaymentMethod.list(client, %{"customer" => "cus_123"})|
    )

    %Request{method: :get, path: "/v1/payment_methods", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Attaches a PaymentMethod to a customer.

  Sends `POST /v1/payment_methods/:id/attach` with params containing the
  customer ID and returns `{:ok, %PaymentMethod{customer: "cus_..."}}`.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The PaymentMethod ID string
  - `params` - MUST include `%{"customer" => "cus_..."}` to specify which customer
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %PaymentMethod{customer: "cus_..."}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, pm} = LatticeStripe.PaymentMethod.attach(client, "pm_123", %{
        "customer" => "cus_123"
      })
  """
  @spec attach(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def attach(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    %Request{
      method: :post,
      path: "/v1/payment_methods/#{id}/attach",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Detaches a PaymentMethod from a customer.

  Sends `POST /v1/payment_methods/:id/detach` and returns
  `{:ok, %PaymentMethod{customer: nil}}`. The PaymentMethod object continues
  to exist in Stripe but is no longer associated with any customer.

  Note: PaymentMethods cannot be deleted — use `detach/4` to disassociate
  a PaymentMethod from a customer.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `id` - The PaymentMethod ID string
  - `params` - Optional params (typically `%{}`)
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %PaymentMethod{customer: nil}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure

  ## Example

      {:ok, pm} = LatticeStripe.PaymentMethod.detach(client, "pm_123")
      nil = pm.customer
  """
  @spec detach(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def detach(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    %Request{
      method: :post,
      path: "/v1/payment_methods/#{id}/detach",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Returns a lazy stream of all PaymentMethods for a customer (auto-pagination).

  Emits individual `%PaymentMethod{}` structs, fetching additional pages as needed.
  Raises `LatticeStripe.Error` if any page fetch fails.

  **Requires `"customer"` in params.** Raises `ArgumentError` before any network
  call if `"customer"` is missing.

  ## Parameters

  - `client` - A `%LatticeStripe.Client{}` struct
  - `params` - MUST include `%{"customer" => "cus_..."}`. Optional: `"type"`, `"limit"`.
  - `opts` - Per-request overrides

  ## Returns

  An `Enumerable.t()` of `%PaymentMethod{}` structs.

  ## Example

      client
      |> LatticeStripe.PaymentMethod.stream!(%{"customer" => "cus_123"})
      |> Stream.take(100)
      |> Enum.to_list()
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params, opts \\ []) do
    Resource.require_param!(
      params,
      "customer",
      ~s|PaymentMethod.list/3 requires a "customer" key in params. | <>
        ~s|Stripe requires customer-scoped listing. | <>
        ~s|Example: PaymentMethod.list(client, %{"customer" => "cus_123"})|
    )

    req = %Request{method: :get, path: "/v1/payment_methods", params: params, opts: opts}
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
  Like `list/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params, opts \\ []) do
    list(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `attach/4` but raises `LatticeStripe.Error` on failure.
  """
  @spec attach!(Client.t(), String.t(), map(), keyword()) :: t()
  def attach!(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    attach(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Like `detach/4` but raises `LatticeStripe.Error` on failure.
  """
  @spec detach!(Client.t(), String.t(), map(), keyword()) :: t()
  def detach!(%Client{} = client, id, params \\ %{}, opts \\ []) when is_binary(id) do
    detach(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  # ---------------------------------------------------------------------------
  # Public: from_map/1
  # ---------------------------------------------------------------------------

  @doc """
  Converts a decoded Stripe API map to a `%PaymentMethod{}` struct.

  Maps all known Stripe PaymentMethod fields. Any unrecognized fields are
  collected into the `extra` map so no data is silently lost.

  Type-specific nested objects (e.g., `card`, `us_bank_account`) are set to
  `nil` unless the map contains them.

  ## Example

      pm = LatticeStripe.PaymentMethod.from_map(%{
        "id" => "pm_123",
        "type" => "card",
        "card" => %{"brand" => "visa", "last4" => "4242"}
      })
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "payment_method",
      type: map["type"],
      created: map["created"],
      livemode: map["livemode"],
      customer:
        (if is_map(map["customer"]),
           do: ObjectTypes.maybe_deserialize(map["customer"]),
           else: map["customer"]),
      metadata: map["metadata"],
      allow_redisplay: map["allow_redisplay"],
      billing_details: map["billing_details"],
      radar_options: map["radar_options"],
      card: map["card"],
      card_present: map["card_present"],
      us_bank_account: map["us_bank_account"],
      sepa_debit: map["sepa_debit"],
      au_becs_debit: map["au_becs_debit"],
      bacs_debit: map["bacs_debit"],
      acss_debit: map["acss_debit"],
      nz_bank_account: map["nz_bank_account"],
      paypal: map["paypal"],
      alipay: map["alipay"],
      wechat_pay: map["wechat_pay"],
      kakao_pay: map["kakao_pay"],
      naver_pay: map["naver_pay"],
      samsung_pay: map["samsung_pay"],
      link: map["link"],
      ideal: map["ideal"],
      fpx: map["fpx"],
      eps: map["eps"],
      klarna: map["klarna"],
      affirm: map["affirm"],
      afterpay_clearpay: map["afterpay_clearpay"],
      alma: map["alma"],
      billie: map["billie"],
      boleto: map["boleto"],
      sofort: map["sofort"],
      cashapp: map["cashapp"],
      p24: map["p24"],
      giropay: map["giropay"],
      bancontact: map["bancontact"],
      oxxo: map["oxxo"],
      konbini: map["konbini"],
      grabpay: map["grabpay"],
      paynow: map["paynow"],
      promptpay: map["promptpay"],
      zip: map["zip"],
      revolut_pay: map["revolut_pay"],
      swish: map["swish"],
      twint: map["twint"],
      mobilepay: map["mobilepay"],
      multibanco: map["multibanco"],
      customer_balance: map["customer_balance"],
      interac_present: map["interac_present"],
      extra: Map.drop(map, @known_fields)
    }
  end
end

defimpl Inspect, for: LatticeStripe.PaymentMethod do
  import Inspect.Algebra

  def inspect(pm, opts) do
    base_fields = [
      id: pm.id,
      object: pm.object,
      type: pm.type
    ]

    card_fields =
      if pm.type == "card" && is_map(pm.card) do
        [card_brand: pm.card["brand"], card_last4: pm.card["last4"]]
      else
        []
      end

    fields = base_fields ++ card_fields

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.PaymentMethod<" | pairs] ++ [">"])
  end
end
