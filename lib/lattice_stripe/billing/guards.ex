defmodule LatticeStripe.Billing.Guards do
  @moduledoc false
  require Logger
  alias LatticeStripe.{Client, Error}

  @doc """
  Checks if the client requires explicit proration_behavior and if the param is present.

  Returns `:ok` when:
  - `client.require_explicit_proration` is `false` (default), OR
  - `params` contains the key `"proration_behavior"`

  Returns `{:error, %Error{type: :proration_required}}` when:
  - `client.require_explicit_proration` is `true`, AND
  - `params` does NOT contain the key `"proration_behavior"`
  """
  @spec check_proration_required(Client.t(), map()) :: :ok | {:error, Error.t()}
  def check_proration_required(%Client{require_explicit_proration: false}, _params), do: :ok

  def check_proration_required(%Client{require_explicit_proration: true}, params)
      when is_map(params) do
    if has_proration_behavior?(params) do
      :ok
    else
      {:error,
       %Error{
         type: :proration_required,
         message:
           "proration_behavior is required when require_explicit_proration is enabled. Valid values: \"create_prorations\", \"always_invoice\", \"none\""
       }}
    end
  end

  def check_proration_required(%Client{require_explicit_proration: true}, _params) do
    {:error,
     %Error{
       type: :proration_required,
       message:
         "proration_behavior is required when require_explicit_proration is enabled, and params must be a map. Valid values: \"create_prorations\", \"always_invoice\", \"none\""
     }}
  end

  defp has_proration_behavior?(params) do
    Map.has_key?(params, "proration_behavior") or
      (is_map(params["subscription_details"]) and
         Map.has_key?(params["subscription_details"], "proration_behavior")) or
      items_has?(params["items"]) or
      phases_has?(params["phases"])
  end

  # Detects whether any element of an `items[]` array carries a
  # `"proration_behavior"` key. Defensive against nil, non-list, and
  # non-map list elements.
  defp items_has?(items) when is_list(items) do
    Enum.any?(items, fn
      item when is_map(item) -> Map.has_key?(item, "proration_behavior")
      _ -> false
    end)
  end

  defp items_has?(_), do: false

  # Detects whether any element of a `phases[]` array carries a
  # `"proration_behavior"` key at the phase level. Defensive against nil,
  # non-list, and non-map list elements.
  #
  # NOTE: Stripe only accepts `proration_behavior` at top-level and at
  # `phases[].proration_behavior` on POST /v1/subscription_schedules/:id —
  # it does NOT accept it at `phases[].items[]`. Do not walk deeper.
  # Source: https://docs.stripe.com/api/subscription_schedules/update
  defp phases_has?(phases) when is_list(phases) do
    Enum.any?(phases, fn
      phase when is_map(phase) -> Map.has_key?(phase, "proration_behavior")
      _ -> false
    end)
  end

  defp phases_has?(_), do: false

  @doc """
  Pre-flight guard for `LatticeStripe.Billing.Meter.create/3`.

  Raises `ArgumentError` when `default_aggregation.formula` is `"sum"` or `"last"`
  AND `value_settings` is present-but-malformed (`event_payload_key` missing, nil,
  or empty). This blocks the silent-zero trap where Stripe returns HTTP 200 but
  every event's value contribution is silently dropped.

  Silent-passes when `value_settings` is omitted — Stripe defaults `event_payload_key`
  to `"value"`, which is a legal and common shape.

  Logs `Logger.warning/1` when `formula == "count"` and `value_settings` is passed,
  because Stripe silently ignores `value_settings` for count meters.

  Reads string keys only (Stripe wire format). Atom-keyed params bypass the guard.
  """
  @spec check_meter_value_settings!(map()) :: :ok
  def check_meter_value_settings!(params) when is_map(params) do
    formula = get_in(params, ["default_aggregation", "formula"])
    value_settings = Map.get(params, "value_settings")

    cond do
      formula in ["sum", "last"] and is_map(value_settings) and
          not valid_event_payload_key?(value_settings) ->
        raise ArgumentError,
              "LatticeStripe.Billing.Meter.create/3: default_aggregation.formula " <>
                "is #{inspect(formula)} but value_settings.event_payload_key is " <>
                "missing or empty. Stripe would accept this and silently drop " <>
                "every MeterEvent's value. Either omit value_settings entirely " <>
                "(defaults to \"value\") or pass " <>
                "%{\"event_payload_key\" => \"<your_key>\"}."

      formula == "count" and not is_nil(value_settings) ->
        Logger.warning(
          "LatticeStripe.Billing.Meter.create/3: value_settings is ignored " <>
            "when default_aggregation.formula is \"count\". Stripe will drop " <>
            "this field silently."
        )

        :ok

      true ->
        :ok
    end
  end

  def check_meter_value_settings!(_non_map), do: :ok

  defp valid_event_payload_key?(%{"event_payload_key" => key})
       when is_binary(key) and byte_size(key) > 0,
       do: true

  defp valid_event_payload_key?(_), do: false

  @doc """
  Pre-flight guard for `LatticeStripe.Billing.MeterEventAdjustment.create/3`.

  Raises `ArgumentError` when `params["cancel"]` is not a map containing an
  `"identifier"` binary — catches the top-level-identifier footgun and the
  `cancel.id` / `cancel.event_id` typos that would otherwise reach Stripe as
  a 400.
  """
  @spec check_adjustment_cancel_shape!(map()) :: :ok
  def check_adjustment_cancel_shape!(%{"cancel" => %{"identifier" => id}})
      when is_binary(id) and byte_size(id) > 0,
      do: :ok

  def check_adjustment_cancel_shape!(%{"cancel" => cancel}) do
    raise ArgumentError,
          ~s[LatticeStripe.Billing.MeterEventAdjustment.create/3: `cancel` must be ] <>
            ~s[a map shaped %{"identifier" => "<meter_event_identifier>"}, got: ] <>
            "#{inspect(cancel)}. Common mistakes: putting `identifier` at the top " <>
            "level, using `cancel.id`, or using `cancel.event_id`."
  end

  def check_adjustment_cancel_shape!(params) do
    raise ArgumentError,
          ~s[LatticeStripe.Billing.MeterEventAdjustment.create/3: missing `cancel` ] <>
            ~s[sub-object. Expected %{"cancel" => %{"identifier" => "..."}}, ] <>
            "got: #{inspect(params)}"
  end
end
