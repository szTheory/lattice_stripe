defmodule LatticeStripe.TestTelemetryHandler do
  @moduledoc false

  def handle_event(event, measurements, metadata, {pid, tag}) do
    send(pid, {tag, event, measurements, metadata})
  end

  def handle_request_path(event, measurements, %{path: path} = metadata, {pid, tag, path}) do
    send(pid, {tag, event, measurements, metadata})
  end

  def handle_request_path(_event, _measurements, _metadata, _config), do: :ok
end
