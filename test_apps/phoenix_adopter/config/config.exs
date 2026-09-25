import Config

config :phoenix_adopter, PhoenixAdopter.Endpoint,
  server: false,
  secret_key_base: String.duplicate("synthetic-phoenix-secret-", 4),
  render_errors: [formats: [json: PhoenixAdopter.ErrorJSON], layout: false]

config :phoenix_adopter,
  webhook_secret: "whsec_synthetic_adopter_test_secret",
  stripe_api_key: "sk_test_synthetic_adopter_key"

config :phoenix_adopter, PhoenixAdopter.Endpoint, adapter: Phoenix.Endpoint.Cowboy2Adapter

import_config "#{config_env()}.exs"
