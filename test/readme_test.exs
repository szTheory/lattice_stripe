defmodule LatticeStripe.ReadmeTest do
  @moduledoc """
  Machine-enforces README Quick Start correctness by extracting fenced
  elixir blocks from the `## Quick Start` section and evaluating them
  against stripe-mock.

  Gated by `@moduletag :integration` so the default `mix test` invocation
  stays stripe-mock-free (Phase 9 D-01). See Phase 19 D-24..D-26.
  """

  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag :readme

  @readme Path.join(__DIR__, "../README.md") |> Path.expand()

  setup_all do
    # stripe-mock already running on :12111 per Phase 9 D-02
    start_supervised!({Finch, name: ReadmeTest.Finch})
    :ok
  end

  test "README Quick Start blocks execute against stripe-mock" do
    readme = File.read!(@readme)
    section = extract_quick_start_section(readme)

    script =
      section
      |> extract_elixir_blocks()
      |> filter_runnable_blocks()
      |> Enum.join("\n")
      |> String.replace(~s("sk_test_..."), ~s("sk_test_readme"))
      |> String.replace("MyApp.Finch", "ReadmeTest.Finch")
      |> inject_base_url()

    {_result, _binding} = Code.eval_string(script, [])
    # If Code.eval_string raises, the test fails — that IS the assertion.
  end

  defp extract_quick_start_section(md) do
    case Regex.run(~r/## Quick Start\n(.*?)(?=\n## |\z)/s, md, capture: :all_but_first) do
      [section] -> section
      nil -> raise "## Quick Start section not found in README"
    end
  end

  defp extract_elixir_blocks(section) do
    ~r/```elixir\n(.*?)```/s
    |> Regex.scan(section, capture: :all_but_first)
    |> Enum.map(&hd/1)
  end

  # The `deps do` block from mix.exs is not eval-able outside a Mix.Project
  # context. Drop any block whose first or second non-blank line contains
  # `deps do`.
  defp filter_runnable_blocks(blocks) do
    Enum.reject(blocks, fn block ->
      block
      |> String.split("\n", trim: true)
      |> Enum.take(2)
      |> Enum.any?(&String.contains?(&1, "deps do"))
    end)
  end

  defp inject_base_url(script) do
    String.replace(
      script,
      "LatticeStripe.Client.new!(",
      ~s|LatticeStripe.Client.new!(base_url: "http://localhost:12111", |
    )
  end
end
