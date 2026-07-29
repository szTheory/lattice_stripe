defmodule LatticeStripe.Billing.Guards do
  @moduledoc false
  # Guard numbering scheme (discoverability entry point):
  #
  #   GUARD-01 — check_meter_value_settings!/1 (sum/last formula requires value_settings)
  #   GUARD-02 — @doc contract on MeterEvent.create/3 documenting 35-day window,
  #              24-hour identifier dedup, and async-ack semantics. This is a
  #              documentation guarantee enforced by a Code.fetch_docs test,
  #              not a function in this module.
  #   GUARD-03 — check_adjustment_cancel_shape!/1 (cancel must nest identifier)
  #   GUARD-04 — check_summary_window!/2 (meter event summary reads: start_time and
  #              end_time must align to minute boundaries always, to UTC hour
  #              boundaries for the "hour" window, and to UTC day boundaries for
  #              the "day" window. Raises with the arithmetic printed; never snaps
  #              the window itself — see the @doc for why)
  #
  # PII masking on %MeterEvent{} is implemented via a custom Inspect protocol in
  # lib/lattice_stripe/billing/meter_event.ex (tagged PII-01), not a guard here.
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

  @doc """
  Pre-flight guard for `LatticeStripe.Billing.MeterEventSummary.list/4` and
  `LatticeStripe.Billing.MeterEventSummary.stream!/4`.

  Raises `ArgumentError` when `start_time` or `end_time` is not aligned to the
  boundary Stripe requires: **minute** boundaries on every query, **UTC hour**
  boundaries when `value_grouping_window` is `"hour"`, and **UTC day** boundaries
  (00:00 UTC) when it is `"day"`. Stripe rejects a misaligned window with an HTTP
  400 whose error code it does not document, so the failure cannot be improved
  after the fact — only prevented. This raise fires before the request is built.

  The guard reports the arithmetic and **does not apply it**. Snapping a window
  has to choose flooring or ceiling, and that choice changes which usage the
  window covers, so it belongs to the caller.

  `fun` is the caller's own `fun/arity` spelling, so the message names whichever
  entry point was invoked — `list/4` and `stream!/4` produce the same message with
  a different function name.

  Silently passes when the `value_grouping_window` value is unrecognised (Stripe
  has extended that enum before and will again), when a timestamp is absent
  (`LatticeStripe.Resource.require_param!/3` owns that case), and when a timestamp
  is not an integer (Stripe's own type validation owns that case). Reads string
  keys only (Stripe wire format), so an atom-keyed params map bypasses the guard.
  """
  @spec check_summary_window!(map(), String.t()) :: :ok
  def check_summary_window!(params, fun) when is_map(params) do
    case summary_divisor(params["value_grouping_window"]) do
      # MANDATORY HATCH 1 — forward compatibility. An unrecognised window value is
      # not checked at all, deliberately: Stripe added "day" to this enum in
      # mid-2024, and a guard that rejected unknown values would have broken every
      # caller on the day it was extended. This clause is the design, not a gap.
      nil ->
        :ok

      divisor ->
        check_aligned!(params, "start_time", divisor, fun)
        check_aligned!(params, "end_time", divisor, fun)
    end
  end

  def check_summary_window!(_non_map, _fun), do: :ok

  # An absent window means 60, not "skip": Stripe states the minute rule on
  # start_time and end_time themselves, independently of the window clause, so it
  # applies to every query whether or not a grouping window was supplied.
  defp summary_divisor(nil), do: 60
  defp summary_divisor("hour"), do: 3_600
  defp summary_divisor("day"), do: 86_400
  defp summary_divisor(_unrecognised), do: nil

  # MANDATORY HATCH 2 — division of responsibility. An absent or non-integer
  # timestamp is skipped rather than raised on: require_param!/3 already owns
  # absence and Stripe owns the wrong type, and an alignment message would send
  # the reader somewhere useless in both cases.
  defp check_aligned!(params, key, divisor, fun) do
    value = Map.get(params, key)

    if is_integer(value) and rem(value, divisor) != 0 do
      raise ArgumentError, misaligned_message(key, value, divisor, fun)
    end

    :ok
  end

  # `Integer.floor_div/2` rather than `div/2` in the printed arithmetic: `div/2`
  # truncates toward zero and so rounds the wrong way for negative inputs. Elixir
  # has no beginning-of-hour helper and `DateTime.truncate/2` only handles
  # sub-second precision, so this is integer arithmetic by necessity.
  defp misaligned_message(key, value, divisor, fun) do
    "LatticeStripe.Billing.MeterEventSummary.#{fun}: #{key} #{value} is not " <>
      "aligned to #{boundary_name(divisor)}. #{alignment_rule(divisor)}, and " <>
      "rejects unaligned values with HTTP 400.\n\n" <>
      "Subscription current_period_start/current_period_end derive from " <>
      "billing_cycle_anchor and are almost never aligned. Align them yourself — " <>
      "this library will not choose floor vs. ceil for you, because that choice " <>
      "changes which usage the window includes:\n\n" <>
      "    start_time = Integer.floor_div(start_time, #{divisor}) * #{divisor}   # floor\n" <>
      "    end_time   = -Integer.floor_div(-end_time, #{divisor}) * #{divisor}   # ceil\n"
  end

  defp boundary_name(60), do: "a minute boundary"
  defp boundary_name(3_600), do: "a UTC hour boundary (00:00, 01:00, ..., 23:00)"
  defp boundary_name(86_400), do: "a UTC day boundary (00:00 UTC)"

  defp alignment_rule(60),
    do: "Stripe requires minute-aligned start_time and end_time on every query"

  defp alignment_rule(3_600),
    do: ~s[Stripe requires hour-aligned timestamps when value_grouping_window is "hour"]

  defp alignment_rule(86_400),
    do: ~s[Stripe requires day-aligned timestamps when value_grouping_window is "day"]
end
