defmodule LatticeStripe.DocsTruth.Fence do
  @moduledoc false

  @fence_line ~r/^```\w*/

  @doc """
  Asserts that markdown fence openers and closers are balanced.

  Lines matching `^```\\w*` toggle fence state (covers ` ```elixir ` openers and
  closing ` ``` ` lines).
  """
  def assert_balanced_fences!(path, content) do
    {open?, opened_at} =
      content
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.reduce({false, nil}, fn {line, line_no}, {open?, opened_at} ->
        if Regex.match?(@fence_line, line) do
          if open?, do: {false, opened_at}, else: {true, line_no}
        else
          {open?, opened_at}
        end
      end)

    if open? do
      raise "unclosed markdown fence in #{path} (opened near line #{opened_at})"
    end

    :ok
  end
end
