defmodule LatticeStripe.Billing.MeterErrorReport.Reason do
  @moduledoc """
  Why a window of async meter events was rejected: a total error count, and the
  failures grouped by error code.

  ## Stripe already did the grouping and the counting

  `error_count` appears **twice** in this payload — once here, as the total
  across the whole validation window, and once on each
  `LatticeStripe.Billing.MeterErrorReport.ErrorType` as that code's own count.
  Stripe supplies both, and it supplies the grouping itself via `error_types`.

  That is why this library ships **zero** grouping or counting helpers on the
  error report. An `Enum.group_by/2` wrapper would re-derive a grouping the wire
  already handed you, and a count helper would sum a number Stripe already sent
  — both would be slower and both could disagree with Stripe. The wire supplies
  the ergonomics.

  Note the two counts can legitimately differ from what the samples show: see
  `LatticeStripe.Billing.MeterErrorReport.ErrorType` on why `sample_errors` is a
  sample rather than a complete list.

  ## Nullability

  `reason` is nullable on the wire, so `from_map/1` returns `nil` for `nil`.
  `error_types`, when present at all, decodes to a list of typed structs; when
  absent it decodes to `[]`.
  """

  alias LatticeStripe.Billing.MeterErrorReport.ErrorType

  @type t :: %__MODULE__{
          error_count: integer() | nil,
          error_types: [ErrorType.t()]
        }

  defstruct [:error_count, error_types: []]

  @doc """
  Decode the wire `data.reason` object.

  `from_map(nil)` returns `nil` — `reason` is nullable. An absent `error_types`
  array yields `[]`, never `nil`.
  """
  @spec from_map(map() | nil) :: t() | nil
  def from_map(nil), do: nil

  def from_map(map) when is_map(map) do
    %__MODULE__{
      error_count: map["error_count"],
      error_types: parse_error_types(map["error_types"])
    }
  end

  # Same empty-list contract as ErrorType.sample_errors: absent means "none",
  # and "none" is [] so callers can comprehend over it without a nil guard.
  defp parse_error_types(items) when is_list(items),
    do: Enum.map(items, &ErrorType.from_map/1)

  defp parse_error_types(_other), do: []
end
