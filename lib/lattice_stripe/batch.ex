defmodule LatticeStripe.Batch do
  @moduledoc """
  Execute multiple Stripe API calls concurrently.

  ## When to use

  `Batch.run/2` is designed for **fan-out patterns** — situations where you need
  to fetch several independent Stripe resources in parallel for a single user request.

  Typical example: loading a dashboard that needs a customer, their active
  subscriptions, and their recent invoices simultaneously:

      {:ok, results} =
        LatticeStripe.Batch.run(client, [
          {LatticeStripe.Customer, :retrieve, ["cus_123"]},
          {LatticeStripe.Subscription, :list, [%{customer: "cus_123"}]},
          {LatticeStripe.Invoice, :list, [%{customer: "cus_123"}]}
        ])

      [customer_result, subscriptions_result, invoices_result] = results

  ## What it is NOT

  `Batch.run/2` is **not** a substitute for Stripe's native batch API. Each call is
  an independent HTTP request — there is no server-side batching, no atomic
  transaction, and no reduced HTTP overhead. Use it when you want concurrent
  fan-out in your application layer; use Stripe's batch endpoint when you need
  atomic multi-resource operations.

  ## Error isolation

  Individual task failures do **not** crash the caller or cancel other tasks.
  Each slot in the result list independently resolves to `{:ok, result}` or
  `{:error, %LatticeStripe.Error{}}`.

      for result <- results do
        case result do
          {:ok, resource} -> process(resource)
          {:error, err} -> Logger.warning("Stripe call failed: \#{err.message}")
        end
      end
  """

  alias LatticeStripe.{Client, Error}

  @type task :: {module(), atom(), [term()]}
  @type result :: {:ok, term()} | {:error, Error.t()}

  @spec run(Client.t(), [task()], keyword()) :: {:ok, [result()]} | {:error, Error.t()}
  def run(%Client{} = client, tasks, opts \\ []) when is_list(tasks) do
    with :ok <- validate_tasks(tasks) do
      max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())

      results =
        tasks
        |> Task.async_stream(
          fn {mod, fun, args} ->
            try do
              apply(mod, fun, [client | args])
            rescue
              e ->
                {:error,
                 %Error{
                   type: :connection_error,
                   message: "Task raised exception: #{Exception.message(e)}"
                 }}
            end
          end,
          max_concurrency: max_concurrency,
          ordered: true,
          timeout: :infinity,
          on_timeout: :kill_task
        )
        |> Enum.map(&map_stream_result/1)

      {:ok, results}
    end
  end

  defp map_stream_result({:ok, {:ok, _} = ok}), do: ok
  defp map_stream_result({:ok, {:error, %Error{}} = err}), do: err

  defp map_stream_result({:exit, :timeout}) do
    {:error, %Error{type: :connection_error, message: "Task timed out"}}
  end

  defp map_stream_result({:exit, reason}) do
    {:error, %Error{type: :connection_error, message: "Task exited: #{inspect(reason)}"}}
  end

  defp validate_tasks([]) do
    {:error, %Error{type: :invalid_request_error, message: "tasks list cannot be empty"}}
  end

  defp validate_tasks(tasks) when is_list(tasks) do
    case Enum.find(tasks, &(not valid_mfa?(&1))) do
      nil -> :ok
      bad -> {:error, %Error{type: :invalid_request_error, message: "invalid task: #{inspect(bad)}"}}
    end
  end

  defp valid_mfa?({mod, fun, args})
       when is_atom(mod) and is_atom(fun) and is_list(args),
       do: true

  defp valid_mfa?(_), do: false
end
