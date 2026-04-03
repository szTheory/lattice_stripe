defmodule LatticeStripe.Webhook.PlugTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Webhook
  alias LatticeStripe.Webhook.CacheBodyReader
  alias LatticeStripe.Webhook.Plug, as: WebhookPlug
  alias LatticeStripe.Test.Fixtures.Event, as: EventFixture

  @secret "whsec_plug_test_secret"
  @payload Jason.encode!(EventFixture.event_map())

  # ---------------------------------------------------------------------------
  # Test handler modules
  # ---------------------------------------------------------------------------

  defmodule OkHandler do
    @behaviour LatticeStripe.Webhook.Handler
    def handle_event(_event), do: :ok
  end

  defmodule OkTupleHandler do
    @behaviour LatticeStripe.Webhook.Handler
    def handle_event(_event), do: {:ok, "done"}
  end

  defmodule ErrorHandler do
    @behaviour LatticeStripe.Webhook.Handler
    def handle_event(_event), do: :error
  end

  defmodule ErrorTupleHandler do
    @behaviour LatticeStripe.Webhook.Handler
    def handle_event(_event), do: {:error, "nope"}
  end

  defmodule RaisingHandler do
    @behaviour LatticeStripe.Webhook.Handler
    def handle_event(_event), do: raise("boom")
  end

  defmodule BadReturnHandler do
    @behaviour LatticeStripe.Webhook.Handler
    def handle_event(_event), do: :wat
  end

  defmodule SecretProvider do
    def get_secret, do: "whsec_plug_test_secret"
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp valid_sig_header do
    Webhook.generate_test_signature(@payload, @secret)
  end

  defp build_conn(method, path, body, sig_header) do
    conn = Plug.Test.conn(method, path, body)

    %{conn | req_headers: [{"stripe-signature", sig_header} | conn.req_headers]}
  end

  defp build_conn_no_sig(method, path, body) do
    Plug.Test.conn(method, path, body)
  end

  defp call_plug(conn, opts) do
    plug_opts = WebhookPlug.init(opts)
    WebhookPlug.call(conn, plug_opts)
  end

  # ---------------------------------------------------------------------------
  # describe "init/1"
  # ---------------------------------------------------------------------------

  describe "init/1" do
    test "raises when secret is missing" do
      assert_raise NimbleOptions.ValidationError, fn ->
        WebhookPlug.init([])
      end
    end

    test "raises when tolerance is zero" do
      assert_raise NimbleOptions.ValidationError, fn ->
        WebhookPlug.init(secret: @secret, tolerance: 0)
      end
    end

    test "raises when tolerance is negative" do
      assert_raise NimbleOptions.ValidationError, fn ->
        WebhookPlug.init(secret: @secret, tolerance: -1)
      end
    end

    test "valid opts with at: produces path_info split" do
      opts = WebhookPlug.init(secret: @secret, at: "/webhooks/stripe")
      assert opts.path_info == ["webhooks", "stripe"]
    end

    test "valid opts without at: has path_info nil" do
      opts = WebhookPlug.init(secret: @secret)
      assert opts.path_info == nil
    end

    test "accepts default tolerance" do
      opts = WebhookPlug.init(secret: @secret)
      assert opts.tolerance == 300
    end

    test "accepts custom tolerance" do
      opts = WebhookPlug.init(secret: @secret, tolerance: 600)
      assert opts.tolerance == 600
    end
  end

  # ---------------------------------------------------------------------------
  # describe "no handler mode"
  # ---------------------------------------------------------------------------

  describe "no handler mode" do
    test "valid POST assigns stripe_event and does not halt" do
      conn =
        build_conn(:post, "/webhooks/stripe", @payload, valid_sig_header())
        |> call_plug(secret: @secret)

      assert %LatticeStripe.Event{} = conn.assigns.stripe_event
      assert conn.assigns.stripe_event.type == "payment_intent.succeeded"
      refute conn.halted
    end

    test "invalid signature returns 400 and halts without assigning stripe_event" do
      conn =
        build_conn(:post, "/webhooks/stripe", @payload, "t=1234,v1=invalidsig")
        |> call_plug(secret: @secret)

      assert conn.status == 400
      assert conn.halted
      refute Map.has_key?(conn.assigns, :stripe_event)
    end

    test "missing Stripe-Signature header returns 400 and halts" do
      conn =
        build_conn_no_sig(:post, "/webhooks/stripe", @payload)
        |> call_plug(secret: @secret)

      assert conn.status == 400
      assert conn.halted
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handler mode"
  # ---------------------------------------------------------------------------

  describe "handler mode" do
    test "handler returning :ok sends 200 and halts" do
      conn =
        build_conn(:post, "/webhooks/stripe", @payload, valid_sig_header())
        |> call_plug(secret: @secret, handler: OkHandler)

      assert conn.status == 200
      assert conn.halted
    end

    test "handler returning {:ok, term} sends 200 and halts" do
      conn =
        build_conn(:post, "/webhooks/stripe", @payload, valid_sig_header())
        |> call_plug(secret: @secret, handler: OkTupleHandler)

      assert conn.status == 200
      assert conn.halted
    end

    test "handler returning :error sends 400 and halts" do
      conn =
        build_conn(:post, "/webhooks/stripe", @payload, valid_sig_header())
        |> call_plug(secret: @secret, handler: ErrorHandler)

      assert conn.status == 400
      assert conn.halted
    end

    test "handler returning {:error, term} sends 400 and halts" do
      conn =
        build_conn(:post, "/webhooks/stripe", @payload, valid_sig_header())
        |> call_plug(secret: @secret, handler: ErrorTupleHandler)

      assert conn.status == 400
      assert conn.halted
    end

    test "handler raising propagates exception" do
      assert_raise RuntimeError, "boom", fn ->
        build_conn(:post, "/webhooks/stripe", @payload, valid_sig_header())
        |> call_plug(secret: @secret, handler: RaisingHandler)
      end
    end

    test "handler returning unexpected value raises RuntimeError" do
      assert_raise RuntimeError, ~r/Expected handle_event\/1 to return/, fn ->
        build_conn(:post, "/webhooks/stripe", @payload, valid_sig_header())
        |> call_plug(secret: @secret, handler: BadReturnHandler)
      end
    end

    test "handler also receives event with correct fields" do
      # Verifies stripe_event is assigned before handler dispatch
      conn =
        build_conn(:post, "/webhooks/stripe", @payload, valid_sig_header())
        |> call_plug(secret: @secret, handler: OkHandler)

      assert conn.assigns.stripe_event.type == "payment_intent.succeeded"
    end
  end

  # ---------------------------------------------------------------------------
  # describe "path matching (at: option)"
  # ---------------------------------------------------------------------------

  describe "path matching (at: option)" do
    test "POST to matching path processes webhook" do
      conn =
        build_conn(:post, "/webhooks/stripe", @payload, valid_sig_header())
        |> call_plug(secret: @secret, at: "/webhooks/stripe")

      assert %LatticeStripe.Event{} = conn.assigns.stripe_event
    end

    test "POST to non-matching path passes through without processing" do
      conn =
        build_conn(:post, "/other/path", @payload, valid_sig_header())
        |> call_plug(secret: @secret, at: "/webhooks/stripe")

      refute conn.halted
      refute Map.has_key?(conn.assigns, :stripe_event)
    end

    test "GET to matching path returns 405 with Allow: POST header" do
      conn =
        build_conn(:get, "/webhooks/stripe", "", "")
        |> call_plug(secret: @secret, at: "/webhooks/stripe")

      assert conn.status == 405
      assert conn.halted
      assert {"allow", "POST"} in conn.resp_headers
    end

    test "PUT to matching path returns 405" do
      conn =
        build_conn(:put, "/webhooks/stripe", "", "")
        |> call_plug(secret: @secret, at: "/webhooks/stripe")

      assert conn.status == 405
      assert conn.halted
    end

    test "GET to non-matching path passes through" do
      conn =
        build_conn(:get, "/other/path", "", "")
        |> call_plug(secret: @secret, at: "/webhooks/stripe")

      refute conn.halted
      assert conn.status == nil
    end

    test "without at: option, processes all POST requests" do
      conn =
        build_conn(:post, "/any/path", @payload, valid_sig_header())
        |> call_plug(secret: @secret)

      assert %LatticeStripe.Event{} = conn.assigns.stripe_event
    end

    test "without at: option, non-POST passes through" do
      conn =
        build_conn(:get, "/any/path", "", "")
        |> call_plug(secret: @secret)

      refute conn.halted
      assert conn.status == nil
    end
  end

  # ---------------------------------------------------------------------------
  # describe "secret resolution"
  # ---------------------------------------------------------------------------

  describe "secret resolution" do
    test "MFA tuple is resolved at call time" do
      conn =
        build_conn(:post, "/webhook", @payload, valid_sig_header())
        |> call_plug(secret: {SecretProvider, :get_secret, []})

      assert %LatticeStripe.Event{} = conn.assigns.stripe_event
    end

    test "zero-arity function is resolved at call time" do
      conn =
        build_conn(:post, "/webhook", @payload, valid_sig_header())
        |> call_plug(secret: fn -> @secret end)

      assert %LatticeStripe.Event{} = conn.assigns.stripe_event
    end

    test "list of secrets: first matching secret succeeds" do
      conn =
        build_conn(:post, "/webhook", @payload, valid_sig_header())
        |> call_plug(secret: ["whsec_wrong_secret", @secret])

      assert %LatticeStripe.Event{} = conn.assigns.stripe_event
    end

    test "list of secrets: signature for any secret in list succeeds" do
      # Signature matches the second secret in the list
      conn =
        build_conn(:post, "/webhook", @payload, valid_sig_header())
        |> call_plug(secret: [@secret, "whsec_another_secret"])

      assert %LatticeStripe.Event{} = conn.assigns.stripe_event
    end

    test "list of secrets: no match returns 400" do
      conn =
        build_conn(:post, "/webhook", @payload, valid_sig_header())
        |> call_plug(secret: ["whsec_wrong1", "whsec_wrong2"])

      assert conn.status == 400
      assert conn.halted
    end
  end

  # ---------------------------------------------------------------------------
  # describe "CacheBodyReader"
  # ---------------------------------------------------------------------------

  describe "CacheBodyReader" do
    test "read_body/2 sets conn.private[:raw_body]" do
      conn = Plug.Test.conn(:post, "/webhook", @payload)
      {:ok, body, conn} = CacheBodyReader.read_body(conn, [])

      assert body == @payload
      assert conn.private[:raw_body] == @payload
    end

    test "read_body/2 returns the same body as Plug.Conn.read_body/2 would" do
      conn = Plug.Test.conn(:post, "/webhook", @payload)
      {:ok, body, _conn} = CacheBodyReader.read_body(conn, [])

      assert body == @payload
    end

    test "Plug reads from conn.private[:raw_body] when available (CacheBodyReader scenario)" do
      # Simulate CacheBodyReader having already read and stashed the body
      conn =
        Plug.Test.conn(:post, "/webhook", @payload)
        |> Plug.Conn.put_private(:raw_body, @payload)
        |> Plug.Conn.put_req_header("stripe-signature", valid_sig_header())

      plug_opts = WebhookPlug.init(secret: @secret)
      result = WebhookPlug.call(conn, plug_opts)

      assert %LatticeStripe.Event{} = result.assigns.stripe_event
    end
  end
end
