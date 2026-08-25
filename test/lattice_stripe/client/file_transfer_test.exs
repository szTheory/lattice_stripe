defmodule LatticeStripe.Client.FileTransferTest do
  use LatticeStripe.ClientCase, async: true

  describe "upload/4" do
    test "sends multipart POST to files_base_url" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.starts_with?(req.url, "https://files.stripe.com/v1/files")

        assert Enum.any?(req.headers, fn {k, v} ->
                 k == "content-type" and String.starts_with?(v, "multipart/form-data; boundary=")
               end)

        assert is_binary(req.body)
        assert req.body =~ "dispute_evidence"
        assert req.body =~ "binary-content"

        ok_response(%{
          "id" => "file_test123",
          "object" => "file",
          "purpose" => "dispute_evidence"
        })
      end)

      assert {:ok, %Response{data: %{"object" => "file", "id" => "file_test123"}}} =
               Client.upload(client, "binary-content", %{"purpose" => "dispute_evidence"})
    end

    test "uses injectable boundary for deterministic body" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.body =~ "--fixedboundary\r\n"
        assert req.body =~ "--fixedboundary--\r\n"
        {_k, v} = Enum.find(req.headers, fn {k, _} -> k == "content-type" end)
        assert v == "multipart/form-data; boundary=fixedboundary"
        ok_response(%{"id" => "file_x", "object" => "file"})
      end)

      assert {:ok, _resp} =
               Client.upload(client, "data", %{"purpose" => "identity_document"},
                 boundary: "fixedboundary"
               )
    end

    test "does not include duplicate content-type headers" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        content_types = Enum.filter(req.headers, fn {k, _} -> k == "content-type" end)
        assert length(content_types) == 1
        ok_response(%{"id" => "file_x", "object" => "file"})
      end)

      assert {:ok, _} = Client.upload(client, "data", %{"purpose" => "dispute_evidence"})
    end

    test "includes authorization and stripe-version headers" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert Enum.any?(req.headers, fn {k, _} -> k == "authorization" end)
        assert Enum.any?(req.headers, fn {k, _} -> k == "stripe-version" end)
        ok_response(%{"id" => "file_x", "object" => "file"})
      end)

      assert {:ok, _} = Client.upload(client, "data", %{"purpose" => "test"})
    end

    test "returns {:error, %Error{}} on API error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response(400, "invalid_request_error", "bad request")
      end)

      assert {:error, %Error{}} = Client.upload(client, "data", %{"purpose" => "test"})
    end

    test "upload!/4 raises on error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response(400, "invalid_request_error", "bad request")
      end)

      assert_raise LatticeStripe.Error, fn ->
        Client.upload!(client, "data", %{"purpose" => "test"})
      end
    end

    test "uses default filename 'upload' when not specified" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.body =~ ~s(filename="upload")
        ok_response(%{"id" => "file_x", "object" => "file"})
      end)

      assert {:ok, _} = Client.upload(client, "data", %{"purpose" => "test"})
    end

    test "uses custom filename when specified" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.body =~ ~s(filename="evidence.pdf")
        ok_response(%{"id" => "file_x", "object" => "file"})
      end)

      assert {:ok, _} =
               Client.upload(client, "data", %{
                 "purpose" => "test",
                 "filename" => "evidence.pdf"
               })
    end
  end

  describe "download/2" do
    test "returns raw binary on 200" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :get
        assert String.ends_with?(req.url, "/v1/quotes/qt_123/pdf")

        {:ok,
         %{
           status: 200,
           headers: [{"content-type", "application/pdf"}, {"request-id", "req_dl"}],
           body: "pdf-binary-data"
         }}
      end)

      assert {:ok, %Response{data: "pdf-binary-data", status: 200, request_id: "req_dl"}} =
               Client.download(client, "/v1/quotes/qt_123/pdf")
    end

    test "retries a transient download failure through the binary response pipeline" do
      client = retry_client()

      expect(LatticeStripe.MockRetryStrategy, :retry?, fn 1, _context -> {:retry, 0} end)

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        error_response(500, "api_error", "Temporary failure")
      end)

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        {:ok,
         %{
           status: 200,
           headers: [{"content-type", "application/pdf"}, {"request-id", "req_retried_dl"}],
           body: "retried-pdf-binary"
         }}
      end)

      assert {:ok,
              %Response{data: "retried-pdf-binary", status: 200, request_id: "req_retried_dl"}} =
               Client.download(client, "/v1/quotes/qt_123/pdf")
    end

    test "JSON-decodes error responses on 4xx" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        {:ok,
         %{
           status: 404,
           headers: [{"request-id", "req_err"}],
           body:
             Jason.encode!(%{
               "error" => %{"type" => "invalid_request_error", "message" => "No such file"}
             })
         }}
      end)

      assert {:error, %Error{type: :invalid_request_error}} =
               Client.download(client, "/v1/files/file_xxx/contents")
    end

    test "preserves response evidence on download errors" do
      client = test_client(max_retries: 0)
      headers = [{"Request-Id", "req_download"}, {"Retry-After", "60"}]

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        {:ok,
         %{
           status: 429,
           headers: headers,
           body:
             Jason.encode!(%{
               "error" => %{"type" => "rate_limit_error", "message" => "Too many requests"}
             })
         }}
      end)

      assert {:error, %Error{headers: ^headers, retry_after: 60}} =
               Client.download(client, "/v1/files/file_xxx/contents")
    end

    test "JSON-decodes error responses on 5xx" do
      client = test_client(max_retries: 0)

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        {:ok,
         %{
           status: 500,
           headers: [{"request-id", "req_err"}],
           body: Jason.encode!(%{"error" => %{"type" => "api_error", "message" => "Internal"}})
         }}
      end)

      assert {:error, %Error{type: :api_error}} =
               Client.download(client, "/v1/some/binary")
    end

    test "uses base_url (not files_base_url) for download" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert String.starts_with?(req.url, "https://api.stripe.com")
        refute String.starts_with?(req.url, "https://files.stripe.com")
        {:ok, %{status: 200, headers: [{"request-id", "req_ok"}], body: "data"}}
      end)

      assert {:ok, _} = Client.download(client, "/v1/files/file_x/contents")
    end

    test "download!/2 raises on error" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        {:ok,
         %{
           status: 404,
           headers: [{"request-id", "req_err"}],
           body:
             Jason.encode!(%{
               "error" => %{
                 "type" => "invalid_request_error",
                 "message" => "Not found"
               }
             })
         }}
      end)

      assert_raise LatticeStripe.Error, fn ->
        Client.download!(client, "/v1/files/file_xxx")
      end
    end

    test "handles connection error" do
      client = test_client(max_retries: 0)

      expect(LatticeStripe.MockTransport, :request, fn _req ->
        {:error, %Mint.TransportError{reason: :timeout}}
      end)

      assert {:error, %Error{type: :connection_error, headers: [], retry_after: nil}} =
               Client.download(client, "/v1/files/file_x/contents")
    end
  end
end
