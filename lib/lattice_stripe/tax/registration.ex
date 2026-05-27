defmodule LatticeStripe.Tax.Registration do
  @moduledoc """
  Stripe Tax Registration objects for declaring where you collect tax.

  ## Does not register with tax authorities

  Creating a registration via `create/3` **does not register you with tax
  authorities**. It tells Stripe which jurisdictions you are configured to
  collect tax in so calculations and reporting can run. Legal registration
  with government agencies remains your responsibility.

  ## Relationship to other tax surfaces

  Registrations work alongside `LatticeStripe.Tax.Settings` (account defaults)
  and `LatticeStripe.Tax.Calculation` (ephemeral tax amounts). This module is
  **not** `LatticeStripe.Invoice.AutomaticTax`. Tax filing, returns, and
  threshold monitoring are **out of SDK scope**.

  ## `country_options`

  Registration params require a nested `country_options` map keyed by
  lowercase ISO country codes that match the top-level `"country"` field.
  For US state sales tax:

      %{
        "country" => "US",
        "country_options" => %{
          "us" => %{"type" => "state_sales_tax", "state" => "CA"}
        }
      }

  For EU OSS:

      %{
        "country" => "DE",
        "country_options" => %{
          "de" => %{"type" => "oss_union", "oss_union" => "standard"}
        }
      }

  Do **not** pass `type` at the top level of the create params — it belongs
  inside the country-specific nested map.

  ## Usage

      {:ok, registration} =
        LatticeStripe.Tax.Registration.create(client, %{
          "country" => "US",
          "country_options" => %{
            "us" => %{"type" => "state_sales_tax", "state" => "CA"}
          }
        })

      {:ok, response} = LatticeStripe.Tax.Registration.list(client)

  ## Pagination

  `list/3` returns a single page of results as `%LatticeStripe.List{}`.
  `%LatticeStripe.List{}` is not `Enumerable`. For many jurisdictions, use
  `stream!/3`, which auto-paginates and yields `%Registration{}` structs.

  See [Standalone Tax API](guides/tax.md) for the canonical calculate → record → reverse workflow.

  See [Stripe Tax Registrations](https://docs.stripe.com/api/tax/registrations).
  """

  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}

  @known_fields ~w[id object active_from country country_options created expires_at livemode status]

  defstruct [
    :id,
    :active_from,
    :country,
    :country_options,
    :created,
    :expires_at,
    :livemode,
    :status,
    object: "tax.registration",
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          active_from: integer() | nil,
          country: String.t() | nil,
          country_options: map() | nil,
          created: integer() | nil,
          expires_at: integer() | nil,
          livemode: boolean() | nil,
          status: atom() | String.t() | nil,
          extra: map()
        }

  @doc """
  Creates a Tax Registration.

  Sends `POST /v1/tax/registrations` with the raw params map.
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params, opts \\ []) when is_map(params) do
    %Request{method: :post, path: "/v1/tax/registrations", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `create/3` but raises on failure."
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(%Client{} = client, params, opts \\ []) when is_map(params) do
    create(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Retrieves a Tax Registration by ID.
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/tax/registrations/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `retrieve/3` but raises on failure."
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    retrieve(client, id, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Updates a Tax Registration by ID.
  """
  @spec update(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) and is_map(params) do
    %Request{method: :post, path: "/v1/tax/registrations/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `update/4` but raises on failure."
  @spec update!(Client.t(), String.t(), map(), keyword()) :: t()
  def update!(%Client{} = client, id, params, opts \\ [])
      when is_binary(id) and is_map(params) do
    update(client, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Lists Tax Registrations with optional filters.
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/tax/registrations", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc "Like `list/3` but raises on failure."
  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) do
    list(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Returns a lazy stream of Tax Registrations matching the given filters.
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/tax/registrations", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  @doc false
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "tax.registration",
      active_from: known["active_from"],
      country: known["country"],
      country_options: known["country_options"],
      created: known["created"],
      expires_at: known["expires_at"],
      livemode: known["livemode"],
      status: atomize_status(known["status"]),
      extra: extra
    }
  end

  defp atomize_status("active"), do: :active
  defp atomize_status("expired"), do: :expired
  defp atomize_status("scheduled"), do: :scheduled
  defp atomize_status(nil), do: nil
  defp atomize_status(other), do: other
end
