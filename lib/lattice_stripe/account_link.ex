defmodule LatticeStripe.AccountLink do
  @moduledoc """
  Operations on Stripe Connect Account Links — short-lived onboarding URLs.

  An Account Link is a single-use URL that hosts Stripe's own Connect
  onboarding or account-update flow. You send the user to this URL, they
  complete KYC / account information, and Stripe redirects them back to your
  `return_url` (or `refresh_url` if the link expires or errors).

  ## Usage

      {:ok, link} = LatticeStripe.AccountLink.create(client, %{
        "account" => "acct_connected_123",
        "type" => "account_onboarding",
        "refresh_url" => "https://example.com/connect/refresh",
        "return_url" => "https://example.com/connect/return"
      })

      redirect_user_to(link.url)

  ## Security: the returned URL is a short-lived bearer token

  The `url` field is a bearer token granting the holder access to the
  connected account's onboarding flow. It expires ~300 seconds after creation.
  **Do not log the URL, do not store it in a database, do not include it in
  error reports or telemetry payloads.** Redirect the user immediately and let
  the URL expire. If you need a fresh URL, create a new Account Link — they
  are cheap (Phase 17 T-17-02).

  ## Create-only

  Stripe does not expose retrieve, update, delete, or list endpoints for
  Account Links. This module provides `create/3` and `create!/3` only.

  ## D-04c decision: no positional `type` argument

  `create/3` follows the SDK-wide `create(client, params, opts)` shape. The
  `type` field (`"account_onboarding"` | `"account_update"`) goes inside
  `params`, not as a positional argument. This is Phase 17 D-04c: we rejected
  a 4-arity `create(client, type, params, opts)` variant because elevating one
  field of a multi-field create to a positional argument would break the
  SDK-wide shape for marginal typo protection on a 2-value enum.

  If the `"type"` key is missing from params, Stripe will return a 400 which
  surfaces as `{:error, %LatticeStripe.Error{type: :invalid_request_error}}`.
  We do NOT client-side validate this (Phase 15 D5 "no fake ergonomics" — let
  Stripe's own error flow through).

  ## Stripe API Reference

  See the [Stripe Account Links API](https://docs.stripe.com/api/account_links).
  """

  alias LatticeStripe.{Client, Error, Request, Resource}

  @known_fields ~w[object created expires_at url]

  defstruct [:created, :expires_at, :url, object: "account_link", extra: %{}]

  @typedoc "A Stripe Connect Account Link."
  @type t :: %__MODULE__{
          object: String.t(),
          created: integer() | nil,
          expires_at: integer() | nil,
          url: String.t() | nil,
          extra: map()
        }

  @doc """
  Creates a new Account Link.

  Sends `POST /v1/account_links`. Required params:

  - `"account"` — Connected account ID (`"acct_..."`)
  - `"type"` — `"account_onboarding"` or `"account_update"`
  - `"refresh_url"` — URL Stripe redirects to if the link expires
  - `"return_url"` — URL Stripe redirects to on completion
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params, opts \\ []) when is_map(params) do
    %Request{method: :post, path: "/v1/account_links", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `create/3` but raises on failure."
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(%Client{} = client, params, opts \\ []) when is_map(params) do
    client |> create(params, opts) |> Resource.unwrap_bang!()
  end

  @doc false
  def from_map(nil), do: nil

  def from_map(%{} = map) do
    {known, extra} = Map.split(map, @known_fields)
    known_atoms = Map.new(known, fn {k, v} -> {String.to_existing_atom(k), v} end)
    struct(__MODULE__, Map.put(known_atoms, :extra, extra))
  end
end
