defmodule LatticeStripe.Webhook.SignatureVerificationError do
  @moduledoc """
  Exception raised when Stripe webhook signature verification fails.

  This exception is raised by the bang variants `LatticeStripe.Webhook.verify_signature!/3`
  and `LatticeStripe.Webhook.construct_event!/3` when verification fails. The `reason`
  field contains a machine-matchable atom describing why verification failed.

  ## Reason Atoms

  - `:missing_header` — the `Stripe-Signature` header was absent or empty
  - `:invalid_header` — the `Stripe-Signature` header was present but malformed (missing `t=` or `v1=`)
  - `:no_matching_signature` — none of the provided secrets produced a matching HMAC
  - `:timestamp_expired` — the webhook timestamp is older than the configured tolerance (default 300s)

  ## Example

      try do
        LatticeStripe.Webhook.construct_event!(payload, sig_header, secret)
      rescue
        e in LatticeStripe.Webhook.SignatureVerificationError ->
          IO.inspect(e.reason)  # :no_matching_signature
      end
  """

  defexception [:message, :reason]

  @type verify_error ::
          :missing_header | :invalid_header | :no_matching_signature | :timestamp_expired

  @type t :: %__MODULE__{
          message: String.t(),
          reason: verify_error()
        }

  @doc false
  @impl true
  def exception(opts) when is_list(opts) do
    reason = Keyword.fetch!(opts, :reason)
    message = Keyword.get(opts, :message, default_message(reason))
    %__MODULE__{message: message, reason: reason}
  end

  defp default_message(:missing_header), do: "No Stripe-Signature header found"
  defp default_message(:invalid_header), do: "Stripe-Signature header is malformed"

  defp default_message(:no_matching_signature),
    do: "Signature verification failed — no secret matched"

  defp default_message(:timestamp_expired),
    do: "Webhook timestamp is too old (replay attack protection)"
end
