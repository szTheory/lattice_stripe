defmodule LatticeStripe.Balance do
  @moduledoc """
  Stripe Balance singleton.

  `Balance.retrieve(client)` fetches the **platform** balance.
  `Balance.retrieve(client, stripe_account: "acct_123")` fetches the
  **connected account's** balance via the per-request `Stripe-Account` header —
  this is the ONLY distinction between the two reads.

  > #### Reconciliation loop antipattern {: .warning}
  >
  > Code that walks every connected account in a loop MUST pass the
  > `stripe_account:` opt on each call. Calling `Balance.retrieve(client)`
  > with no opts inside such a loop returns the platform balance every time
  > and silently produces wrong reconciliation totals.

  ## Examples

      # Platform balance
      {:ok, balance} = LatticeStripe.Balance.retrieve(client)

      # Connected account balance (per-request override)
      {:ok, balance} =
        LatticeStripe.Balance.retrieve(client, stripe_account: "acct_123")

      # Read available USD balance
      [usd] = Enum.filter(balance.available, &(&1.currency == "usd"))
      IO.puts("Available USD: \#{usd.amount}")

      # Read source-type breakdown
      IO.puts("From cards: \#{usd.source_types.card}")

  ## Module surface

  Balance is a **singleton** — it has no `id`, no `list/1`, no
  `create/2`, `update/3`, or `delete/2`. The only operations are
  `retrieve/2` and `retrieve!/2`.

  ## Stripe API Reference

  https://docs.stripe.com/api/balance
  """

  alias LatticeStripe.Balance.Amount
  alias LatticeStripe.{Client, Error, Request, Resource}

  @known_fields ~w[
    object available connect_reserved instant_available issuing livemode pending
  ]

  defstruct [
    :available,
    :connect_reserved,
    :instant_available,
    :issuing,
    :livemode,
    :pending,
    object: "balance",
    extra: %{}
  ]

  @typedoc "A Stripe Balance object."
  @type t :: %__MODULE__{
          object: String.t(),
          available: [Amount.t()] | nil,
          pending: [Amount.t()] | nil,
          connect_reserved: [Amount.t()] | nil,
          instant_available: [Amount.t()] | nil,
          issuing: map() | nil,
          livemode: boolean() | nil,
          extra: map()
        }

  @doc """
  Retrieves the Stripe Balance.

  Sends `GET /v1/balance` and returns `{:ok, %Balance{}}`.

  Pass `stripe_account: "acct_..."` in `opts` to retrieve a connected
  account's balance via the per-request `Stripe-Account` header.
  """
  @spec retrieve(Client.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, opts \\ []) do
    %Request{method: :get, path: "/v1/balance", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Like `retrieve/2` but raises `LatticeStripe.Error` on failure.
  """
  @spec retrieve!(Client.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, opts \\ []) do
    client |> retrieve(opts) |> Resource.unwrap_bang!()
  end

  @doc false
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    issuing =
      case map["issuing"] do
        %{"available" => avail} = iss when is_list(avail) ->
          Map.put(iss, "available", Enum.map(avail, &Amount.cast/1))

        other ->
          other
      end

    %__MODULE__{
      object: map["object"] || "balance",
      available: cast_amount_list(map["available"]),
      pending: cast_amount_list(map["pending"]),
      connect_reserved: cast_amount_list(map["connect_reserved"]),
      instant_available: cast_amount_list(map["instant_available"]),
      issuing: issuing,
      livemode: map["livemode"],
      extra: Map.drop(map, @known_fields)
    }
  end

  defp cast_amount_list(nil), do: nil
  defp cast_amount_list(list) when is_list(list), do: Enum.map(list, &Amount.cast/1)
end
