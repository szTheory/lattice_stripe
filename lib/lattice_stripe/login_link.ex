defmodule LatticeStripe.LoginLink do
  @moduledoc """
  Operations on Stripe Express Login Links — single-use dashboard return URLs
  for Express connected accounts.

  A Login Link is a single-use URL that logs the owner of an Express Connect
  account into the Stripe Express dashboard. Use it to let a connected account
  owner return to their dashboard after initial onboarding.

  ## Usage

      {:ok, link} = LatticeStripe.LoginLink.create(client, "acct_connected_123")
      redirect_user_to(link.url)

  ## Signature deviation: `account_id` is the second positional argument

  Unlike the SDK-wide `create(client, params, opts)` shape, `LoginLink.create/4`
  takes the connected `account_id` as its second positional argument:

      @spec create(Client.t(), String.t(), map(), keyword()) ::
              {:ok, t()} | {:error, Error.t()}

  This deviation is intentional: the Stripe endpoint is
  `POST /v1/accounts/:account_id/login_links`, where the account ID is
  URL-path-scoped rather than a request body parameter. Every other Stripe SDK
  (stripe-node, stripe-python, stripe-go, stripity_stripe) places the account
  ID as a path argument for this endpoint. We match that convention here
  rather than hiding the path structure behind a nested params field.

  ## Express-only

  Login Links only work for connected accounts of `type: "express"`. Calling
  this on a Standard or Custom account returns a 400 surfaced as
  `{:error, %LatticeStripe.Error{type: :invalid_request_error}}`.

  ## Security: the returned URL is a short-lived bearer token

  Like `LatticeStripe.AccountLink`, the returned `url` is a bearer token.
  **Do not log, store, or include the URL in telemetry payloads.** Redirect
  the user immediately (Phase 17 T-17-02).

  ## Create-only

  Stripe does not expose retrieve, update, delete, or list endpoints for
  Login Links. This module provides `create/4` and `create!/4` only.

  ## Stripe API Reference

  See the [Stripe Login Link API](https://docs.stripe.com/api/account/login_link).
  """

  alias LatticeStripe.{Client, Error, Request, Resource}

  @known_fields ~w[object created url]

  defstruct [:created, :url, object: "login_link", extra: %{}]

  @typedoc "A Stripe Express Login Link."
  @type t :: %__MODULE__{
          object: String.t(),
          created: integer() | nil,
          url: String.t() | nil,
          extra: map()
        }

  @doc """
  Creates a new Login Link for the given Express connected account.

  Sends `POST /v1/accounts/:account_id/login_links`. No body parameters are
  required — pass an empty map (the default) unless future Stripe API
  additions require fields.

  ## Parameters

  - `client` - `%LatticeStripe.Client{}`
  - `account_id` - Express connected account ID (`"acct_..."`)
  - `params` - Optional map of body parameters (default `%{}`)
  - `opts` - Per-request overrides (e.g., `[idempotency_key: "..."]`)
  """
  @spec create(Client.t(), String.t(), map(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, account_id, params \\ %{}, opts \\ [])
      when is_binary(account_id) do
    %Request{
      method: :post,
      path: "/v1/accounts/#{account_id}/login_links",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Like `create/4` but raises on failure."
  @spec create!(Client.t(), String.t(), map(), keyword()) :: t()
  def create!(%Client{} = client, account_id, params \\ %{}, opts \\ [])
      when is_binary(account_id) do
    client |> create(account_id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc false
  def from_map(nil), do: nil

  def from_map(%{} = map) do
    {known, extra} = Map.split(map, @known_fields)
    known_atoms = Map.new(known, fn {k, v} -> {String.to_existing_atom(k), v} end)
    struct(__MODULE__, Map.put(known_atoms, :extra, extra))
  end
end
