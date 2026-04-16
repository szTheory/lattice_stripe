defmodule LatticeStripe.BillingPortal.Configuration do
  @moduledoc """
  Manages Stripe customer portal configurations controlling branding, features,
  and business info.

  A portal configuration defines the appearance and available actions for your
  customers' self-service billing portal (the page returned by
  `LatticeStripe.BillingPortal.Session.create/3`).

  ## Lifecycle

  Configurations cannot be deleted — only deactivated via
  `update(client, id, %{"active" => false})`. Once deactivated, the
  configuration can be re-activated by setting `active` back to `true`.

  A configuration marked `is_default: true` is Stripe's account default and
  **cannot be deactivated**. Attempting to deactivate the default configuration
  returns a Stripe error; no client-side guard is applied — let Stripe enforce
  this invariant.

  ## Usage

      client = LatticeStripe.Client.new!(api_key: "sk_live_...", finch: MyApp.Finch)

      # Create a custom portal configuration
      {:ok, config} = LatticeStripe.BillingPortal.Configuration.create(client, %{
        "business_profile" => %{
          "headline" => "Manage your subscription",
          "privacy_policy_url" => "https://example.com/privacy",
          "terms_of_service_url" => "https://example.com/terms"
        },
        "features" => %{
          "invoice_history" => %{"enabled" => true}
        }
      })

      # Retrieve a configuration
      {:ok, config} = LatticeStripe.BillingPortal.Configuration.retrieve(client, "bpc_123")

      # Deactivate a configuration (cannot delete)
      {:ok, _config} = LatticeStripe.BillingPortal.Configuration.update(
        client, config.id, %{"active" => false}
      )

      # List all configurations
      {:ok, resp} = LatticeStripe.BillingPortal.Configuration.list(client)
      configs = resp.data.data  # [%Configuration{}, ...]

      # Stream all configurations lazily (auto-pagination)
      client
      |> LatticeStripe.BillingPortal.Configuration.stream!()
      |> Enum.each(&process_config/1)

  ## Stripe API Reference

  See the [Stripe Portal Configuration API](https://docs.stripe.com/api/customer_portal/configuration)
  for the full object reference and available parameters.
  """

  alias LatticeStripe.BillingPortal.Configuration.Features
  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}

  @known_fields ~w[
    id object active application business_profile created default_return_url
    features is_default livemode login_page metadata name updated
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t() | nil,
          active: boolean() | nil,
          application: String.t() | nil,
          business_profile: map() | nil,
          created: integer() | nil,
          default_return_url: String.t() | nil,
          features: Features.t() | nil,
          is_default: boolean() | nil,
          livemode: boolean() | nil,
          login_page: map() | nil,
          metadata: map() | nil,
          name: String.t() | nil,
          updated: integer() | nil,
          extra: map()
        }

  defstruct [
    :id,
    :object,
    :active,
    :application,
    :business_profile,
    :created,
    :default_return_url,
    :features,
    :is_default,
    :livemode,
    :login_page,
    :metadata,
    :name,
    :updated,
    extra: %{}
  ]

  # ---------------------------------------------------------------------------
  # CREATE
  # ---------------------------------------------------------------------------

  @doc """
  Create a customer portal configuration.

  Pass `params` as a string-keyed map matching Stripe's wire format. Returns
  `{:ok, %Configuration{}}` on success or `{:error, %LatticeStripe.Error{}}` on
  failure.
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: "/v1/billing_portal/configurations", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Bang variant of `create/3`. Raises `LatticeStripe.Error` on failure."
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(client, params \\ %{}, opts \\ []),
    do: client |> create(params, opts) |> Resource.unwrap_bang!()

  # ---------------------------------------------------------------------------
  # RETRIEVE
  # ---------------------------------------------------------------------------

  @doc """
  Retrieve a customer portal configuration by ID.
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{
      method: :get,
      path: "/v1/billing_portal/configurations/#{id}",
      params: %{},
      opts: opts
    }
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
  Update a customer portal configuration.

  To deactivate a configuration: `update(client, id, %{"active" => false})`.
  Note: configurations with `is_default: true` cannot be deactivated — Stripe
  returns an error in that case.
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    %Request{
      method: :post,
      path: "/v1/billing_portal/configurations/#{id}",
      params: params,
      opts: opts
    }
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
  List customer portal configurations. Supports cursor-based pagination via
  `starting_after` and `ending_before`, and filtering via `active` and
  `is_default`.
  """
  @spec list(Client.t(), map(), keyword()) ::
          {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{
      method: :get,
      path: "/v1/billing_portal/configurations",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc "Bang variant of `list/3`. Raises `LatticeStripe.Error` on failure."
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(client, params \\ %{}, opts \\ []),
    do: client |> list(params, opts) |> Resource.unwrap_bang!()

  @doc """
  Returns a lazy stream of all customer portal configurations (auto-pagination).

  Emits individual `%Configuration{}` structs, fetching additional pages as
  needed. Raises `LatticeStripe.Error` if any page fetch fails.
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{
      method: :get,
      path: "/v1/billing_portal/configurations",
      params: params,
      opts: opts
    }

    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # DECODE
  # ---------------------------------------------------------------------------

  @doc """
  Decode a Stripe-shaped string-keyed map into a `%Configuration{}`.

  The `features` field is dispatched to `Features.from_map/1` for typed
  sub-struct decoding. The `business_profile` and `login_page` fields are kept
  as raw maps (Level 1 nesting per D-01 — single-boolean or shallow objects
  with no sub-type value). Unknown top-level keys land in `:extra`.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"],
      active: known["active"],
      application: known["application"],
      business_profile: known["business_profile"],
      created: known["created"],
      default_return_url: known["default_return_url"],
      features: Features.from_map(known["features"]),
      is_default: known["is_default"],
      livemode: known["livemode"],
      login_page: known["login_page"],
      metadata: known["metadata"],
      name: known["name"],
      updated: known["updated"],
      extra: extra
    }
  end
end
