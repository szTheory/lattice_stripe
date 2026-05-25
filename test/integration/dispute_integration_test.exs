defmodule LatticeStripe.DisputeIntegrationTest do
  @moduledoc """
  Milestone-focused dispute integration coverage against stripe-mock.

  Assertions are intentionally shape-first because stripe-mock proves request
  routing and typed decoding, not persistent dispute lifecycle semantics.
  """
  use ExUnit.Case, async: false

  import LatticeStripe.TestHelpers

  @moduletag :integration

  alias LatticeStripe.{Dispute, File}

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
    upload_client = %{base_client | files_base_url: "http://localhost:12111"}

    {:ok, client: base_client, upload_client: upload_client}
  end

  test "retrieve/3 returns a typed dispute struct", %{client: client} do
    assert {:ok, %Dispute{id: id}} = Dispute.retrieve(client, "dp_test1234567890abc")
    assert is_binary(id)
  end

  test "list/3 returns a response with a dispute list", %{client: client} do
    # This is milestone smoke coverage only; stripe-mock does not preserve dispute state.
    assert {:ok, %LatticeStripe.Response{data: %LatticeStripe.List{data: disputes}}} =
             Dispute.list(client)

    assert is_list(disputes)
  end

  test "update/4 returns a typed dispute struct for metadata changes", %{client: client} do
    assert {:ok, %Dispute{id: id}} =
             Dispute.update(client, "dp_test1234567890abc", %{
               "metadata" => %{"phase_38" => "true"}
             })

    assert is_binary(id)
  end

  test "close/3 returns a typed dispute struct", %{client: client} do
    # stripe-mock is stateless, so this only proves request routing and typed decode.
    assert {:ok, %Dispute{id: id}} = Dispute.close(client, "dp_test1234567890abc")
    assert is_binary(id)
  end

  test "stages uploaded file evidence and then submits it", %{
    client: client,
    upload_client: upload_client
  } do
    # Phase 38 closes the milestone audit gap for File.create -> dispute evidence flow.
    assert {:ok, %File{id: file_id, purpose: "dispute_evidence"}} =
             File.create(upload_client, %{
               "file" => "phase-38 dispute evidence",
               "purpose" => "dispute_evidence",
               "filename" => "phase-38-evidence.txt"
             })

    evidence = %{
      "uncategorized_file" => file_id,
      "uncategorized_text" => "Uploaded through the public SDK integration flow"
    }

    # stripe-mock is stateless, so these assertions prove request/response wiring and
    # typed decoding rather than persistent dispute lifecycle semantics.
    assert {:ok,
            %Dispute{
              id: dispute_id,
              evidence: %Dispute.Evidence{uncategorized_file: returned_file_id}
            }} = Dispute.update_evidence(client, "dp_test1234567890abc", evidence)

    assert dispute_id == "dp_test1234567890abc"
    assert returned_file_id == file_id

    assert {:ok, %Dispute{id: submitted_id}} =
             Dispute.submit_evidence(client, "dp_test1234567890abc")

    assert submitted_id == dispute_id
  end
end
