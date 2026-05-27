defmodule LatticeStripe.Tax.Settings do
  @moduledoc """
  Account-level Stripe Tax configuration singleton.

  Tax Settings is a **singleton** — there is no resource ID. The only operations
  are `retrieve/2` and `update/3` against fixed paths on `/v1/tax/settings`.

  ## Defaults and Calculation

  The `defaults` field holds account-wide fallbacks such as `tax_code` and
  `tax_behavior`. When line items in `LatticeStripe.Tax.Calculation.create/3`
  omit those fields, Stripe applies the settings defaults.

  ## Relationship to other tax surfaces

  This module is **not** `LatticeStripe.Invoice.AutomaticTax`. Automatic tax on
  Invoices, Subscriptions, and Quotes is configured via nested `automatic_tax`
  settings on those Billing resources. Use Tax Settings for account-wide
  Stripe Tax configuration that applies to the Calculations API and
  registrations.

  Pass `stripe_account: "acct_..."` in `opts` on `retrieve/2` and `update/3`
  for connected accounts (same semantics as `LatticeStripe.Balance.retrieve/2`).

  ## Usage

      {:ok, settings} = LatticeStripe.Tax.Settings.retrieve(client)

      {:ok, settings} =
        LatticeStripe.Tax.Settings.update(client, %{
          "defaults" => %{
            "tax_behavior" => "exclusive",
            "tax_code" => "txcd_99999999"
          }
        })

  Once a settings field is set, Stripe does not support unsetting it via the
  API — you can only change values. Check `status` and `status_details` for
  whether Tax is active in your jurisdictions.

  See [Standalone Tax API](guides/tax.md) for the canonical calculate → record → reverse workflow.

  See [Stripe Tax Settings](https://docs.stripe.com/api/tax/settings).
  """

  alias LatticeStripe.Tax.Settings.{Defaults, HeadOffice, StatusDetails}
  alias LatticeStripe.{Client, Error, Request, Resource}

  @known_fields ~w[defaults head_office livemode object status status_details]

  defstruct [
    :defaults,
    :head_office,
    :livemode,
    :status,
    :status_details,
    object: "tax.settings",
    extra: %{}
  ]

  @type t :: %__MODULE__{
          object: String.t(),
          defaults: Defaults.t() | nil,
          head_office: HeadOffice.t() | nil,
          livemode: boolean() | nil,
          status: atom() | String.t() | nil,
          status_details: StatusDetails.t() | nil,
          extra: map()
        }

  @doc """
  Retrieves the Stripe Tax Settings singleton.

  Sends `GET /v1/tax/settings` and returns `{:ok, %Settings{}}`.

  Pass `stripe_account: "acct_..."` in `opts` for connected accounts.
  """
  @spec retrieve(Client.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, opts \\ []) do
    %Request{method: :get, path: "/v1/tax/settings", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `retrieve/2` but raises `LatticeStripe.Error` on failure."
  @spec retrieve!(Client.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, opts \\ []) do
    client |> retrieve(opts) |> Resource.unwrap_bang!()
  end

  @doc """
  Updates Stripe Tax Settings.

  Sends `POST /v1/tax/settings` with the raw params map.
  """
  @spec update(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(%Client{} = client, params, opts \\ []) when is_map(params) do
    %Request{method: :post, path: "/v1/tax/settings", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `update/3` but raises on failure."
  @spec update!(Client.t(), map(), keyword()) :: t()
  def update!(%Client{} = client, params, opts \\ []) when is_map(params) do
    update(client, params, opts) |> Resource.unwrap_bang!()
  end

  @doc false
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      object: known["object"] || "tax.settings",
      defaults: Defaults.from_map(known["defaults"]),
      head_office: HeadOffice.from_map(known["head_office"]),
      livemode: known["livemode"],
      status: atomize_status(known["status"]),
      status_details: StatusDetails.from_map(known["status_details"]),
      extra: extra
    }
  end

  defp atomize_status("active"), do: :active
  defp atomize_status("pending"), do: :pending
  defp atomize_status(nil), do: nil
  defp atomize_status(other), do: other
end
