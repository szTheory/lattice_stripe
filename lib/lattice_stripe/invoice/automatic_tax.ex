defmodule LatticeStripe.Invoice.AutomaticTax do
  @moduledoc """
  Represents automatic tax calculation settings on a Stripe Invoice.

  Returned as a nested field on `LatticeStripe.Invoice` and
  `LatticeStripe.Subscription` structs (both Stripe resources carry an
  `automatic_tax` sub-object with the same shape).

  ## Fields

  - `enabled` - Whether automatic tax is enabled for this invoice
  - `status` - Calculation status: `nil`, `"requires_location_inputs"`, `"complete"`, or `"failed"`
  - `liability` - Tax liability object (raw map); present when Stripe Tax is active.
    Kept as a raw map per SDK convention — no sub-struct needed.
  - `extra` - Unknown fields from Stripe not yet in this struct. Future Stripe
    API additions to `automatic_tax` are preserved here rather than silently
    dropped.

  ## Stripe API Reference

  See the [Stripe Invoice object](https://docs.stripe.com/api/invoices/object#invoice_object-automatic_tax)
  for field definitions.
  """

  @known_fields ~w[enabled liability status]

  defstruct [:enabled, :liability, :status, extra: %{}]

  @typedoc """
  Automatic tax calculation settings for a Stripe Invoice or Subscription.
  """
  @type t :: %__MODULE__{
          enabled: boolean() | nil,
          liability: map() | nil,
          status: String.t() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%AutomaticTax{}` struct.

  Maps all known `automatic_tax` fields. Any unrecognized fields are collected
  into the `extra` map so forward-compatible additions from Stripe are not
  silently lost.

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
        liability: %{"type" => "self"},
        extra: %{}
      }
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      enabled: known["enabled"],
      liability: known["liability"],
      status: known["status"],
      extra: extra
    }
  end
end

defimpl Inspect, for: LatticeStripe.Invoice.AutomaticTax do
  import Inspect.Algebra

  def inspect(tax, opts) do
    base_fields = [
      enabled: tax.enabled,
      status: tax.status,
      liability: tax.liability
    ]

    fields =
      if tax.extra == %{} do
        base_fields
      else
        base_fields ++ [extra: tax.extra]
      end

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.Invoice.AutomaticTax<" | pairs] ++ [">"])
  end
end
