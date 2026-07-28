defmodule LatticeStripe.Billing.MeterErrorReport.ErrorType do
  @moduledoc """
  One class of async meter-event failure: a `code`, how many events failed with
  it, and a **sample** of those failures.

  ## `sample_errors` is a sample, not a list of every failure

  `error_count` is the true number of events that failed with this `code`.
  `sample_errors` holds only a subset Stripe chose to include — and on
  high-volume failures it is routinely empty while `error_count` is in the
  hundreds. Treating `length(sample_errors)` as the failure count under-reports,
  usually by an order of magnitude. Read `error_count` for the count and
  `sample_errors` for the examples.

  ## `code` is a String, and stays one

  `code` is **never** converted to an atom. Three reasons, each sufficient:

  1. **Stripe documents the enum as open.** The reference says "Open Enum."
     verbatim. New values arrive without a version bump.
  2. **It is server-controlled and demonstrably growing.** Stripe has already
     *retired* one value (`meter_event_value_not_found`) that this repository's
     own metering guide still documents — the set churns in both directions.
  3. **Atoms are never garbage collected on the BEAM.** Atomizing a value an
     external server chooses is an atom-table exhaustion vector, and the
     existing-atom variant merely converts that vector into a decode crash on
     the next code Stripe adds.

  A closed union type would go stale the same way the Elixir peer library's
  card-error union did. Match on the binary.

  ## Current values (non-exhaustive)

  The ten values Stripe publishes today. This list is documentation, not a
  contract — do not build a total `case` over it without a catch-all clause:

  - `"archived_meter"`
  - `"meter_event_customer_not_found"`
  - `"meter_event_dimension_count_too_high"`
  - `"meter_event_invalid_value"`
  - `"meter_event_no_customer_defined"`
  - `"meter_event_value_too_many_digits"`
  - `"missing_dimension_payload_keys"`
  - `"no_meter"`
  - `"timestamp_in_future"`
  - `"timestamp_too_far_in_past"`

  Note that `"no_meter"` (a **code**) is a different thing from
  `v1.billing.meter.no_meter_found` (an **event type**).
  """

  alias LatticeStripe.Billing.MeterErrorReport.SampleError

  @type t :: %__MODULE__{
          code: String.t() | nil,
          error_count: integer() | nil,
          sample_errors: [SampleError.t()]
        }

  defstruct [:code, :error_count, sample_errors: []]

  @doc """
  Decode one wire `error_types[]` entry.

  `from_map(nil)` returns `nil`. An absent or empty `sample_errors` array
  yields `[]` — never `nil`, so callers can comprehend over it unconditionally.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{
      code: map["code"],
      error_count: map["error_count"],
      sample_errors: parse_sample_errors(map["sample_errors"])
    }
  end

  # The empty branch returns [] rather than nil. `Tax.Calculation`'s equivalent
  # fan-out returns nil, and that is the shape not being copied here: an absent
  # sample list is genuinely "no samples", and a caller comprehending over it
  # should not have to nil-guard first.
  defp parse_sample_errors(items) when is_list(items),
    do: Enum.map(items, &SampleError.from_map/1)

  defp parse_sample_errors(_other), do: []
end
