defmodule LatticeStripe.Test.Fixtures.File do
  @moduledoc false

  def basic(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "file_test123",
        "object" => "file",
        "created" => 1_700_000_000,
        "expires_at" => nil,
        "filename" => "evidence.pdf",
        "links" => nil,
        "purpose" => "dispute_evidence",
        "size" => 1024,
        "title" => nil,
        "type" => "pdf",
        "url" => "https://files.stripe.com/v1/files/file_test123/contents",
        "zzz_forward_compat_field" => "extra_value"
      },
      overrides
    )
  end

  def with_links(overrides \\ %{}) do
    links = %{
      "object" => "list",
      "data" => [
        %{
          "id" => "link_test456",
          "object" => "file_link",
          "created" => 1_700_000_000,
          "expired" => false,
          "expires_at" => nil,
          "file" => "file_test123",
          "livemode" => false,
          "metadata" => %{},
          "url" => "https://files.stripe.com/links/MDB..."
        }
      ],
      "has_more" => false,
      "url" => "/v1/file_links"
    }

    basic(Map.merge(%{"links" => links}, overrides))
  end
end
