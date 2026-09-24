defmodule PhoenixAdopter.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [PhoenixAdopter.Endpoint]
    Supervisor.start_link(children, strategy: :one_for_one, name: PhoenixAdopter.Supervisor)
  end
end

defmodule PhoenixAdopter.Config do
  def webhook_secret, do: Application.fetch_env!(:phoenix_adopter, :webhook_secret)
end

defmodule PhoenixAdopter.Router do
  use Phoenix.Router

  post("/checkout", PhoenixAdopter.CheckoutController, :create)
end

defmodule PhoenixAdopter.CheckoutController do
  use Phoenix.Controller, formats: [:json]

  alias LatticeStripe.Checkout.Session

  def create(conn, _params) do
    client =
      LatticeStripe.Client.new!(
        api_key: Application.fetch_env!(:phoenix_adopter, :stripe_api_key),
        transport: PhoenixAdopter.MockTransport,
        max_retries: 0,
        telemetry_enabled: false
      )

    params = %{
      "mode" => "subscription",
      "success_url" => "https://adopter.example.test/success",
      "cancel_url" => "https://adopter.example.test/cancel",
      "line_items" => [%{"price" => "price_test_monthly", "quantity" => 1}]
    }

    case Session.create(client, params) do
      {:ok, %Session{} = session} ->
        conn
        |> assign(:checkout_session, session)
        |> put_status(:created)
        |> json(%{id: session.id})

      {:error, _error} ->
        conn |> put_status(:bad_gateway) |> json(%{error: "checkout_unavailable"})
    end
  end
end

defmodule PhoenixAdopter.WebhookHandler do
  @behaviour LatticeStripe.Webhook.Handler

  @impl true
  def handle_event(%LatticeStripe.Event{} = event) do
    send(Process.get(:phoenix_adopter_test_pid), {:stripe_event, event})
    :ok
  end
end

defmodule PhoenixAdopter.ErrorJSON do
  def render(template, _assigns),
    do: %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
end

defmodule PhoenixAdopter.Endpoint do
  use Phoenix.Endpoint, otp_app: :phoenix_adopter

  plug(LatticeStripe.Webhook.Plug,
    at: "/webhooks/stripe",
    secret: {PhoenixAdopter.Config, :webhook_secret, []},
    handler: PhoenixAdopter.WebhookHandler
  )

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix_adopter, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason
  )

  plug(PhoenixAdopter.Router)
end
