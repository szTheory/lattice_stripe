defmodule LatticeStripe.TestTelemetryHandler do
  @moduledoc false

  def handle_event(event, measurements, metadata, {pid, tag}) do
    send(pid, {tag, event, measurements, metadata})
  end
end
