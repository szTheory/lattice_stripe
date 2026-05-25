defmodule LatticeStripe.Testing.Fixtures do
  @moduledoc """
  Public raw-map fixtures for downstream app tests.

  The resource-specific modules under `LatticeStripe.Testing.Fixtures.*` return
  Stripe-shaped maps that act as the canonical fixture source of truth for the
  v1.3 resource families. Build `%LatticeStripe.Event{}` structs, signed webhook
  payloads, and typed resource structs on top of these maps via
  `LatticeStripe.Testing`.
  """
end
