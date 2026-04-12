defmodule LatticeStripe.InvoiceItem.Period do
  @moduledoc "Billing period for an InvoiceItem."

  defstruct [:start, :end]

  @typedoc """
  Billing period for a Stripe InvoiceItem.
  """
  @type t :: %__MODULE__{
          start: integer() | nil,
          end: integer() | nil
        }

  @doc """
  Converts a decoded Stripe API map to a `%Period{}` struct.

  Returns `nil` when given `nil` (InvoiceItem has no period field).

  ## Example

      iex> LatticeStripe.InvoiceItem.Period.from_map(%{"start" => 1_700_000_000, "end" => 1_702_000_000})
      %LatticeStripe.InvoiceItem.Period{start: 1_700_000_000, end: 1_702_000_000}
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{
      start: map["start"],
      end: map["end"]
    }
  end
end
