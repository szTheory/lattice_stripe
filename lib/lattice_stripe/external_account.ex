defmodule LatticeStripe.ExternalAccount do
  @moduledoc """
  Polymorphic dispatcher for external accounts on a Stripe Connect connected account.

  External accounts are either bank accounts (`%LatticeStripe.BankAccount{}`)
  or debit cards (`%LatticeStripe.Card{}`). All CRUD operations for the
  `/v1/accounts/:account/external_accounts` endpoint live on this module;
  responses are dispatched to the appropriate struct via `cast/1` based on
  the `object` discriminator.

  Unknown future object types fall back to
  `%LatticeStripe.ExternalAccount.Unknown{}` so user code never crashes on a
  new Stripe shape:

      case ea do
        %LatticeStripe.BankAccount{} -> ...
        %LatticeStripe.Card{} -> ...
        %LatticeStripe.ExternalAccount.Unknown{} -> ...
      end

  ## Usage

      client = LatticeStripe.Client.new!(api_key: "sk_live_...", finch: MyApp.Finch)

      # Attach a tokenized bank account to a connected account
      {:ok, ba} =
        LatticeStripe.ExternalAccount.create(client, "acct_1...", %{
          "external_account" => "btok_..."
        })

      # Retrieve a single external account
      {:ok, ea} = LatticeStripe.ExternalAccount.retrieve(client, "acct_1...", "ba_1...")

      # List all external accounts (mixed bank_account + card)
      {:ok, resp} = LatticeStripe.ExternalAccount.list(client, "acct_1...")
      Enum.each(resp.data.data, &handle_external_account/1)

      # Stream all external accounts lazily with auto-pagination
      client
      |> LatticeStripe.ExternalAccount.stream!("acct_1...")
      |> Enum.each(&handle_external_account/1)

      # Delete an external account
      {:ok, %{extra: %{"deleted" => true}}} =
        LatticeStripe.ExternalAccount.delete(client, "acct_1...", "ba_1...")

  ## Stripe API Reference

  - https://docs.stripe.com/api/external_account_bank_accounts
  - https://docs.stripe.com/api/external_account_cards
  """

  alias LatticeStripe.{BankAccount, Card, Client, Error, List, Request, Resource, Response}
  alias LatticeStripe.ExternalAccount.Unknown

  @typedoc """
  The sum-type returned by every operation in this module. Pattern-match on
  the concrete struct:

      case ea do
        %LatticeStripe.BankAccount{} -> ...
        %LatticeStripe.Card{} -> ...
        %LatticeStripe.ExternalAccount.Unknown{} -> ...
      end
  """
  @type ea :: BankAccount.t() | Card.t() | Unknown.t()

  # ---------------------------------------------------------------------------
  # cast/1 — polymorphic dispatch on the `object` discriminator
  # ---------------------------------------------------------------------------

  @doc """
  Dispatches a decoded Stripe external-account map to the correct struct.

  Returns a `%BankAccount{}`, `%Card{}`, or `%ExternalAccount.Unknown{}`
  depending on the `"object"` field in the payload. Returns `nil` if given
  `nil`. Never raises on novel object types — the `Unknown` fallback
  preserves the full raw payload in `:extra`.
  """
  @spec cast(map() | nil) :: ea() | nil
  def cast(nil), do: nil
  def cast(%{"object" => "bank_account"} = raw), do: BankAccount.cast(raw)
  def cast(%{"object" => "card"} = raw), do: Card.cast(raw)
  def cast(%{"object" => _other} = raw), do: Unknown.cast(raw)

  # ---------------------------------------------------------------------------
  # Public API: CRUDL
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new external account on a Connect connected account.

  Sends `POST /v1/accounts/:account/external_accounts` with the given params
  and returns `{:ok, sum_type}` — a `%BankAccount{}` or `%Card{}` depending
  on the token type used.

  ## Parameters

  - `client` - `%LatticeStripe.Client{}`
  - `account_id` - Connected account ID (e.g., `"acct_1..."`). Required, non-empty.
  - `params` - Creation params, typically `%{"external_account" => "btok_..." | "tok_..."}`
  - `opts` - Per-request overrides

  ## Returns

  - `{:ok, %LatticeStripe.BankAccount{} | %LatticeStripe.Card{}}` on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec create(Client.t(), String.t(), map(), keyword()) ::
          {:ok, ea()} | {:error, Error.t()}
  def create(%Client{} = client, account_id, params, opts \\ []) do
    validate_id!(account_id, "account_id")

    %Request{
      method: :post,
      path: "/v1/accounts/#{account_id}/external_accounts",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&cast/1)
  end

  @doc """
  Retrieves a single external account on a connected account.

  Sends `GET /v1/accounts/:account/external_accounts/:id`.
  """
  @spec retrieve(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, ea()} | {:error, Error.t()}
  def retrieve(%Client{} = client, account_id, id, opts \\ []) do
    validate_id!(account_id, "account_id")
    validate_id!(id, "id")

    %Request{
      method: :get,
      path: "/v1/accounts/#{account_id}/external_accounts/#{id}",
      params: %{},
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&cast/1)
  end

  @doc """
  Updates an external account on a connected account.

  Sends `POST /v1/accounts/:account/external_accounts/:id`. Stripe's update
  surface is field-limited (metadata, account_holder_name, default_for_currency,
  etc. — varies by external account type).
  """
  @spec update(Client.t(), String.t(), String.t(), map(), keyword()) ::
          {:ok, ea()} | {:error, Error.t()}
  def update(%Client{} = client, account_id, id, params, opts \\ []) do
    validate_id!(account_id, "account_id")
    validate_id!(id, "id")

    %Request{
      method: :post,
      path: "/v1/accounts/#{account_id}/external_accounts/#{id}",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&cast/1)
  end

  @doc """
  Deletes an external account on a connected account.

  Sends `DELETE /v1/accounts/:account/external_accounts/:id`. Stripe returns
  the object type with `"deleted" => true`, which flows into the struct's
  `:extra` map so callers can verify the deletion outcome.
  """
  @spec delete(Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, ea()} | {:error, Error.t()}
  def delete(%Client{} = client, account_id, id, opts \\ []) do
    validate_id!(account_id, "account_id")
    validate_id!(id, "id")

    %Request{
      method: :delete,
      path: "/v1/accounts/#{account_id}/external_accounts/#{id}",
      params: %{},
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&cast/1)
  end

  @doc """
  Lists external accounts on a connected account.

  Sends `GET /v1/accounts/:account/external_accounts`. Pass
  `%{"object" => "bank_account"}` or `%{"object" => "card"}` to filter by type.
  """
  @spec list(Client.t(), String.t(), map(), keyword()) ::
          {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, account_id, params \\ %{}, opts \\ []) do
    validate_id!(account_id, "account_id")

    %Request{
      method: :get,
      path: "/v1/accounts/#{account_id}/external_accounts",
      params: params,
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&cast/1)
  end

  @doc """
  Returns a lazy stream of external accounts on a connected account.

  Emits individual sum-type structs (`%BankAccount{}`, `%Card{}`, or
  `%Unknown{}`), fetching additional pages as needed. Raises
  `LatticeStripe.Error` if any page fetch fails.
  """
  @spec stream!(Client.t(), String.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, account_id, params \\ %{}, opts \\ []) do
    validate_id!(account_id, "account_id")

    req = %Request{
      method: :get,
      path: "/v1/accounts/#{account_id}/external_accounts",
      params: params,
      opts: opts
    }

    List.stream!(client, req) |> Stream.map(&cast/1)
  end

  # ---------------------------------------------------------------------------
  # Bang variants
  # ---------------------------------------------------------------------------

  @doc "Like `create/4` but raises `LatticeStripe.Error` on failure."
  @spec create!(Client.t(), String.t(), map(), keyword()) :: ea()
  def create!(%Client{} = client, account_id, params, opts \\ []) do
    create(client, account_id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc "Like `retrieve/4` but raises `LatticeStripe.Error` on failure."
  @spec retrieve!(Client.t(), String.t(), String.t(), keyword()) :: ea()
  def retrieve!(%Client{} = client, account_id, id, opts \\ []) do
    retrieve(client, account_id, id, opts) |> Resource.unwrap_bang!()
  end

  @doc "Like `update/5` but raises `LatticeStripe.Error` on failure."
  @spec update!(Client.t(), String.t(), String.t(), map(), keyword()) :: ea()
  def update!(%Client{} = client, account_id, id, params, opts \\ []) do
    update(client, account_id, id, params, opts) |> Resource.unwrap_bang!()
  end

  @doc "Like `delete/4` but raises `LatticeStripe.Error` on failure."
  @spec delete!(Client.t(), String.t(), String.t(), keyword()) :: ea()
  def delete!(%Client{} = client, account_id, id, opts \\ []) do
    delete(client, account_id, id, opts) |> Resource.unwrap_bang!()
  end

  @doc "Like `list/4` but raises `LatticeStripe.Error` on failure."
  @spec list!(Client.t(), String.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, account_id, params \\ %{}, opts \\ []) do
    list(client, account_id, params, opts) |> Resource.unwrap_bang!()
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Pre-network guard: raise ArgumentError immediately on empty / nil / non-binary.
  defp validate_id!(value, _name) when is_binary(value) and value != "", do: :ok

  defp validate_id!(_value, name) do
    raise ArgumentError,
          "LatticeStripe.ExternalAccount requires a non-empty binary #{name}"
  end
end
