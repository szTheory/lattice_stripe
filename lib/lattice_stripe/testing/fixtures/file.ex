defmodule LatticeStripe.Testing.Fixtures.File do
  @moduledoc """
  Canonical raw fixtures for Stripe File objects.
  """

  @doc """
  Returns a Stripe-shaped File map.
  """
  @spec file_json(map()) :: map()
  def file_json(overrides \\ %{}) do
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

  @doc """
  Returns a File map with an embedded `links` list.
  """
  @spec file_with_links_json(map()) :: map()
  def file_with_links_json(overrides \\ %{}) do
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

    file_json(Map.merge(%{"links" => links}, overrides))
  end
end
