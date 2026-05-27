defmodule LatticeStripe.TaxId do
  @moduledoc """
  Operations on Stripe Tax ID objects.

  Tax IDs store customer tax identification numbers (VAT, EIN, etc.) for tax
  reporting and calculation. Stripe exposes two URL families for the same
  resource shape — this module routes by arity so adopters call one module
  for both paths.

  ## Dual-path URL table

  | Operation | Top-level (`/v1/tax_ids`) | Customer-nested (`/v1/customers/:id/tax_ids`) |
  |-----------|---------------------------|-----------------------------------------------|
  | Create    | `create/3`                | `create/4` — `customer_id` is 2nd arg after `client` |
  | Retrieve  | `retrieve/3`              | `retrieve/4` |
  | List      | `list/3`                  | `list/4` |
  | Delete    | `delete/3`                | `delete/4` |
  | Stream    | `stream!/3`               | `stream!/4` |

  Top-level paths apply when the tax ID is not scoped to a single customer URL
  prefix. Customer-nested paths apply when managing tax IDs on a known
  `cus_...` record. Nested `create/4` omits `"customer"` from the request body —
  Stripe infers the customer from the URL path.

  ## Usage

      # Top-level create
      {:ok, tax_id} =
        LatticeStripe.TaxId.create(client, %{"type" => "eu_vat", "value" => "DE123456789"})

      # Customer-nested create
      {:ok, tax_id} =
        LatticeStripe.TaxId.create(client, "cus_123", %{"type" => "eu_vat", "value" => "DE123456789"})

  ## Not `LatticeStripe.Invoice.AutomaticTax`

  Tax IDs on customers are separate from automatic tax on invoices. Use
  `LatticeStripe.Invoice.AutomaticTax` when Stripe calculates tax on an invoice
  from the customer's address and tax settings — not this module.

  See [Standalone Tax API](guides/tax.md) for the canonical calculate → record → reverse workflow.

  ## Operations not supported by the Stripe API

  - **update** — Tax IDs are immutable once created (Coupon precedent).
  - **search** — No `/v1/tax_ids/search` endpoint exists.

  See the [Stripe Tax ID API](https://docs.stripe.com/api/tax_ids).
  """

  alias LatticeStripe.{
    Client,
    Error,
    List,
    ObjectTypes,
    Request,
    Resource,
    Response
  }

  alias LatticeStripe.TaxId.{Owner, Verification}

  @known_fields ~w[id object country created customer customer_account deleted livemode owner type value verification]

  defstruct [
    :id,
    :country,
    :created,
    :customer,
    :customer_account,
    :livemode,
    :owner,
    :type,
    :value,
    :verification,
    object: "tax_id",
    deleted: false,
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          country: String.t() | nil,
          created: integer() | nil,
          customer: struct() | String.t() | nil,
          customer_account: String.t() | nil,
          livemode: boolean() | nil,
          owner: Owner.t() | nil,
          type: String.t() | nil,
          value: String.t() | nil,
          verification: Verification.t() | nil,
          deleted: boolean(),
          extra: map()
        }

  # create/3 and create/4 — guards disambiguate top-level vs customer-nested --------

  @doc """
  Creates a Tax ID.

  - `create(client, params, opts)` — POST `/v1/tax_ids`
  - `create(client, customer_id, params, opts)` — POST `/v1/customers/:customer_id/tax_ids`
    (omits `"customer"` from the request body)
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  @spec create(Client.t(), String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, customer_id, params, opts)
      when is_binary(customer_id) and is_map(params) and is_list(opts) do
    params = Map.drop(params, ["customer"])

    %Request{
      method: :post,
      path: "/v1/customers/#{customer_id}/tax_ids",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  def create(%Client{} = client, customer_id, params)
      when is_binary(customer_id) and is_map(params) do
    create(client, customer_id, params, [])
  end

  def create(%Client{} = client, params, opts) when is_map(params) and is_list(opts) do
    %Request{method: :post, path: "/v1/tax_ids", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  def create(%Client{} = client, params) when is_map(params) do
    create(client, params, [])
  end

  # retrieve — nested 3/4-arg before top-level 2/3-arg ------------------------------

  @doc """
  Retrieves a Tax ID.

  - `retrieve(client, id, opts)` — GET `/v1/tax_ids/:id`
  - `retrieve(client, customer_id, id, opts)` — GET `/v1/customers/:customer_id/tax_ids/:id`
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  @spec retrieve(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, customer_id, id, opts)
      when is_binary(customer_id) and is_binary(id) and is_list(opts) do
    %Request{
      method: :get,
      path: "/v1/customers/#{customer_id}/tax_ids/#{id}",
      params: %{},
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  def retrieve(%Client{} = client, customer_id, id)
      when is_binary(customer_id) and is_binary(id) do
    retrieve(client, customer_id, id, [])
  end

  def retrieve(%Client{} = client, id, opts) when is_binary(id) and is_list(opts) do
    %Request{method: :get, path: "/v1/tax_ids/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  def retrieve(%Client{} = client, id) when is_binary(id) do
    retrieve(client, id, [])
  end

  # list ----------------------------------------------------------------------------

  @doc """
  Lists Tax IDs.

  - `list(client, params, opts)` — GET `/v1/tax_ids`
  - `list(client, customer_id, params, opts)` — GET `/v1/customers/:customer_id/tax_ids`
  """
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  @spec list(Client.t(), String.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, customer_id, params, opts)
      when is_binary(customer_id) and is_map(params) and is_list(opts) do
    %Request{
      method: :get,
      path: "/v1/customers/#{customer_id}/tax_ids",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  def list(%Client{} = client, customer_id, params)
      when is_binary(customer_id) and is_map(params) do
    list(client, customer_id, params, [])
  end

  def list(%Client{} = client, params, opts) when is_map(params) and is_list(opts) do
    %Request{method: :get, path: "/v1/tax_ids", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  def list(%Client{} = client, params) when is_map(params) do
    list(client, params, [])
  end

  # delete ----------------------------------------------------------------------------

  @doc """
  Deletes a Tax ID.

  - `delete(client, id, opts)` — DELETE `/v1/tax_ids/:id`
  - `delete(client, customer_id, id, opts)` — DELETE `/v1/customers/:customer_id/tax_ids/:id`
  """
  @spec delete(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  @spec delete(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def delete(%Client{} = client, customer_id, id, opts)
      when is_binary(customer_id) and is_binary(id) and is_list(opts) do
    %Request{
      method: :delete,
      path: "/v1/customers/#{customer_id}/tax_ids/#{id}",
      params: %{},
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  def delete(%Client{} = client, customer_id, id)
      when is_binary(customer_id) and is_binary(id) do
    delete(client, customer_id, id, [])
  end

  def delete(%Client{} = client, id, opts) when is_binary(id) and is_list(opts) do
    %Request{method: :delete, path: "/v1/tax_ids/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  def delete(%Client{} = client, id) when is_binary(id) do
    delete(client, id, [])
  end

  # stream! ---------------------------------------------------------------------------

  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  @spec stream!(Client.t(), String.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, customer_id, params, opts)
      when is_binary(customer_id) and is_map(params) and is_list(opts) do
    req = %Request{
      method: :get,
      path: "/v1/customers/#{customer_id}/tax_ids",
      params: params,
      opts: opts
    }

    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  def stream!(%Client{} = client, customer_id, params)
      when is_binary(customer_id) and is_map(params) do
    stream!(client, customer_id, params, [])
  end

  def stream!(%Client{} = client, params, opts) when is_map(params) and is_list(opts) do
    req = %Request{method: :get, path: "/v1/tax_ids", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  def stream!(%Client{} = client, params \\ %{}) when is_map(params) do
    stream!(client, params, [])
  end

  # Bang variants (no default args — guards disambiguate arity-3) -------------------

  def create!(%Client{} = c, cid, p, o)
      when is_binary(cid) and is_map(p) and is_list(o),
      do: create(c, cid, p, o) |> Resource.unwrap_bang!()

  def create!(%Client{} = c, cid, p) when is_binary(cid) and is_map(p),
    do: create(c, cid, p, []) |> Resource.unwrap_bang!()

  def create!(%Client{} = c, p, o) when is_map(p) and is_list(o),
    do: create(c, p, o) |> Resource.unwrap_bang!()

  def create!(%Client{} = c, p) when is_map(p), do: create!(c, p, [])

  def retrieve!(%Client{} = c, cid, id, o)
      when is_binary(cid) and is_binary(id) and is_list(o),
      do: retrieve(c, cid, id, o) |> Resource.unwrap_bang!()

  def retrieve!(%Client{} = c, cid, id) when is_binary(cid) and is_binary(id),
    do: retrieve(c, cid, id, []) |> Resource.unwrap_bang!()

  def retrieve!(%Client{} = c, id, o) when is_binary(id) and is_list(o),
    do: retrieve(c, id, o) |> Resource.unwrap_bang!()

  def retrieve!(%Client{} = c, id) when is_binary(id), do: retrieve!(c, id, [])

  def delete!(%Client{} = c, cid, id, o)
      when is_binary(cid) and is_binary(id) and is_list(o),
      do: delete(c, cid, id, o) |> Resource.unwrap_bang!()

  def delete!(%Client{} = c, cid, id) when is_binary(cid) and is_binary(id),
    do: delete(c, cid, id, []) |> Resource.unwrap_bang!()

  def delete!(%Client{} = c, id, o) when is_binary(id) and is_list(o),
    do: delete(c, id, o) |> Resource.unwrap_bang!()

  def delete!(%Client{} = c, id) when is_binary(id), do: delete!(c, id, [])

  def list!(%Client{} = c, cid, p, o) when is_binary(cid) and is_map(p) and is_list(o),
    do: list(c, cid, p, o) |> Resource.unwrap_bang!()

  def list!(%Client{} = c, cid, p) when is_binary(cid) and is_map(p),
    do: list(c, cid, p, []) |> Resource.unwrap_bang!()

  def list!(%Client{} = c, p, o) when is_map(p) and is_list(o),
    do: list(c, p, o) |> Resource.unwrap_bang!()

  def list!(%Client{} = c, p) when is_map(p), do: list!(c, p, [])

  # NOTE: NO update/* and NO search/* — Stripe TaxId is CRUDL minus update.

  @doc false
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(%{} = map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "tax_id",
      country: known["country"],
      created: known["created"],
      customer: parse_expandable(known["customer"]),
      customer_account: known["customer_account"],
      livemode: known["livemode"],
      owner: Owner.from_map(known["owner"]),
      type: known["type"],
      value: known["value"],
      verification: Verification.from_map(known["verification"]),
      deleted: known["deleted"] || false,
      extra: extra
    }
  end

  defp parse_expandable(value) when is_map(value), do: ObjectTypes.maybe_deserialize(value)
  defp parse_expandable(value), do: value
end

defimpl Inspect, for: LatticeStripe.TaxId do
  import Inspect.Algebra

  @redacted [:value]

  def inspect(struct, opts) do
    redacted =
      Enum.reduce(@redacted, struct, fn field, acc ->
        case Map.get(acc, field) do
          nil -> acc
          _ -> Map.put(acc, field, "[REDACTED]")
        end
      end)

    pairs =
      Map.from_struct(redacted)
      |> Enum.reject(fn {k, v} -> k == :extra and v == %{} end)
      |> Enum.map(fn {k, v} -> concat([Atom.to_string(k), ": ", to_doc(v, opts)]) end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.TaxId<" | pairs] ++ [">"])
  end
end
