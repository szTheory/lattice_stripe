defmodule LatticeStripe.Testing.TestClock.Owner do
  @moduledoc false
  # Per-test cleanup GenServer. Tracks clock ids created during a test and
  # deletes them on `cleanup/2` (called from an `on_exit` callback).
  #
  # NOT `start_supervised!` — the Owner must outlive the test pid so
  # `on_exit` can call `delete/3` even when the test crashes or raises.
  # This mirrors `Ecto.Adapters.SQL.Sandbox.start_owner!/2` (D-13f).

  use GenServer

  alias LatticeStripe.Client
  alias LatticeStripe.TestHelpers.TestClock, as: Backend

  @spec start_owner!(keyword()) :: pid()
  def start_owner!(opts \\ []) do
    case GenServer.start(__MODULE__, opts) do
      {:ok, pid} -> pid
      {:error, reason} -> raise "Failed to start TestClock Owner: #{inspect(reason)}"
    end
  end

  @spec register(pid(), String.t()) :: :ok
  def register(owner, clock_id) when is_pid(owner) and is_binary(clock_id) do
    GenServer.call(owner, {:register, clock_id})
  end

  @spec registered(pid()) :: [String.t()]
  def registered(owner) when is_pid(owner) do
    GenServer.call(owner, :registered)
  end

  @doc """
  Best-effort delete of every registered clock, then stops the owner.

  Errors from individual `delete/3` calls are swallowed — the Mix task is
  the backstop. Called from an `on_exit` callback after the test exits.
  """
  @spec cleanup(pid(), Client.t()) :: :ok
  def cleanup(owner, %Client{} = client) when is_pid(owner) do
    try do
      if Process.alive?(owner) do
        ids = registered(owner)

        for id <- ids do
          try do
            Backend.delete(client, id)
          rescue
            _ -> :ok
          catch
            _, _ -> :ok
          end
        end

        if Process.alive?(owner), do: GenServer.stop(owner)
      end
    catch
      :exit, _ -> :ok
    end

    :ok
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    {:ok, %{clock_ids: []}}
  end

  @impl true
  def handle_call({:register, id}, _from, state) do
    {:reply, :ok, %{state | clock_ids: [id | state.clock_ids]}}
  end

  @impl true
  def handle_call(:registered, _from, state) do
    # Return in registration order (reverse so first-registered is first)
    {:reply, Enum.reverse(state.clock_ids), state}
  end
end
