defmodule LatticeStripe.Dispute.Evidence do
  @moduledoc """
  Represents the evidence object nested on a Stripe Dispute.

  Unknown fields from the Stripe API response are preserved in `:extra` for
  forward compatibility.

  See [Stripe Dispute Evidence](https://docs.stripe.com/api/disputes/object).
  """

  @known_fields ~w[
    access_activity_log billing_address cancellation_policy
    cancellation_policy_disclosure cancellation_rebuttal customer_communication
    customer_email_address customer_name customer_purchase_ip customer_signature
    duplicate_charge_documentation duplicate_charge_explanation duplicate_charge_id
    enhanced_evidence product_description receipt refund_policy
    refund_policy_disclosure refund_refusal_explanation service_date
    service_documentation shipping_address shipping_carrier shipping_date
    shipping_documentation shipping_tracking_number uncategorized_file
    uncategorized_text
  ]

  @struct_fields Enum.map(@known_fields, &String.to_atom/1)

  # Equivalent to `defstruct @known_fields ++ [:extra]`, but atomized explicitly
  # for current Elixir versions where new struct fields must be atoms at compile time.
  defstruct @struct_fields ++ [extra: %{}]

  @type t :: %__MODULE__{
          access_activity_log: String.t() | nil,
          billing_address: String.t() | nil,
          cancellation_policy: String.t() | nil,
          cancellation_policy_disclosure: String.t() | nil,
          cancellation_rebuttal: String.t() | nil,
          customer_communication: String.t() | nil,
          customer_email_address: String.t() | nil,
          customer_name: String.t() | nil,
          customer_purchase_ip: String.t() | nil,
          customer_signature: String.t() | nil,
          duplicate_charge_documentation: String.t() | nil,
          duplicate_charge_explanation: String.t() | nil,
          duplicate_charge_id: String.t() | nil,
          enhanced_evidence: map() | nil,
          product_description: String.t() | nil,
          receipt: String.t() | nil,
          refund_policy: String.t() | nil,
          refund_policy_disclosure: String.t() | nil,
          refund_refusal_explanation: String.t() | nil,
          service_date: String.t() | nil,
          service_documentation: String.t() | nil,
          shipping_address: String.t() | nil,
          shipping_carrier: String.t() | nil,
          shipping_date: String.t() | nil,
          shipping_documentation: String.t() | nil,
          shipping_tracking_number: String.t() | nil,
          uncategorized_file: String.t() | nil,
          uncategorized_text: String.t() | nil,
          extra: map()
        }

  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)
    known_atoms = Map.new(known, fn {k, v} -> {String.to_existing_atom(k), v} end)
    struct(__MODULE__, Map.merge(known_atoms, %{extra: extra}))
  end
end
