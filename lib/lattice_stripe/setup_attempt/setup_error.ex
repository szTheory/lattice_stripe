defmodule LatticeStripe.SetupAttempt.SetupError do
  @moduledoc """
  Represents the historical `setup_error` nested object on a Stripe SetupAttempt.

  Unknown fields from the Stripe API response are preserved in `:extra` for
  forward compatibility.
  """

  alias LatticeStripe.ObjectTypes

  @known_fields ~w[
    advice_code code decline_code doc_url message network_advice_code
    network_decline_code param payment_method type
  ]

  defstruct [
    :advice_code,
    :code,
    :decline_code,
    :doc_url,
    :message,
    :network_advice_code,
    :network_decline_code,
    :param,
    :payment_method,
    :type,
    extra: %{}
  ]

  @type t :: %__MODULE__{
          advice_code: String.t() | nil,
          code: String.t() | nil,
          decline_code: String.t() | nil,
          doc_url: String.t() | nil,
          message: String.t() | nil,
          network_advice_code: String.t() | nil,
          network_decline_code: String.t() | nil,
          param: String.t() | nil,
          payment_method: LatticeStripe.PaymentMethod.t() | String.t() | map() | nil,
          type: String.t() | nil,
          extra: map()
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      advice_code: known["advice_code"],
      code: known["code"],
      decline_code: known["decline_code"],
      doc_url: known["doc_url"],
      message: known["message"],
      network_advice_code: known["network_advice_code"],
      network_decline_code: known["network_decline_code"],
      param: known["param"],
      payment_method: parse_payment_method(known["payment_method"]),
      type: known["type"],
      extra: extra
    }
  end

  defp parse_payment_method(value) when is_map(value), do: ObjectTypes.maybe_deserialize(value)
  defp parse_payment_method(value), do: value
end
