defmodule LatticeStripe.Testing.TestClockError do
  @moduledoc """
  Exception raised by `LatticeStripe.Testing.TestClock` when a test-time
  precondition fails — e.g., `advance/2` is called with an unsupported
  unit (`:months`, `:years` on Elixir 1.15), or no client is bound at the
  call site.

  Distinct from `LatticeStripe.Error` (which represents Stripe API
  failures): `TestClockError` is purely a test-helper-level programming
  error that surfaces inside the developer's ExUnit suite.
  """

  defexception [:message, :type]

  @type t :: %__MODULE__{
          message: String.t() | nil,
          type: atom() | nil
        }
end
