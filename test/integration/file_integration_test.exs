defmodule LatticeStripe.FileIntegrationTest do
  @moduledoc """
  Integration tests for `LatticeStripe.File` and `LatticeStripe.FileLink`
  against stripe-mock.

  Run stripe-mock before these tests:

      docker run --rm -p 12111:12111 stripe/stripe-mock:latest

  These tests validate wire-level correctness against the Stripe OpenAPI spec.
  Assertions check SHAPE (is_binary, String.starts_with?) not SEMANTICS.
  """

  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.{File, FileLink, Error}

  setup_all do
    case :gen_tcp.connect(~c"localhost", 12_111, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        start_supervised!({Finch, name: LatticeStripe.IntegrationFinch})
        :ok

      {:error, _} ->
        raise "stripe-mock not running on localhost:12111 — start with: docker run -p 12111-12112:12111-12112 stripe/stripe-mock:latest"
    end
  end

  setup do
    base_client = test_integration_client()
    # Upload client points files_base_url at stripe-mock (D-23)
    upload_client = %{base_client | files_base_url: "http://localhost:12111"}
    {:ok, client: base_client, upload_client: upload_client}
  end

  describe "File" do
    test "create/3 uploads file and returns %File{}", %{upload_client: client} do
      assert {:ok, %File{id: id, purpose: purpose}} =
               File.create(client, %{
                 "file" => "fake-pdf-content",
                 "purpose" => "dispute_evidence"
               })

      assert is_binary(id)
      assert String.starts_with?(id, "file_")
      assert purpose == "dispute_evidence"
    end

    test "retrieve/3 returns %File{}", %{client: client} do
      # stripe-mock accepts any file ID for retrieve
      assert {:ok, %File{id: id}} = File.retrieve(client, "file_mock")
      assert is_binary(id)
    end

    test "list/3 returns list of files", %{client: client} do
      assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{data: files}}} =
               File.list(client)

      assert is_list(files)
    end
  end

  describe "FileLink" do
    test "create/3 returns %FileLink{}", %{client: client} do
      assert {:ok, %FileLink{id: id}} =
               FileLink.create(client, %{"file" => "file_mock"})

      assert is_binary(id)
    end

    test "retrieve/3 returns %FileLink{}", %{client: client} do
      assert {:ok, %FileLink{id: id}} = FileLink.retrieve(client, "link_mock")
      assert is_binary(id)
    end

    test "update/4 returns %FileLink{}", %{client: client} do
      assert {:ok, %FileLink{id: id}} =
               FileLink.update(client, "link_mock", %{"metadata" => %{"key" => "value"}})

      assert is_binary(id)
    end

    test "list/3 returns list of file links", %{client: client} do
      assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{data: links}}} =
               FileLink.list(client)

      assert is_list(links)
    end
  end
end
