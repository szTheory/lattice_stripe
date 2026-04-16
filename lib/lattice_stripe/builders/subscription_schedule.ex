defmodule LatticeStripe.Builders.SubscriptionSchedule do
  @moduledoc """
  Optional fluent builder for `LatticeStripe.SubscriptionSchedule` creation params.

  This is a **companion** to the raw map API — not a replacement. Developers who
  prefer to construct deeply-nested phase params via a pipe chain can use this
  builder to avoid manually typing string keys and prevent typos. The output of
  `build/1` is a plain string-keyed map that passes directly to
  `LatticeStripe.SubscriptionSchedule.create/3`.

  ## Usage

  ### Mode 1: customer + phases

  Build a new schedule from scratch with an explicit phase timeline.

      alias LatticeStripe.Builders.SubscriptionSchedule, as: SSBuilder

      params =
        SSBuilder.new()
        |> SSBuilder.customer("cus_1234567890")
        |> SSBuilder.start_date(:now)
        |> SSBuilder.end_behavior(:release)
        |> SSBuilder.add_phase(
             SSBuilder.phase_new()
             |> SSBuilder.phase_items([%{"price" => "price_1234567890", "quantity" => 1}])
             |> SSBuilder.phase_iterations(12)
             |> SSBuilder.phase_proration_behavior(:create_prorations)
             |> SSBuilder.phase_build()
           )
        |> SSBuilder.build()

      # Pass to the resource layer
      LatticeStripe.SubscriptionSchedule.create(client, params)

  ### Mode 2: from_subscription

  Convert an existing Subscription into a schedule whose first phase captures
  the subscription's current state.

      params =
        SSBuilder.new()
        |> SSBuilder.from_subscription("sub_1234567890")
        |> SSBuilder.build()

      LatticeStripe.SubscriptionSchedule.create(client, params)

  **Important:** The two modes are mutually exclusive. Mixing `customer`/`phases`
  fields with `from_subscription` produces a Stripe 400 error. The builder does
  not client-side-validate this constraint — Stripe's error is already actionable.

  ## Nil omission

  `build/1` and `phase_build/1` automatically strip fields with `nil` values,
  so setting only the fields you need is safe — unused fields do not appear in
  the output map.

  ## Atom values

  Stripe enum fields (`:release`, `:create_prorations`, `:resume`, etc.) are
  automatically converted to their string equivalents in `build/1` and
  `phase_build/1` output.
  """

  @opaque t :: %__MODULE__{}

  defmodule Phase do
    @moduledoc false

    @opaque t :: %__MODULE__{}

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
      items: []
    ]
  end

  defstruct [
    :customer,
    :from_subscription,
    :start_date,
    :end_behavior,
    :metadata,
    phases: []
  ]

  # ---------------------------------------------------------------------------
  # Top-level accumulator setters
  # ---------------------------------------------------------------------------

  @doc "Create a new empty SubscriptionSchedule builder accumulator."
  @spec new() :: t()
  def new(), do: %__MODULE__{}

  @doc "Set the customer ID (Mode 1 — customer + phases)."
  @spec customer(t(), String.t()) :: t()
  def customer(%__MODULE__{} = b, cus_id) when is_binary(cus_id),
    do: %{b | customer: cus_id}

  @doc "Set the source subscription ID (Mode 2 — from_subscription)."
  @spec from_subscription(t(), String.t()) :: t()
  def from_subscription(%__MODULE__{} = b, sub_id) when is_binary(sub_id),
    do: %{b | from_subscription: sub_id}

  @doc "Set the schedule start date. Accepts `:now`, a Unix timestamp integer, or a string."
  @spec start_date(t(), :now | integer() | String.t()) :: t()
  def start_date(%__MODULE__{} = b, date), do: %{b | start_date: date}

  @doc "Set the end behavior atom or string (e.g. `:release`, `:cancel`)."
  @spec end_behavior(t(), atom() | String.t()) :: t()
  def end_behavior(%__MODULE__{} = b, value), do: %{b | end_behavior: value}

  @doc "Set schedule-level metadata map."
  @spec metadata(t(), map()) :: t()
  def metadata(%__MODULE__{} = b, meta) when is_map(meta), do: %{b | metadata: meta}

  @doc """
  Append a phase to the schedule.

  Accepts either a plain string-keyed map (output of `phase_build/1`) or a
  `%Phase{}` struct (the result of `phase_new/0` plus setter calls). If given a
  struct, `phase_build/1` is called internally before appending.
  """
  @spec add_phase(t(), map() | Phase.t()) :: t()
  def add_phase(%__MODULE__{} = b, %Phase{} = phase),
    do: %{b | phases: b.phases ++ [phase_build(phase)]}

  def add_phase(%__MODULE__{} = b, phase) when is_map(phase),
    do: %{b | phases: b.phases ++ [phase]}

  @doc """
  Produce the final string-keyed params map.

  Nil values are omitted. Atom enum values are converted to strings. The
  `"phases"` key is omitted when no phases have been added.
  """
  @spec build(t()) :: map()
  def build(%__MODULE__{} = b) do
    %{
      "customer" => b.customer,
      "from_subscription" => b.from_subscription,
      "start_date" => stringify_date(b.start_date),
      "end_behavior" => to_string_if_atom(b.end_behavior),
      "metadata" => b.metadata
    }
    |> then(fn m ->
      if b.phases == [], do: m, else: Map.put(m, "phases", b.phases)
    end)
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
  end

  # ---------------------------------------------------------------------------
  # Phase sub-builder functions
  # ---------------------------------------------------------------------------

  @doc "Create a new empty Phase accumulator."
  @spec phase_new() :: Phase.t()
  def phase_new(), do: %Phase{}

  @doc "Set the items list on a phase."
  @spec phase_items(Phase.t(), list()) :: Phase.t()
  def phase_items(%Phase{} = p, items) when is_list(items), do: %{p | items: items}

  @doc "Set the add_invoice_items list on a phase."
  @spec phase_add_invoice_items(Phase.t(), list()) :: Phase.t()
  def phase_add_invoice_items(%Phase{} = p, items) when is_list(items),
    do: %{p | add_invoice_items: items}

  @doc "Set the number of iterations for this phase."
  @spec phase_iterations(Phase.t(), integer()) :: Phase.t()
  def phase_iterations(%Phase{} = p, n) when is_integer(n), do: %{p | iterations: n}

  @doc "Set proration behavior atom or string (e.g. `:create_prorations`, `:none`)."
  @spec phase_proration_behavior(Phase.t(), atom() | String.t()) :: Phase.t()
  def phase_proration_behavior(%Phase{} = p, value), do: %{p | proration_behavior: value}

  @doc "Set the billing cycle anchor behavior."
  @spec phase_billing_cycle_anchor(Phase.t(), atom() | String.t()) :: Phase.t()
  def phase_billing_cycle_anchor(%Phase{} = p, value), do: %{p | billing_cycle_anchor: value}

  @doc "Set the collection method (e.g. `:charge_automatically`, `:send_invoice`)."
  @spec phase_collection_method(Phase.t(), atom() | String.t()) :: Phase.t()
  def phase_collection_method(%Phase{} = p, value), do: %{p | collection_method: value}

  @doc "Set the currency code for this phase."
  @spec phase_currency(Phase.t(), String.t()) :: Phase.t()
  def phase_currency(%Phase{} = p, currency) when is_binary(currency),
    do: %{p | currency: currency}

  @doc "Set the default payment method ID for this phase."
  @spec phase_default_payment_method(Phase.t(), String.t()) :: Phase.t()
  def phase_default_payment_method(%Phase{} = p, pm_id) when is_binary(pm_id),
    do: %{p | default_payment_method: pm_id}

  @doc "Set the description for this phase."
  @spec phase_description(Phase.t(), String.t()) :: Phase.t()
  def phase_description(%Phase{} = p, desc) when is_binary(desc), do: %{p | description: desc}

  @doc "Set the end date (Unix timestamp) for this phase."
  @spec phase_end_date(Phase.t(), integer() | String.t()) :: Phase.t()
  def phase_end_date(%Phase{} = p, date), do: %{p | end_date: date}

  @doc "Set metadata map for this phase."
  @spec phase_metadata(Phase.t(), map()) :: Phase.t()
  def phase_metadata(%Phase{} = p, meta) when is_map(meta), do: %{p | metadata: meta}

  @doc "Set the on_behalf_of account ID for this phase."
  @spec phase_on_behalf_of(Phase.t(), String.t()) :: Phase.t()
  def phase_on_behalf_of(%Phase{} = p, acct_id) when is_binary(acct_id),
    do: %{p | on_behalf_of: acct_id}

  @doc "Set the start date for this phase."
  @spec phase_start_date(Phase.t(), integer() | String.t()) :: Phase.t()
  def phase_start_date(%Phase{} = p, date), do: %{p | start_date: date}

  @doc "Set trial_continuation behavior (e.g. `:resume`, `:none`)."
  @spec phase_trial_continuation(Phase.t(), atom() | String.t()) :: Phase.t()
  def phase_trial_continuation(%Phase{} = p, value), do: %{p | trial_continuation: value}

  @doc "Set the trial end date (Unix timestamp) for this phase."
  @spec phase_trial_end(Phase.t(), integer() | String.t()) :: Phase.t()
  def phase_trial_end(%Phase{} = p, date), do: %{p | trial_end: date}

  @doc "Set the application fee percent for this phase."
  @spec phase_application_fee_percent(Phase.t(), number()) :: Phase.t()
  def phase_application_fee_percent(%Phase{} = p, pct),
    do: %{p | application_fee_percent: pct}

  @doc "Set the transfer_data map for this phase."
  @spec phase_transfer_data(Phase.t(), map()) :: Phase.t()
  def phase_transfer_data(%Phase{} = p, data) when is_map(data), do: %{p | transfer_data: data}

  @doc "Set the discounts list for this phase."
  @spec phase_discounts(Phase.t(), list()) :: Phase.t()
  def phase_discounts(%Phase{} = p, discounts) when is_list(discounts),
    do: %{p | discounts: discounts}

  @doc "Set the default_tax_rates list for this phase."
  @spec phase_default_tax_rates(Phase.t(), list()) :: Phase.t()
  def phase_default_tax_rates(%Phase{} = p, rates) when is_list(rates),
    do: %{p | default_tax_rates: rates}

  @doc "Set the invoice_settings map for this phase."
  @spec phase_invoice_settings(Phase.t(), map()) :: Phase.t()
  def phase_invoice_settings(%Phase{} = p, settings) when is_map(settings),
    do: %{p | invoice_settings: settings}

  @doc "Set the automatic_tax map for this phase."
  @spec phase_automatic_tax(Phase.t(), map()) :: Phase.t()
  def phase_automatic_tax(%Phase{} = p, auto_tax) when is_map(auto_tax),
    do: %{p | automatic_tax: auto_tax}

  @doc "Set the pause_collection map for this phase."
  @spec phase_pause_collection(Phase.t(), map()) :: Phase.t()
  def phase_pause_collection(%Phase{} = p, pc) when is_map(pc), do: %{p | pause_collection: pc}

  @doc "Set the prebilling map for this phase."
  @spec phase_prebilling(Phase.t(), map()) :: Phase.t()
  def phase_prebilling(%Phase{} = p, pb) when is_map(pb), do: %{p | prebilling: pb}

  @doc "Set the billing_thresholds map for this phase."
  @spec phase_billing_thresholds(Phase.t(), map()) :: Phase.t()
  def phase_billing_thresholds(%Phase{} = p, bt) when is_map(bt),
    do: %{p | billing_thresholds: bt}

  @doc """
  Produce the final string-keyed map for a phase.

  Nil values are omitted. Atom enum values are converted to strings. Empty
  `items` and `add_invoice_items` lists are omitted.
  """
  @spec phase_build(Phase.t()) :: map()
  def phase_build(%Phase{} = p) do
    %{
      "add_invoice_items" => nilify_empty(p.add_invoice_items),
      "application_fee_percent" => p.application_fee_percent,
      "automatic_tax" => p.automatic_tax,
      "billing_cycle_anchor" => to_string_if_atom(p.billing_cycle_anchor),
      "billing_thresholds" => p.billing_thresholds,
      "collection_method" => to_string_if_atom(p.collection_method),
      "currency" => p.currency,
      "default_payment_method" => p.default_payment_method,
      "default_tax_rates" => p.default_tax_rates,
      "description" => p.description,
      "discounts" => p.discounts,
      "end_date" => p.end_date,
      "invoice_settings" => p.invoice_settings,
      "items" => nilify_empty(p.items),
      "iterations" => p.iterations,
      "metadata" => p.metadata,
      "on_behalf_of" => p.on_behalf_of,
      "pause_collection" => p.pause_collection,
      "prebilling" => p.prebilling,
      "proration_behavior" => to_string_if_atom(p.proration_behavior),
      "start_date" => p.start_date,
      "transfer_data" => p.transfer_data,
      "trial_continuation" => to_string_if_atom(p.trial_continuation),
      "trial_end" => p.trial_end
    }
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp to_string_if_atom(v) when is_atom(v) and not is_nil(v), do: Atom.to_string(v)
  defp to_string_if_atom(v), do: v

  defp stringify_date(:now), do: "now"
  defp stringify_date(v) when is_integer(v), do: v
  defp stringify_date(v) when is_binary(v), do: v
  defp stringify_date(nil), do: nil

  defp nilify_empty([]), do: nil
  defp nilify_empty(v), do: v
end
