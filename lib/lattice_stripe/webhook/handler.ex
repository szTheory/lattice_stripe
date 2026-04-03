defmodule LatticeStripe.Webhook.Handler do
  @moduledoc """
  Behaviour for handling verified Stripe webhook events.

  Implement this behaviour in your application to handle incoming webhook events
  dispatched by `LatticeStripe.Plug.Webhook` (or your own dispatcher). The
  handler receives a fully verified and typed `%LatticeStripe.Event{}` struct —
  signature has already been verified before `handle_event/1` is called.

  ## Example

      defmodule MyApp.StripeHandler do
        @behaviour LatticeStripe.Webhook.Handler

        @impl true
        def handle_event(%LatticeStripe.Event{type: "payment_intent.succeeded"} = event) do
          MyApp.Payments.fulfill(event.data["object"])
          :ok
        end

        def handle_event(%LatticeStripe.Event{type: "customer.subscription.deleted"} = event) do
          MyApp.Subscriptions.cancel(event.data["object"])
          :ok
        end

        # Catch-all for events you don't handle explicitly
        def handle_event(_event), do: :ok
      end

  ## Return Values

  - `:ok` — event handled successfully
  - `{:ok, term()}` — event handled successfully, with a return value (ignored by dispatcher)
  - `:error` — event handling failed (dispatcher may log or return 500)
  - `{:error, term()}` — event handling failed with a reason (dispatcher may log or return 500)
  """

  @doc """
  Handles a verified Stripe webhook event.

  Called by the webhook dispatcher after signature verification succeeds.
  The `event` argument is a fully typed `%LatticeStripe.Event{}` struct.

  Return `:ok` or `{:ok, _}` to signal success. Return `:error` or
  `{:error, reason}` to signal failure.
  """
  @callback handle_event(LatticeStripe.Event.t()) ::
              :ok | {:ok, term()} | :error | {:error, term()}
end
