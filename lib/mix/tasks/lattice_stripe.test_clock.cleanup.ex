defmodule Mix.Tasks.LatticeStripe.TestClock.Cleanup do
  @moduledoc """
  Mix task backstop for cleaning up leaked test clocks.

  Intended as a safety net for SIGKILL / BEAM crash / CI timeout
  scenarios that bypass the ExUnit `on_exit` per-test cleanup. Stripe
  enforces a hard limit of 100 test clocks per account -- if leaked
  clocks pile up, every subsequent test fails at create time.

  ## Metadata limitation (A-13g)

  Stripe's Test Clock API does **not** support `metadata`, so this task
  cannot filter by a LatticeStripe-specific marker. It uses **age-based
  filtering only** (via `--older-than`) and an optional **name prefix
  filter** (via `--name-prefix`). This means the task may match clocks
  not created by LatticeStripe. Use `--dry-run` (the default) to
  preview candidates before deleting.

  ## Usage

      # Dry-run against clocks older than 1 hour (the default):
      mix lattice_stripe.test_clock.cleanup --client MyApp.StripeClient

      # Actually delete (requires explicit --yes):
      mix lattice_stripe.test_clock.cleanup --client MyApp.StripeClient --no-dry-run --yes

      # Custom age threshold + name prefix filter:
      mix lattice_stripe.test_clock.cleanup --client MyApp.StripeClient --older-than 2h --name-prefix lattice_stripe_test

  ## Flags

  - `--client` -- module name (e.g. `MyApp.StripeClient`) exposing a
    `stripe_client/0` function returning a `%LatticeStripe.Client{}`
  - `--dry-run` / `--no-dry-run` -- dry-run is on by default; pass
    `--no-dry-run` to enable deletion
  - `--older-than` -- duration with unit suffix (`30m`, `1h`, `2h`,
    `24h`, `7d`). Default: `1h`
  - `--yes` -- explicit confirmation required for destructive delete;
    default `false`
  - `--name-prefix` -- only match clocks whose `name` starts with this
    string (e.g., `"lattice_stripe_test"`)

  ## Safety

  Destructive delete requires BOTH `--yes` and `--no-dry-run`. Without
  `--yes` the task always exits after printing candidates. Without
  `--no-dry-run` the task exits after printing. This is intentional --
  see the threat model in `.planning/phases/13-billing-test-clocks`.

  If the client's `base_url` points at stripe-mock (localhost or
  127.0.0.1), the task prints a no-op message and exits cleanly.
  """

  use Mix.Task

  @shortdoc "Clean up leaked test clocks (age-based, safe by default)"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          client: :string,
          dry_run: :boolean,
          older_than: :string,
          yes: :boolean,
          name_prefix: :string
        ],
        aliases: [c: :client, n: :dry_run, y: :yes]
      )

    Mix.Task.run("app.start")

    client_spec = Keyword.get(opts, :client) || Mix.raise("--client is required")
    dry_run = Keyword.get(opts, :dry_run, true)
    yes = Keyword.get(opts, :yes, false)
    older_than_ms = parse_duration!(Keyword.get(opts, :older_than, "1h"))
    name_prefix = Keyword.get(opts, :name_prefix)

    client = resolve_client!(client_spec)

    if stripe_mock?(client) do
      Mix.shell().info("Detected stripe-mock at #{client.base_url}; no-op cleanup.")
    else
      do_cleanup(client, dry_run, yes, older_than_ms, name_prefix)
    end
  end

  defp do_cleanup(client, dry_run, yes, older_than_ms, name_prefix) do
    cleanup_opts =
      [older_than_ms: older_than_ms, delete: false] ++
        if(name_prefix, do: [name_prefix: name_prefix], else: [])

    {:ok, candidates} =
      LatticeStripe.TestHelpers.TestClock.cleanup_tagged(client, cleanup_opts)

    Mix.shell().info(
      "Found #{length(candidates)} candidate clock(s) older than #{format_duration(older_than_ms)}."
    )

    for c <- candidates do
      Mix.shell().info("  - #{c.id} (created #{c.created}, name: #{c.name || "nil"})")
    end

    cond do
      length(candidates) == 0 ->
        Mix.shell().info("Nothing to clean up.")

      dry_run ->
        Mix.shell().info(
          "Dry-run mode (default). No clocks deleted. Pass --no-dry-run --yes to delete."
        )

      not yes ->
        Mix.shell().info(
          "Refusing to delete without explicit --yes. Pass --no-dry-run --yes to confirm."
        )

      true ->
        delete_opts =
          [older_than_ms: older_than_ms, delete: true] ++
            if(name_prefix, do: [name_prefix: name_prefix], else: [])

        {:ok, %{deleted: d, failed: f}} =
          LatticeStripe.TestHelpers.TestClock.cleanup_tagged(client, delete_opts)

        Mix.shell().info("Deleted #{d} clock(s); #{f} failure(s).")
    end
  end

  @doc false
  def resolve_client!(spec) do
    mod =
      case spec do
        "Elixir." <> _ ->
          String.to_existing_atom(spec)

        _ ->
          String.to_existing_atom("Elixir." <> spec)
      end

    apply(mod, :stripe_client, [])
  rescue
    e in [ArgumentError, UndefinedFunctionError] ->
      Mix.raise(
        "Could not resolve --client #{inspect(spec)}: expected a module " <>
          "exposing stripe_client/0. (#{Exception.message(e)})"
      )
  end

  @doc false
  def stripe_mock?(%LatticeStripe.Client{base_url: url}) when is_binary(url) do
    url =~ "localhost" or url =~ "127.0.0.1" or url =~ "stripe-mock"
  end

  def stripe_mock?(_), do: false

  @doc false
  def parse_duration!(str) do
    case Regex.run(~r/^(\d+)([smhd])$/, str) do
      [_, n, "s"] -> String.to_integer(n) * 1_000
      [_, n, "m"] -> String.to_integer(n) * 60_000
      [_, n, "h"] -> String.to_integer(n) * 3_600_000
      [_, n, "d"] -> String.to_integer(n) * 86_400_000
      _ -> Mix.raise("Invalid --older-than: #{str}. Use N[smhd], e.g. 30m, 1h, 24h, 7d.")
    end
  end

  defp format_duration(ms) when is_integer(ms) do
    cond do
      rem(ms, 86_400_000) == 0 -> "#{div(ms, 86_400_000)}d"
      rem(ms, 3_600_000) == 0 -> "#{div(ms, 3_600_000)}h"
      rem(ms, 60_000) == 0 -> "#{div(ms, 60_000)}m"
      true -> "#{div(ms, 1_000)}s"
    end
  end
end
