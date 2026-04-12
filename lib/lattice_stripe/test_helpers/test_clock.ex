defmodule LatticeStripe.TestHelpers.TestClock do
  @moduledoc """
  Operations on Stripe [Test Clock](https://docs.stripe.com/api/test_clocks)
  objects.

  Test Clocks let you simulate the passage of time in Stripe test mode —
  useful for exercising subscription renewals, invoice cycles, and billing
  lifecycle events without waiting real-world time. This module is the
  low-level SDK wrapper over `POST /v1/test_helpers/test_clocks` and sibling
  endpoints; for an ergonomic ExUnit helper built on top of it, see
  `LatticeStripe.Testing.TestClock`.

  ## Account limit

  Stripe enforces a hard limit of **100 test clocks per account**. If you
  hit the limit, `create/2` returns an error. The
  `LatticeStripe.Testing.TestClock` user-facing helper registers every
  created clock with a per-test ExUnit owner that cleans up on test exit,
  and `mix lattice_stripe.test_clock.cleanup` backstops SIGKILL/crash
  scenarios.

  ## Metadata support (A-13g)

  Verified against the Stripe OpenAPI spec (spec3.sdk.json) and
  `stripe/stripe-mock:latest` on 2026-04-11: `POST /v1/test_helpers/test_clocks`
  does **NOT** accept a `metadata` parameter, and the `test_helpers.test_clock`
  object schema has no `metadata` field. The request body schema exposes
  only `expand`, `frozen_time`, and `name`; the object schema exposes
  `created`, `deletes_after`, `frozen_time`, `id`, `livemode`, `name`,
  `object`, `status`, and `status_details`.

  Consequence: this struct intentionally omits `:metadata`.
  `LatticeStripe.Testing.TestClock` (Plan 13-05) falls back to
  Owner-only tracking plus an age-based Mix task for cleanup rather than
  tagging clocks with a metadata marker.

  ## Status values

  - `:ready` — clock is at its current `frozen_time` and idle
  - `:advancing` — an `advance/4` call is in progress server-side
  - `:internal_failure` — a server-side advancement failed; the clock is
    unusable and should be deleted

  Unknown server-returned status strings are passed through as raw strings
  (`String.t()`) for forward compatibility; tests should pattern-match
  against the known atoms or use `to_string/1` for display.

  ## Deletion cascades

  Deleting a test clock **cascades**: every Customer attached to the clock
  is deleted, every Subscription attached is canceled. Do not attach
  production-critical fixtures to a clock you intend to delete.

  ## Typical usage

      {:ok, clock} = LatticeStripe.TestHelpers.TestClock.create(client, %{frozen_time: System.system_time(:second)})
      {:ok, clock} = LatticeStripe.TestHelpers.TestClock.retrieve(client, clock.id)
      {:ok, _}     = LatticeStripe.TestHelpers.TestClock.delete(client, clock.id)

  The `advance/4` and `advance_and_wait/4` functions land in Plan 13-04.

  For a high-level ExUnit experience (automatic cleanup, setup callbacks,
  customer linkage), use `LatticeStripe.Testing.TestClock` instead.

  ## Operations not supported by the Stripe API

  - **update** — Stripe Test Clocks are immutable after creation. To
    advance their time, use `advance/4` (lands in Plan 13-04). To change
    metadata or name, delete and re-create.
  - **search** — Stripe's Test Clock API does not expose a `/search`
    endpoint. Use `list/3` with client-side filtering if needed.
  """

  alias LatticeStripe.{Client, Error, List, Request, Resource, Response}

  @path "/v1/test_helpers/test_clocks"

  # Known top-level fields from the Stripe test_helpers.test_clock object.
  # Used to build the struct and separate known from extra (unknown) fields.
  # NOTE: `metadata` is intentionally absent — Stripe does not expose it on
  # test clocks (verified via OpenAPI spec + stripe-mock on 2026-04-11).
  @known_fields ~w[
    id object created deletes_after frozen_time livemode name status status_details
  ]

  defstruct [
    :id,
    :created,
    :deletes_after,
    :frozen_time,
    :livemode,
    :name,
    :status,
    :status_details,
    object: "test_helpers.test_clock",
    deleted: false,
    extra: %{}
  ]

  @typedoc """
  A Stripe Test Clock object.

  See the [Stripe Test Clock API](https://docs.stripe.com/api/test_clocks/object)
  for field definitions.
  """
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          created: integer() | nil,
          deletes_after: integer() | nil,
          frozen_time: integer() | nil,
          livemode: boolean() | nil,
          name: String.t() | nil,
          status: :ready | :advancing | :internal_failure | String.t() | nil,
          status_details: map() | nil,
          deleted: boolean(),
          extra: map()
        }

  @doc """
  Converts a decoded Stripe API map to a `%TestClock{}` struct.

  Maps all known Stripe test clock fields. Any unrecognized fields are
  collected into the `extra` map so no data is silently lost.

  Per D-03, the `status` field is atomized via a whitelist: `"ready"` →
  `:ready`, `"advancing"` → `:advancing`, `"internal_failure"` →
  `:internal_failure`. Unknown values pass through as raw strings for
  forward compatibility with future Stripe enum additions.
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "test_helpers.test_clock",
      created: map["created"],
      deletes_after: map["deletes_after"],
      frozen_time: map["frozen_time"],
      livemode: map["livemode"],
      name: map["name"],
      status: atomize_status(map["status"]),
      status_details: map["status_details"],
      deleted: map["deleted"] || false,
      extra: Map.drop(map, @known_fields)
    }
  end

  # D-03 whitelist atomization — unknown values pass through as raw strings.
  defp atomize_status("ready"), do: :ready
  defp atomize_status("advancing"), do: :advancing
  defp atomize_status("internal_failure"), do: :internal_failure
  defp atomize_status(nil), do: nil
  defp atomize_status(other) when is_binary(other), do: other
  defp atomize_status(other), do: other

  # ---------------------------------------------------------------------------
  # CRUD
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new Stripe Test Clock.

  Sends `POST /v1/test_helpers/test_clocks` with the given params and returns
  the new clock as a typed `t()`.

  ## Parameters

  - `client` — A `%LatticeStripe.Client{}` struct.
  - `params` — Map of Stripe API params. Required: `:frozen_time` (integer unix
    timestamp). Optional: `:name` (string). Note: `:metadata` is NOT accepted
    by the Stripe Test Clock API (see "Metadata support" above).
  - `opts` — Per-request overrides (e.g., `:idempotency_key`).

  ## Example

      {:ok, clock} = LatticeStripe.TestHelpers.TestClock.create(client, %{
        frozen_time: System.system_time(:second),
        name: "renewal-test"
      })
  """
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: @path, params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Retrieves a Test Clock by id. GET /v1/test_helpers/test_clocks/:id."
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "#{@path}/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc "Lists Test Clocks with optional filters. GET /v1/test_helpers/test_clocks."
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: @path, params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  @doc """
  Streams Test Clocks lazily via cursor pagination.

  Returns a `Stream` that yields `%TestClock{}` items. Matches the
  Phase 12 resource pattern (`LatticeStripe.List.stream!/2` + `Stream.map`).
  """
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: @path, params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end

  @doc """
  Deletes a Test Clock by id. DELETE /v1/test_helpers/test_clocks/:id.

  **This cascades**: every Customer attached to the clock is deleted, every
  Subscription canceled. See module docs.
  """
  @spec delete(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def delete(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :delete, path: "#{@path}/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  # ---------------------------------------------------------------------------
  # Bang variants
  # ---------------------------------------------------------------------------

  def create!(%Client{} = c, p \\ %{}, o \\ []),
    do: create(c, p, o) |> Resource.unwrap_bang!()

  def retrieve!(%Client{} = c, id, o \\ []) when is_binary(id),
    do: retrieve(c, id, o) |> Resource.unwrap_bang!()

  def list!(%Client{} = c, p \\ %{}, o \\ []),
    do: list(c, p, o) |> Resource.unwrap_bang!()

  def delete!(%Client{} = c, id, o \\ []) when is_binary(id),
    do: delete(c, id, o) |> Resource.unwrap_bang!()

  # NOTE: NO update/3,4 and NO search/2,3 — Stripe Test Clock API absence.

  # ---------------------------------------------------------------------------
  # advance/4 (Plan 13-04)
  # ---------------------------------------------------------------------------

  @doc """
  Advances a Test Clock to a new `frozen_time`.

  Sends `POST /v1/test_helpers/test_clocks/:id/advance`. The returned
  clock will typically have `status: :advancing` — the server processes
  the advancement asynchronously. Use `advance_and_wait/4` (or the bang
  variant) if you need to block until the clock reaches `:ready`.

  Stripe enforces a maximum advancement of roughly two billing intervals
  of the shortest attached subscription. Advancing further in a single
  call returns a 400 error; advance in chunks instead.

  ## Parameters

  - `client` — A `%LatticeStripe.Client{}` struct
  - `id` — Test Clock id (`"clock_..."`)
  - `frozen_time` — Unix timestamp (integer) to advance TO
  - `opts` — Per-request overrides

  ## Returns

  - `{:ok, %TestClock{status: :advancing}}` (usually) on success
  - `{:error, %LatticeStripe.Error{}}` on failure
  """
  @spec advance(Client.t(), String.t(), integer(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def advance(%Client{} = client, id, frozen_time, opts \\ [])
      when is_binary(id) and is_integer(frozen_time) do
    %Request{
      method: :post,
      path: "#{@path}/#{id}/advance",
      params: %{"frozen_time" => frozen_time},
      opts: opts
    }
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  @doc """
  Bang variant of `advance/4`. Returns `%TestClock{}` on success, raises
  `LatticeStripe.Error` on failure.
  """
  @spec advance!(Client.t(), String.t(), integer(), keyword()) :: t() | no_return()
  def advance!(%Client{} = client, id, frozen_time, opts \\ [])
      when is_binary(id) and is_integer(frozen_time) do
    advance(client, id, frozen_time, opts) |> Resource.unwrap_bang!()
  end

  # ---------------------------------------------------------------------------
  # advance_and_wait/4 (Plan 13-04)
  # ---------------------------------------------------------------------------

  @default_timeout 60_000
  @default_initial_interval 500
  @default_max_interval 5_000
  @default_multiplier 1.5
  @sleep_floor 500

  @telemetry_event [:lattice_stripe, :test_clock, :advance_and_wait]

  @doc """
  Advances a Test Clock and polls until it reaches `status: :ready`.

  This is the differentiating helper for Stripe test-clock workflows: you
  almost never want to call `advance/4` directly in a test, because the
  clock returns `status: :advancing` and you have to poll for completion
  yourself. `advance_and_wait/4` does the advance + the polling + the
  terminal-failure detection + a well-behaved timeout, returning either
  a ready clock or a typed `%LatticeStripe.Error{}`.

  ## Polling strategy

  - **First poll has zero delay** — catches already-ready clocks and
    stripe-mock's instant fixture without waiting 500ms.
  - **Exponential backoff with full jitter, floored at 500ms.** Subsequent
    sleeps are `max(500, :rand.uniform(delay))` where `delay` starts at
    500ms, multiplies by 1.5 each iteration, and caps at 5000ms. Stripe's
    docs warn about tight-loop rate limits on test clocks; the 500ms floor
    is non-negotiable.
  - **Monotonic deadline.** The timeout uses `System.monotonic_time/1`, not
    system time — NTP adjustments during long test runs do not cause
    premature timeouts.
  - **Default timeout: 60 seconds.** Override via `opts[:timeout]`
    (milliseconds).

  ## Errors

  - **Timeout** — returns `{:error, %LatticeStripe.Error{type: :test_clock_timeout,
    raw_body: %{"clock_id" => _, "last_status" => _, "attempts" => _, "elapsed_ms" => _}}}`
  - **Internal failure** — returns `{:error, %LatticeStripe.Error{type: :test_clock_failed,
    raw_body: %{"clock_id" => _, "last_status" => "internal_failure", "attempts" => _}}}` —
    Stripe entered a terminal failure state, retrying will not help.
  - **HTTP failure during poll** — the underlying `retrieve/3` error propagates unchanged.

  ## Telemetry

  Emits `[:lattice_stripe, :test_clock, :advance_and_wait, :start]` and
  `[..., :stop]` via `:telemetry.span/3`. Stop metadata includes
  `%{clock_id:, status:, attempts:, outcome: :ok | :error}`. Gated by
  `client.telemetry_enabled`.

  ## Options

  - `:timeout` — total deadline in ms (default 60_000)
  - `:initial_interval` — first non-zero sleep in ms (default 500, clamped to 500 floor)
  - `:max_interval` — maximum sleep in ms (default 5_000)
  - `:multiplier` — per-iteration growth factor (default 1.5)

  ## Example

      {:ok, ready} =
        LatticeStripe.TestHelpers.TestClock.advance_and_wait(
          client,
          clock.id,
          System.system_time(:second) + 86_400 * 30
        )

      assert ready.status == :ready
  """
  @spec advance_and_wait(Client.t(), String.t(), integer(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def advance_and_wait(%Client{} = client, id, frozen_time, opts \\ [])
      when is_binary(id) and is_integer(frozen_time) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    initial = max(Keyword.get(opts, :initial_interval, @default_initial_interval), @sleep_floor)
    max_int = Keyword.get(opts, :max_interval, @default_max_interval)
    mult = Keyword.get(opts, :multiplier, @default_multiplier)

    started_at = System.monotonic_time(:millisecond)
    deadline = started_at + timeout

    backoff = %{
      delay: initial,
      max_interval: max_int,
      multiplier: mult,
      deadline: deadline,
      started_at: started_at
    }

    run = fn ->
      result =
        with {:ok, _advancing} <- advance(client, id, frozen_time, opts) do
          poll_until_ready(client, id, backoff, opts, 0)
        end

      {result, build_stop_meta(id, result)}
    end

    if client.telemetry_enabled do
      :telemetry.span(@telemetry_event, %{clock_id: id, timeout: timeout}, run)
    else
      {result, _meta} = run.()
      result
    end
  end

  @doc """
  Bang variant of `advance_and_wait/4`. Returns `%TestClock{}` on success,
  raises `LatticeStripe.Error` on failure (timeout or internal_failure).
  """
  @spec advance_and_wait!(Client.t(), String.t(), integer(), keyword()) :: t() | no_return()
  def advance_and_wait!(%Client{} = client, id, frozen_time, opts \\ []) do
    case advance_and_wait(client, id, frozen_time, opts) do
      {:ok, clock} -> clock
      {:error, %Error{} = e} -> raise e
    end
  end

  # ---------------------------------------------------------------------------
  # Internal poll loop
  # ---------------------------------------------------------------------------

  # Always poll FIRST — even on attempt 0 there is no sleep. This catches
  # already-ready clocks and stripe-mock's instant fixture (D-13b).
  #
  # `backoff` is a map with keys: :delay, :max_interval, :multiplier,
  # :deadline, :started_at — bundled to keep arity within Credo limits.
  defp poll_until_ready(client, id, backoff, opts, attempts) do
    case retrieve(client, id, opts) do
      {:ok, %__MODULE__{status: :ready} = clock} ->
        {:ok, clock}

      {:ok, %__MODULE__{status: :internal_failure}} ->
        {:error,
         %Error{
           type: :test_clock_failed,
           message: "Test clock #{id} entered internal_failure state",
           raw_body: %{
             "clock_id" => id,
             "last_status" => "internal_failure",
             "attempts" => attempts + 1
           }
         }}

      {:ok, %__MODULE__{status: status}} ->
        handle_non_ready(client, id, backoff, opts, attempts, status)

      {:error, %Error{}} = err ->
        err
    end
  end

  defp handle_non_ready(client, id, backoff, opts, attempts, status) do
    now = System.monotonic_time(:millisecond)

    if now >= backoff.deadline do
      timeout_val = Keyword.get(opts, :timeout, @default_timeout)

      {:error,
       %Error{
         type: :test_clock_timeout,
         message: "Test clock #{id} did not reach :ready within #{timeout_val}ms",
         raw_body: %{
           "clock_id" => id,
           "last_status" => to_string(status),
           "attempts" => attempts + 1,
           "elapsed_ms" => now - backoff.started_at
         }
       }}
    else
      # A-13b: max(500, :rand.uniform(delay)) — floor wins over jitter.
      sleep_ms = max(@sleep_floor, :rand.uniform(backoff.delay))
      Process.sleep(sleep_ms)
      next_delay = min(backoff.max_interval, round(backoff.delay * backoff.multiplier))
      poll_until_ready(client, id, %{backoff | delay: next_delay}, opts, attempts + 1)
    end
  end

  # Build telemetry :stop metadata from the final result tuple.
  defp build_stop_meta(clock_id, {:ok, %__MODULE__{status: status}}) do
    %{clock_id: clock_id, status: status, attempts: nil, outcome: :ok}
  end

  defp build_stop_meta(clock_id, {:error, %Error{type: type, raw_body: raw}}) do
    attempts = if is_map(raw), do: Map.get(raw, "attempts"), else: nil
    last = if is_map(raw), do: Map.get(raw, "last_status"), else: nil

    %{
      clock_id: clock_id,
      status: last,
      attempts: attempts,
      outcome: :error,
      error_type: type
    }
  end
end
