defmodule LatticeStripe.SubscriptionSchedule.Phase do
  @moduledoc """
  A single phase of a Stripe Subscription Schedule.

  ## Dual usage

  This struct is used for BOTH `schedule.phases[]` entries AND
  `schedule.default_settings`. When populated from `default_settings`, the
  timeline fields (`start_date`, `end_date`, `iterations`, `trial_end`,
  `trial_continuation`) will be `nil` — those fields only apply to concrete
  phases on the timeline, not to the per-schedule defaults.

  This asymmetry reflects Stripe's API shape, not a LatticeStripe modeling
  defect. Reusing one struct for both positions is justified because every
  other field on `default_settings` matches the Phase shape.

  ## Nested decoding

  - `automatic_tax` decodes via `LatticeStripe.Invoice.AutomaticTax.from_map/1`
    (reused from Phase 14 — no duplication).
  - `items` decodes into `[%LatticeStripe.SubscriptionSchedule.PhaseItem{}]`.
  - `add_invoice_items` decodes into
    `[%LatticeStripe.SubscriptionSchedule.AddInvoiceItem{}]`.
  - Other nested fields (`invoice_settings`, `transfer_data`,
    `billing_thresholds`, `discounts`, `metadata`, `pause_collection`,
    `prebilling`, `default_tax_rates`) stay as plain maps/values.

  ## PII

  `Phase` uses Elixir's default derived Inspect — there is NO `defimpl Inspect`
  on this struct. All PII masking for `default_payment_method` (and for any
  payment-method id appearing inside `phases[]` or `default_settings`) is
  handled by the single custom `Inspect` impl on the top-level
  `%LatticeStripe.SubscriptionSchedule{}`, which never surfaces `phases[]`
  or `default_settings` contents as full structs.
  """

  alias LatticeStripe.Invoice.AutomaticTax
  alias LatticeStripe.SubscriptionSchedule.{AddInvoiceItem, PhaseItem}

  @known_fields ~w[
    add_invoice_items application_fee_percent automatic_tax billing_cycle_anchor
    billing_thresholds collection_method currency default_payment_method default_tax_rates
    description discounts end_date invoice_settings items iterations metadata on_behalf_of
    pause_collection prebilling proration_behavior start_date transfer_data trial_continuation
    trial_end
  ]

  defstruct [
    :add_invoice_items,
    :application_fee_percent,
    :automatic_tax,
    :billing_cycle_anchor,
    :billing_thresholds,
    :collection_method,
    :currency,
    :default_payment_method,
    :default_tax_rates,
    :description,
    :discounts,
    :end_date,
    :invoice_settings,
    :items,
    :iterations,
    :metadata,
    :on_behalf_of,
    :pause_collection,
    :prebilling,
    :proration_behavior,
    :start_date,
    :transfer_data,
    :trial_continuation,
    :trial_end,
    extra: %{}
  ]

  @typedoc "A Stripe Subscription Schedule Phase (also reused for default_settings)."
  @type t :: %__MODULE__{
          add_invoice_items: [AddInvoiceItem.t()] | nil,
          application_fee_percent: number() | nil,
          automatic_tax: AutomaticTax.t() | nil,
          billing_cycle_anchor: String.t() | nil,
          billing_thresholds: map() | nil,
          collection_method: String.t() | nil,
          currency: String.t() | nil,
          default_payment_method: String.t() | nil,
          default_tax_rates: list() | nil,
          description: String.t() | nil,
          discounts: list() | nil,
          end_date: integer() | nil,
          invoice_settings: map() | nil,
          items: [PhaseItem.t()] | nil,
          iterations: integer() | nil,
          metadata: map() | nil,
          on_behalf_of: String.t() | nil,
          pause_collection: map() | nil,
          prebilling: map() | nil,
          proration_behavior: String.t() | nil,
          start_date: integer() | nil,
          transfer_data: map() | nil,
          trial_continuation: String.t() | nil,
          trial_end: integer() | nil,
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%Phase{}` struct.

  Decodes nested typed structs:
  - `automatic_tax` → `%LatticeStripe.Invoice.AutomaticTax{}`
  - `items` → `[%LatticeStripe.SubscriptionSchedule.PhaseItem{}]`
  - `add_invoice_items` → `[%LatticeStripe.SubscriptionSchedule.AddInvoiceItem{}]`

  Unknown fields are collected into `:extra`.

  Returns `nil` when given `nil`.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      add_invoice_items: decode_add_invoice_items(known["add_invoice_items"]),
      application_fee_percent: known["application_fee_percent"],
      automatic_tax: AutomaticTax.from_map(known["automatic_tax"]),
      billing_cycle_anchor: known["billing_cycle_anchor"],
      billing_thresholds: known["billing_thresholds"],
      collection_method: known["collection_method"],
      currency: known["currency"],
      default_payment_method: known["default_payment_method"],
      default_tax_rates: known["default_tax_rates"],
      description: known["description"],
      discounts: known["discounts"],
      end_date: known["end_date"],
      invoice_settings: known["invoice_settings"],
      items: decode_items(known["items"]),
      iterations: known["iterations"],
      metadata: known["metadata"],
      on_behalf_of: known["on_behalf_of"],
      pause_collection: known["pause_collection"],
      prebilling: known["prebilling"],
      proration_behavior: known["proration_behavior"],
      start_date: known["start_date"],
      transfer_data: known["transfer_data"],
      trial_continuation: known["trial_continuation"],
      trial_end: known["trial_end"],
      extra: extra
    }
  end

  defp decode_items(nil), do: nil
  defp decode_items(items) when is_list(items), do: Enum.map(items, &PhaseItem.from_map/1)
  defp decode_items(other), do: other

  defp decode_add_invoice_items(nil), do: nil

  defp decode_add_invoice_items(items) when is_list(items),
    do: Enum.map(items, &AddInvoiceItem.from_map/1)

  defp decode_add_invoice_items(other), do: other
end
