defmodule LatticeStripe.Invoice.AutomaticTax do
  @moduledoc """
  Represents automatic tax calculation settings on a Stripe Invoice.

  Returned as a nested field on `LatticeStripe.Invoice` structs.

  ## Fields

  - `enabled` - Whether automatic tax is enabled for this invoice
  - `status` - Calculation status: `nil`, `"requires_location_inputs"`, `"complete"`, or `"failed"`
  - `liability` - Tax liability object (raw map); present when Stripe Tax is active.
    Kept as a raw map per SDK convention — no sub-struct needed.

  ## Stripe API Reference

  See the [Stripe Invoice object](https://docs.stripe.com/api/invoices/object#invoice_object-automatic_tax)
  for field definitions.
  """

  defstruct [:enabled, :liability, :status]

  @typedoc """
  Automatic tax calculation settings for a Stripe Invoice.
  """
  @type t :: %__MODULE__{
          enabled: boolean() | nil,
          liability: map() | nil,
          status: String.t() | nil
        }

  @doc """
  Converts a decoded Stripe API map to a `%AutomaticTax{}` struct.

  Returns `nil` when given `nil` (invoice has no automatic_tax field).

  ## Example

      iex> LatticeStripe.Invoice.AutomaticTax.from_map(%{
      ...>   "enabled" => true,
      ...>   "status" => "complete",
      ...>   "liability" => %{"type" => "self"}
      ...> })
      %LatticeStripe.Invoice.AutomaticTax{
        enabled: true,
        status: "complete",
        liability: %{"type" => "self"}
      }
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{
      enabled: map["enabled"],
      liability: map["liability"],
      status: map["status"]
    }
  end
end
