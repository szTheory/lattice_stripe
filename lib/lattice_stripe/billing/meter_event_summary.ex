defmodule LatticeStripe.Billing.MeterEventSummary do
  @moduledoc """
  A pre-aggregated total of the usage reported to one billing meter, for one
  customer, over one window of time.

  Wire object `billing.meter_event_summary`, ids prefixed `mtrusg_`, served from a
  single parent-scoped path: `GET /v1/billing/meters/:meter_id/event_summaries`.
  That is the only path Stripe serves for this object — there is no top-level
  `/v1/billing/meter_event_summaries` collection and no `GET /{summary_id}` — which
  is why the meter id is a positional argument to `list/4` and `stream!/4` rather
  than a filter, and why this module ships no retrieve function.

  > #### Two ways to read a confidently wrong number {: .warning}
  >
  > **The returned object never says which customer it belongs to.** It has exactly
  > seven fields, not one of them names a customer, and it cannot be expanded to add
  > one. The customer is an *input* to the query and never an *output*. So a
  > reconciler that lists summaries for several customers and merges the results has
  > lost the attribution completely — and the warning sign is easy to miss, because
  > grouping the merged list by a customer field is not something you can even
  > attempt: the field does not exist. Keep the association out of band, alongside
  > the customer id you filtered on.
  >
  > **The figure is not live.** Stripe's own specification states that these summaries
  > are **eventually consistent**. The object carries no freshness field and Stripe
  > publishes no staleness SLA, so a caller has no way to tell how old a number is.
  > Label the figure in your UI with the time you fetched it, never present it as
  > real-time, and never treat it as a billing source of truth — Stripe bills from the
  > meter, not from these summaries.

  ## The window boundary is ambiguous

  Stripe's specification contradicts itself about whether the end of the window is
  included. The `end_time` query parameter and the `end_time` field on the returned
  object are both documented as **exclusive**, while `aggregated_value`'s own
  description — on that same object — says the aggregation covers `start_time` through
  `end_time` **inclusive**. Two of the three say exclusive.

  All three descriptions ship verbatim into every SDK's generated documentation, so the
  same contradiction is waiting in Stripe's other libraries. **This library asserts
  neither reading** and does not adjust your window to compensate for either. If one
  boundary event would change a decision you are making, do not settle it by reading
  documentation — measure it against your own account.

  ## Listing

  `customer`, `start_time` and `end_time` are all **required** filters. Stripe answers a
  call missing any of them with an HTTP 400; `list/4` and `stream!/4` raise
  `ArgumentError` before the request leaves the process instead.

  Stripe's `limit` ranges from 1 to 100 and **defaults to 10** — and that default is the
  trap. Ask for hourly buckets across a 31-day month and the window holds **744** of
  them. A caller who sums the ten rows that come back, without checking whether more
  exist, gets a plausible-looking number that is about one and a third percent of the
  truth. (Illustrative, assuming usage spread evenly across the buckets; the real
  fraction depends on your data.)

  The fix is usually not to paginate harder — it is to ask the question you actually
  have.

  **For a total, omit `value_grouping_window`.** Stripe aggregates server-side and
  returns a single bucket, in one request, with no pagination and no client-side float
  summation. This is what an admin screen showing "usage this period" almost always
  wants:

      params = %{
        "customer" => "cus_123",
        "start_time" => 1_753_620_000,
        "end_time" => 1_753_706_400
      }

      resp = LatticeStripe.Billing.MeterEventSummary.list!(client, "mtr_123", params)
      [summary] = resp.data.data

      summary.aggregated_value

  **For a series, pass `value_grouping_window`** as `"hour"` or `"day"` and stream it, so
  that `has_more` is followed for you rather than silently ignored:

      buckets = Map.put(params, "value_grouping_window", "hour")

      client
      |> LatticeStripe.Billing.MeterEventSummary.stream!("mtr_123", buckets)
      |> Enum.map(&{&1.start_time, &1.aggregated_value})

  The difference compounds across a customer base: rendering one usage figure for 200
  customers costs roughly 15,000 requests at the default page size, 1,600 at
  `limit=100`, and 200 with no window at all. See `LatticeStripe.List` for the memory
  guidance that applies to any stream you do not bound with `Stream.take/2`.

  ## Timestamp alignment

  Stripe requires `start_time` and `end_time` to be aligned to **minute** boundaries on
  every query, to **UTC hour** boundaries when `value_grouping_window` is `"hour"`, and
  to **UTC day** boundaries (00:00 UTC) when it is `"day"`. The timezone is UTC — not
  the account's, not the customer's.

  The most natural inputs are the ones that violate this. A subscription's
  `current_period_start` and `current_period_end` derive from its billing cycle anchor,
  so they land on an arbitrary second and are almost never aligned to anything.

  **This library will not align them for you.** Rounding changes what the query means:
  floor the start and you sweep in usage from before the period; ceil it and you drop
  usage that belongs to it. That is a business decision, not a formatting detail, and a
  library that makes it silently produces a wrong number its caller never sees. Do the
  arithmetic yourself, where you can see it:

      start_time = Integer.floor_div(start_time, 86_400) * 86_400
      end_time = -Integer.floor_div(-end_time, 86_400) * 86_400

  `Integer.floor_div/2` rather than `div/2` — `div/2` truncates toward zero, which
  rounds the wrong way for negative inputs.

  ## Design

  Three things this module deliberately does not have:

  - **No retrieve function.** Stripe serves no get-by-summary-id route, so there is no
    operation to wrap. This is an absence in the API, not a gap to apologise for.
  - **No window-aligning helper.** Rejected on domain grounds: any snap has to choose
    floor or ceil, that choice changes which usage the window covers, and adjacent
    metering platforms that do auto-align demonstrate the cost — one of them turns a
    three-day range into four windows without saying so.
  - **No convenience accessor on `LatticeStripe.Billing.Meter`.** Parent-scoping is
    expressed in this module's signatures, not by a delegator on the parent. Stripe's
    own Java SDK documentation once advertised exactly such a method; it never existed,
    and Stripe's answer was that the documentation was wrong.

  Note the read/write type asymmetry: `aggregated_value` comes back as a **float**,
  while `LatticeStripe.Billing.MeterEvent` writes take the value as a **decimal
  string**. See `guides/metering.md` for the payload contract.

  See the [Stripe Meter Event Summary API](https://docs.stripe.com/api/billing/meter-event_summary).
  """

  alias LatticeStripe.{Client, Request, Resource}

  # Exactly the seven fields Stripe's spec marks required — the object has no
  # others. String sigil (no `a`) matches Jason's default string-key output, and
  # square brackets rather than parens because `Drift`'s @known_fields regex only
  # matches the bracket form (D-20).
  @known_fields ~w[
    id object aggregated_value start_time end_time meter livemode
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t() | nil,
          aggregated_value: float() | nil,
          start_time: integer() | nil,
          end_time: integer() | nil,
          meter: String.t() | nil,
          livemode: boolean() | nil,
          extra: map()
        }

  # There is deliberately NO `:customer` field. You filter *by* customer, but
  # Stripe's response never says which customer a summary belongs to — the object
  # has exactly the seven fields below and no more (F-02). This is an omission in
  # Stripe's wire format, not an oversight here: do not "fix" it by inventing a
  # field, because a struct that carries a customer the API never sent is a lie a
  # reconciler will trust. Callers that need the association must keep it out of
  # band, alongside the id they filtered on.
  defstruct [
    :id,
    :aggregated_value,
    :start_time,
    :end_time,
    :meter,
    :livemode,
    object: "billing.meter_event_summary",
    extra: %{}
  ]

  # ---------------------------------------------------------------------------
  # LIST
  # ---------------------------------------------------------------------------

  @doc """
  List one page of usage summaries for a meter.

  Sends `GET /v1/billing/meters/:meter_id/event_summaries`.

  `params` **must** carry `"customer"`, `"start_time"` and `"end_time"` — Stripe
  marks all three required. Each guard raises `ArgumentError` before any network
  call, in that order, and so does an empty or `nil` `meter_id`.

  Those guards check key **presence, not value emptiness**, and read **string keys
  only** (Stripe wire format): a `"customer"` key whose value is `""` passes the
  guard and fails at Stripe instead, and an atom-keyed params map bypasses the
  guards entirely.

  Timestamps are Unix seconds. Stripe requires them aligned to minute boundaries
  always, to UTC hour boundaries when `value_grouping_window` is `"hour"`, and to
  UTC day boundaries (00:00 UTC) when it is `"day"`.

  Also supports Stripe's `limit` (default **10**, max 100) and `starting_after` /
  `ending_before` cursors. A 31-day hourly window is 744 buckets, so a bare
  `list/4` over one silently returns the first ten.
  """
  @spec list(Client.t(), String.t(), map(), keyword()) ::
          {:ok, LatticeStripe.Response.t()} | {:error, LatticeStripe.Error.t()}
  def list(client, meter_id, params \\ %{}, opts \\ [])

  def list(%Client{} = client, meter_id, params, opts) do
    # Every raise below fires before %Request{} is constructed. Order is
    # load-bearing: first failure wins, and it is the id, then customer, then
    # start_time, then end_time.
    validate_id!(meter_id, "list/4")

    Resource.require_param!(
      params,
      "customer",
      "LatticeStripe.Billing.MeterEventSummary.list/4 requires a customer param"
    )

    Resource.require_param!(
      params,
      "start_time",
      "LatticeStripe.Billing.MeterEventSummary.list/4 requires a start_time param"
    )

    Resource.require_param!(
      params,
      "end_time",
      "LatticeStripe.Billing.MeterEventSummary.list/4 requires an end_time param"
    )

    %Request{method: :get, path: path(meter_id), params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc "Like `list/4` but raises on failure."
  @spec list!(Client.t(), String.t(), map(), keyword()) :: LatticeStripe.Response.t()
  def list!(client, meter_id, params \\ %{}, opts \\ []) do
    client |> list(meter_id, params, opts) |> Resource.unwrap_bang!()
  end

  # ---------------------------------------------------------------------------
  # STREAM
  # ---------------------------------------------------------------------------

  @doc """
  Returns a lazy stream of **every** usage summary in the window (auto-pagination).

  Emits individual `%MeterEventSummary{}` structs, following `has_more` and fetching
  each subsequent page as the stream is consumed. Raises `LatticeStripe.Error` if any
  page fetch fails, so a partial enumeration surfaces as an error rather than as a
  short — and silently wrong — series.

  This is the correct entry point for a bucketed series. Stripe's `limit` defaults to
  **10** while a 31-day hourly window is 744 buckets, so a bare `list/4` over one
  returns the first ten and no indication that a sum over them is a fraction of the
  truth. For a single **total**, omit `value_grouping_window` and use `list/4` — one
  server-aggregated bucket, one request, no pagination.

  The same guards `list/4` applies fire here, and they raise at **call time** rather
  than at the first `Enum` step, so the failure lands at the call site.

  Consume it with `Enum.to_list/1` when you intend to hold every bucket in memory, or
  bound it with `Stream.take/2` when you do not — see `LatticeStripe.List` for the
  memory guidance:

      client
      |> LatticeStripe.Billing.MeterEventSummary.stream!(meter_id, params)
      |> Enum.map(& &1.aggregated_value)

  There is no non-bang `stream/4` twin — a lazy stream cannot return an error tuple at
  construction time for a failure that happens pages later.
  """
  @spec stream!(Client.t(), String.t(), map(), keyword()) :: Enumerable.t()
  def stream!(client, meter_id, params \\ %{}, opts \\ [])

  def stream!(%Client{} = client, meter_id, params, opts) do
    # These MUST be the function's literal first statements. `Stream.resource/3`
    # defers its start function, so a guard constructed lazily would not raise until
    # the stream is consumed — arbitrarily far from the caller that made the mistake.
    # Order matches `list/4`: id, then customer, then start_time, then end_time.
    validate_id!(meter_id, "stream!/4")

    Resource.require_param!(
      params,
      "customer",
      "LatticeStripe.Billing.MeterEventSummary.stream!/4 requires a customer param"
    )

    Resource.require_param!(
      params,
      "start_time",
      "LatticeStripe.Billing.MeterEventSummary.stream!/4 requires a start_time param"
    )

    Resource.require_param!(
      params,
      "end_time",
      "LatticeStripe.Billing.MeterEventSummary.stream!/4 requires an end_time param"
    )

    req = %Request{method: :get, path: path(meter_id), params: params, opts: opts}

    # The cursor state machine — base_params preservation, the starting_after cursor,
    # and the idempotency-key strip on page fetches — belongs to LatticeStripe.List and
    # is not re-grown here. This function's only job is to hand it correctly-shaped
    # state. It works unmodified because the summary carries a required top-level `id`
    # (F-01), which is what `List` matches on to derive its cursor.
    LatticeStripe.List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # DECODE
  # ---------------------------------------------------------------------------

  @doc """
  Decode a Stripe-shaped string-keyed map into a `%MeterEventSummary{}`.

  `aggregated_value` arrives as a JSON number and stays a float — it is never
  rounded and never coerced to an integer. Note the asymmetry with the write path:
  reads return a float, while `LatticeStripe.Billing.MeterEvent` writes take the
  value as a **decimal string**.

  Idempotent: applied to an already-decoded struct it returns it unchanged, and
  `from_map(nil)` returns `nil`. Unknown top-level keys land in `:extra`.
  """
  @spec from_map(map() | t() | nil) :: t() | nil
  def from_map(nil), do: nil

  # The struct clause MUST precede the `is_map/1` clause — a struct is a map.
  def from_map(%__MODULE__{} = summary), do: summary

  def from_map(map) when is_map(map) do
    {known, extra} = Map.split(map, @known_fields)

    %__MODULE__{
      id: known["id"],
      object: known["object"] || "billing.meter_event_summary",
      aggregated_value: known["aggregated_value"],
      start_time: known["start_time"],
      end_time: known["end_time"],
      meter: known["meter"],
      livemode: known["livemode"],
      extra: extra
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # The canonical path lives here once. `list/4` and the streaming variant both
  # read it, so they physically cannot diverge.
  defp path(meter_id), do: "/v1/billing/meters/#{meter_id}/event_summaries"

  # Pre-network guard: raise ArgumentError immediately on empty / nil / non-binary.
  # stripe-go ships the opposite behaviour on this exact endpoint — a nil id becomes
  # "", producing /v1/billing/meters//event_summaries and a 404 with no hint the id
  # was the problem.
  #
  # The second argument keeps the external_account.ex helper shape and carries the
  # caller's own `fun/arity` spelling, because D-09 locks the message to name the
  # arity so all four ArgumentErrors from one call site share a single grammar —
  # and D-08 specifies two message sets, `list/4`'s and `stream!/4`'s. A `stream!/4`
  # call that reported `list/4` would send the reader to the wrong doc page.
  defp validate_id!(value, _fun) when is_binary(value) and value != "", do: :ok

  defp validate_id!(_value, fun) do
    raise ArgumentError,
          "LatticeStripe.Billing.MeterEventSummary.#{fun} requires a non-empty meter id"
  end
end
