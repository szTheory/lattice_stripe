defmodule LatticeStripe.Invoice.StatusTransitions do
  @moduledoc """
  Tracks lifecycle Unix timestamps for a Stripe Invoice.

  Returned as a nested field on `LatticeStripe.Invoice` structs. All fields are
  optional Unix timestamps that record when the invoice entered each lifecycle state.

  ## Fields

  - `finalized_at` - Unix timestamp when the invoice was finalized (moved to open status)
  - `marked_uncollectible_at` - Unix timestamp when the invoice was marked uncollectible
  - `paid_at` - Unix timestamp when the invoice was paid
  - `voided_at` - Unix timestamp when the invoice was voided

  ## Stripe API Reference

  See the [Stripe Invoice object](https://docs.stripe.com/api/invoices/object#invoice_object-status_transitions)
  for field definitions.
  """

  defstruct [:finalized_at, :marked_uncollectible_at, :paid_at, :voided_at]

  @typedoc """
  Lifecycle timestamps for a Stripe Invoice.
  """
  @type t :: %__MODULE__{
          finalized_at: integer() | nil,
          marked_uncollectible_at: integer() | nil,
          paid_at: integer() | nil,
          voided_at: integer() | nil
        }

  @doc """
  Converts a decoded Stripe API map to a `%StatusTransitions{}` struct.

  Returns `nil` when given `nil` (invoice has no status_transitions field).

  ## Example

      iex> LatticeStripe.Invoice.StatusTransitions.from_map(%{
      ...>   "finalized_at" => 1_700_000_000,
      ...>   "paid_at" => 1_700_000_200,
      ...>   "marked_uncollectible_at" => nil,
      ...>   "voided_at" => nil
      ...> })
      %LatticeStripe.Invoice.StatusTransitions{
        finalized_at: 1_700_000_000,
        paid_at: 1_700_000_200,
        marked_uncollectible_at: nil,
        voided_at: nil
      }
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{
      finalized_at: map["finalized_at"],
      marked_uncollectible_at: map["marked_uncollectible_at"],
      paid_at: map["paid_at"],
      voided_at: map["voided_at"]
    }
  end
end
