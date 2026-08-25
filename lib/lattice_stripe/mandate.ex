defmodule LatticeStripe.Mandate do
  @moduledoc """
  Operations on Stripe Mandate objects.

  Mandates are Stripe-created authorization records used for inspection of
  payment authorization state and customer acceptance details. This module is
  intentionally retrieve-only: LatticeStripe does not expose create, update, or
  delete flows for mandates.

  ## Usage

      {:ok, mandate} = LatticeStripe.Mandate.retrieve(client, "mandate_123")

      case mandate.customer_acceptance do
        %{type: :online} -> :online_acceptance
        _ -> mandate.status
      end
  """

  alias LatticeStripe.{Client, Error, Request, Resource}
  alias LatticeStripe.Mandate.{CustomerAcceptance, SingleUse}
  alias LatticeStripe.ObjectTypes

  @known_fields ~w[
    id object customer_acceptance livemode multi_use on_behalf_of payment_method
    payment_method_details single_use status type
  ]

  defstruct [
    :id,
    :customer_acceptance,
    :livemode,
    :multi_use,
    :on_behalf_of,
    :payment_method,
    :payment_method_details,
    :single_use,
    :status,
    :type,
    object: "mandate",
    extra: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          customer_acceptance: CustomerAcceptance.t() | nil,
          livemode: boolean() | nil,
          multi_use: map() | nil,
          on_behalf_of: String.t() | nil,
          payment_method: LatticeStripe.PaymentMethod.t() | String.t() | nil,
          payment_method_details: map() | nil,
          single_use: SingleUse.t() | nil,
          status: atom() | String.t() | nil,
          type: atom() | String.t() | nil,
          extra: map()
        }

  @doc """
  Retrieves a mandate by ID.

  Sends `GET /v1/mandates/:id` and returns a typed `%Mandate{}`.
  """
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/mandates/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Like `retrieve/3` but raises `LatticeStripe.Error` on failure.
  """
  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    retrieve(client, id, opts) |> Resource.unwrap_bang!()
  end

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "mandate",
      customer_acceptance: CustomerAcceptance.from_map(known["customer_acceptance"]),
      livemode: known["livemode"],
      multi_use: known["multi_use"],
      on_behalf_of: known["on_behalf_of"],
      payment_method: ObjectTypes.maybe_deserialize(known["payment_method"]),
      payment_method_details: known["payment_method_details"],
      single_use: SingleUse.from_map(known["single_use"]),
      status: atomize_status(known["status"]),
      type: atomize_type(known["type"]),
      extra: extra
    }
  end

  defp atomize_status("active"), do: :active
  defp atomize_status("inactive"), do: :inactive
  defp atomize_status("pending"), do: :pending
  defp atomize_status(other), do: other

  defp atomize_type("single_use"), do: :single_use
  defp atomize_type("multi_use"), do: :multi_use
  defp atomize_type(other), do: other
end
