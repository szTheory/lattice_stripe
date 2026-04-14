defmodule LatticeStripe.BillingPortal.Guards do
  @moduledoc false
  # Guard numbering scheme (discoverability entry point):
  #
  #   PORTAL-GUARD-01 — check_flow_data!/1 (flow_data.type dispatch + required sub-fields)
  #
  # Pre-flight guards live alongside their resource namespace per Phase 20 D-01.
  # BillingPortal and Billing are unrelated Stripe surfaces that happen to share
  # the word "billing"; see .planning/v1.1-accrue-context.md.

  @fn_name "LatticeStripe.BillingPortal.Session.create/3"

  @doc """
  Pre-flight guard for `LatticeStripe.BillingPortal.Session.create/3`.

  Raises `ArgumentError` when `flow_data.type` is a known type whose required
  nested sub-fields are missing, OR when `flow_data.type` is an unknown string,
  OR when `flow_data` is present but malformed. Silent-passes when `flow_data`
  is omitted entirely (valid — Stripe renders the default portal homepage).

  Reads string keys only (Stripe wire format — Phase 20 D-06). Atom-keyed
  params bypass the guard; the HTTP layer will surface Stripe's 400.
  """
  @spec check_flow_data!(map()) :: :ok
  def check_flow_data!(%{"flow_data" => flow}) when is_map(flow), do: check_flow!(flow)
  def check_flow_data!(_), do: :ok

  # payment_method_update has no required sub-fields.
  defp check_flow!(%{"type" => "payment_method_update"}), do: :ok

  # subscription_cancel requires .subscription_cancel.subscription
  defp check_flow!(%{
         "type" => "subscription_cancel",
         "subscription_cancel" => %{"subscription" => s}
       })
       when is_binary(s) and byte_size(s) > 0,
       do: :ok

  defp check_flow!(%{"type" => "subscription_cancel"} = f),
    do: raise_missing!("subscription_cancel", "subscription_cancel.subscription", f)

  # subscription_update requires .subscription_update.subscription
  defp check_flow!(%{
         "type" => "subscription_update",
         "subscription_update" => %{"subscription" => s}
       })
       when is_binary(s) and byte_size(s) > 0,
       do: :ok

  defp check_flow!(%{"type" => "subscription_update"} = f),
    do: raise_missing!("subscription_update", "subscription_update.subscription", f)

  # subscription_update_confirm requires .subscription_update_confirm.subscription
  # AND .subscription_update_confirm.items (non-empty list)
  defp check_flow!(%{
         "type" => "subscription_update_confirm",
         "subscription_update_confirm" => %{"subscription" => s, "items" => i}
       })
       when is_binary(s) and byte_size(s) > 0 and is_list(i) and i != [],
       do: :ok

  defp check_flow!(%{"type" => "subscription_update_confirm"} = f),
    do:
      raise_missing!(
        "subscription_update_confirm",
        "subscription_update_confirm.subscription AND .items (non-empty list)",
        f
      )

  # Unknown type string — enumerate the valid set in the error.
  defp check_flow!(%{"type" => type}) when is_binary(type) do
    raise ArgumentError,
          "#{@fn_name}: unknown flow_data.type #{inspect(type)}. Valid types: " <>
            ~s["subscription_cancel", "subscription_update", ] <>
            ~s["subscription_update_confirm", "payment_method_update".]
  end

  # Malformed flow_data (no type key, or non-binary type).
  defp check_flow!(flow) do
    raise ArgumentError,
          ~s[#{@fn_name}: flow_data must contain a "type" key, got: #{inspect(flow)}]
  end

  defp raise_missing!(type, path, flow) do
    raise ArgumentError,
          ~s[#{@fn_name}: flow_data.type is "#{type}" but required field ] <>
            ~s[#{path} is missing. Got flow_data: #{inspect(flow)}]
  end
end
