# Phase 32: File & FileLink - Pattern Map

**Mapped:** 2026-04-16
**Files analyzed:** 13 (7 new, 6 modified)
**Analogs found:** 13 / 13

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/lattice_stripe/multipart_encoder.ex` | utility | transform | `lib/lattice_stripe/form_encoder.ex` | role-match |
| `lib/lattice_stripe/file.ex` | resource | request-response | `lib/lattice_stripe/customer.ex` | exact |
| `lib/lattice_stripe/file_link.ex` | resource | CRUD | `lib/lattice_stripe/customer.ex` | exact |
| `lib/lattice_stripe/client.ex` (modified) | transport | request-response | self (existing) | exact |
| `lib/lattice_stripe/config.ex` (modified) | config | — | self (existing) | exact |
| `lib/lattice_stripe/response.ex` (modified) | model | — | self (existing) | exact |
| `lib/lattice_stripe/object_types.ex` (modified) | registry | — | self (existing) | exact |
| `test/lattice_stripe/multipart_encoder_test.exs` | test | — | `test/lattice_stripe/form_encoder_test.exs` | role-match |
| `test/lattice_stripe/file_test.exs` | test | — | `test/lattice_stripe/account_link_test.exs` | exact |
| `test/lattice_stripe/file_link_test.exs` | test | — | `test/lattice_stripe/account_link_test.exs` | exact |
| `test/integration/file_integration_test.exs` | test | — | `test/integration/account_link_integration_test.exs` | exact |
| `test/support/fixtures/file.ex` | test-fixture | — | `test/support/fixtures/account_link.ex` | exact |
| `test/support/fixtures/file_link.ex` | test-fixture | — | `test/support/fixtures/account_link.ex` | exact |

---

## Pattern Assignments

### `lib/lattice_stripe/multipart_encoder.ex` (utility, transform)

**Analog:** `lib/lattice_stripe/form_encoder.ex`

**Module skeleton pattern** (form_encoder.ex lines 1-19):
```elixir
defmodule LatticeStripe.MultipartEncoder do
  @moduledoc false

  # Mirror: FormEncoder is also @moduledoc false — internal encoding module, not public API.
  # FormEncoder.encode/1 returns a binary. MultipartEncoder.encode/4 returns {binary, boundary}.
```

**Public function spec pattern** (form_encoder.ex lines 19-26):
```elixir
  @spec encode(binary(), String.t(), map(), keyword()) :: {binary(), String.t()}
  def encode(file_binary, filename, string_fields, opts \\ []) do
    # Mirror: FormEncoder.encode/1 uses @spec and single public function
    # MultipartEncoder gets injectable :boundary option (D-06) — same determinism trick
    boundary = Keyword.get(opts, :boundary) || random_boundary()
    ...
    {body, boundary}
  end
```

**iodata assembly pattern** (client.ex lines 287-299 — `encode_uuid/1`):
```elixir
  # Mirror: Client.encode_uuid/1 assembles iodata list then calls IO.iodata_to_binary/1.
  # MultipartEncoder must do the same: accumulate parts as iodata, collect to binary at end.
  defp encode_uuid(<<a::32, b::16, c::16, d::16, e::48>>) do
    [
      Base.encode16(<<a::32>>, case: :lower),
      "-",
      ...
    ]
    |> IO.iodata_to_binary()
  end
```

**Random bytes pattern** (client.ex lines 281-284):
```elixir
  # Mirror: :crypto.strong_rand_bytes/16 already used in Client for idempotency keys.
  # Use identical pattern for boundary generation (D-06).
  defp random_boundary do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
  # Note: Client uses <<a::48, _::4, b::12, _::2, c::62>> = :crypto.strong_rand_bytes(16)
  # for UUID format. For a boundary, Base.encode16 directly is simpler and sufficient.
```

---

### `lib/lattice_stripe/file.ex` (resource, request-response)

**Analog:** `lib/lattice_stripe/customer.ex`

**Imports pattern** (customer.ex line 48):
```elixir
alias LatticeStripe.{Client, Error, List, Request, Resource, Response}
# File also needs: MultipartEncoder (via Client.upload), FileLink (for parse_links/1)
alias LatticeStripe.{Client, Error, List, ObjectTypes, Request, Resource, Response}
```

**@known_fields + defstruct pattern** (customer.ex lines 53-91):
```elixir
  @known_fields ~w[
    id object created expires_at filename links purpose size title type url
  ]

  defstruct [
    :id,
    :created,
    :expires_at,
    :filename,
    :links,
    :purpose,
    :size,
    :title,
    :type,
    :url,
    object: "file",
    extra: %{}
  ]
```

**@type t pattern** (customer.ex lines 93-128):
```elixir
  @type t :: %__MODULE__{
          id: String.t() | nil,
          object: String.t(),
          created: integer() | nil,
          expires_at: integer() | nil,
          filename: String.t() | nil,
          links: LatticeStripe.List.t() | nil,
          purpose: String.t() | nil,
          size: integer() | nil,
          title: String.t() | nil,
          type: String.t() | nil,
          url: String.t() | nil,
          extra: map()
        }
```

**create/3 pattern — DEVIATION from Customer** (customer.ex lines 164-169 shows standard pattern; File deviates per D-13):
```elixir
  # Standard Customer pattern (DO NOT USE for File.create):
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: "/v1/customers", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  # File.create MUST use Client.upload/4 instead (D-13):
  @spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    file_binary = Map.fetch!(params, "file")
    upload_params = Map.drop(params, ["file"])
    Client.upload(client, file_binary, upload_params, opts)
    |> Resource.unwrap_singular(&from_map/1)
  end
```

**retrieve/3 pattern** (customer.ex lines 187-192):
```elixir
  @spec retrieve(Client.t(), String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/files/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end
```

**list/3 pattern** (customer.ex lines 263-268):
```elixir
  @spec list(Client.t(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/files", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end
  # Note: File has NO update/4 and NO delete/3 (D-17 — files are immutable)
```

**stream!/3 pattern** (customer.ex lines 327-331):
```elixir
  @spec stream!(Client.t(), map(), keyword()) :: Enumerable.t()
  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/files", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end
```

**bang variants pattern** (customer.ex lines 368-411):
```elixir
  @spec create!(Client.t(), map(), keyword()) :: t()
  def create!(%Client{} = client, params \\ %{}, opts \\ []) do
    create(client, params, opts) |> Resource.unwrap_bang!()
  end

  @spec retrieve!(Client.t(), String.t(), keyword()) :: t()
  def retrieve!(%Client{} = client, id, opts \\ []) when is_binary(id) do
    retrieve(client, id, opts) |> Resource.unwrap_bang!()
  end

  @spec list!(Client.t(), map(), keyword()) :: Response.t()
  def list!(%Client{} = client, params \\ %{}, opts \\ []) do
    list(client, params, opts) |> Resource.unwrap_bang!()
  end
```

**from_map/1 pattern** (customer.ex lines 432-464):
```elixir
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    known = Map.take(map, @known_fields)
    # Note: use Map.take + @known_fields for extra separation (see customer.ex pattern)
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "file",
      created: map["created"],
      expires_at: map["expires_at"],
      filename: map["filename"],
      links: parse_links(map["links"]),   # NESTED LIST — see parse_links pattern below
      purpose: map["purpose"],
      size: map["size"],
      title: map["title"],
      type: map["type"],
      url: map["url"],
      extra: Map.drop(map, @known_fields)
    }
  end
```

**parse_links/1 — nested list pattern** (invoice.ex lines 1070-1079):
```elixir
  # Exact pattern from Invoice.parse_lines/1 (D-16):
  defp parse_links(nil), do: nil

  defp parse_links(%{"object" => "list"} = links_map) do
    List.from_json(links_map)
    |> Map.update!(:data, fn items ->
      Enum.map(items, &FileLink.from_map/1)
    end)
  end

  defp parse_links(other), do: other
```

**Custom Inspect pattern — URL masking** (customer.ex lines 467-489):
```elixir
defimpl Inspect, for: LatticeStripe.File do
  import Inspect.Algebra

  def inspect(file, opts) do
    # Mask url — authenticated download credential (D-19)
    # Mirror: Customer masks PII fields; File masks url
    fields = [
      id: file.id,
      object: file.object,
      purpose: file.purpose,
      size: file.size
    ]

    pairs =
      fields
      |> Enum.map(fn {k, v} ->
        concat([Atom.to_string(k), ": ", to_doc(v, opts)])
      end)
      |> Enum.intersperse(", ")

    concat(["#LatticeStripe.File<" | pairs] ++ [">"])
  end
end
```

---

### `lib/lattice_stripe/file_link.ex` (resource, CRUD)

**Analog:** `lib/lattice_stripe/customer.ex`

**Imports pattern** (customer.ex line 48):
```elixir
alias LatticeStripe.{Client, Error, List, ObjectTypes, Request, Resource, Response}
# FileLink needs ObjectTypes for expandable file field (D-15)
```

**@known_fields + defstruct** (customer.ex lines 53-91):
```elixir
  @known_fields ~w[
    id object created expired expires_at file livemode metadata url
  ]

  defstruct [
    :id,
    :created,
    :expired,
    :expires_at,
    :file,
    :livemode,
    :metadata,
    :url,
    object: "file_link",
    extra: %{}
  ]
```

**from_map/1 with expandable field** (object_types.ex lines 42-53 — `maybe_deserialize/1` pattern):
```elixir
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      object: map["object"] || "file_link",
      created: map["created"],
      expired: map["expired"],
      expires_at: map["expires_at"],
      file: ObjectTypes.maybe_deserialize(map["file"]),  # expandable (D-15)
      livemode: map["livemode"],
      metadata: map["metadata"] || %{},
      url: map["url"],
      extra: Map.drop(map, @known_fields)
    }
  end
```

**Full CRUD surface** (customer.ex lines 164-331 — all ops):
```elixir
  # FileLink has: create/3, retrieve/3, update/4, list/3, stream!/3 + bang variants
  # FileLink has NO delete/3 (D-18 — file links expire, not deleted)

  def create(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :post, path: "/v1/file_links", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  def retrieve(%Client{} = client, id, opts \\ []) when is_binary(id) do
    %Request{method: :get, path: "/v1/file_links/#{id}", params: %{}, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  def update(%Client{} = client, id, params, opts \\ []) when is_binary(id) do
    %Request{method: :post, path: "/v1/file_links/#{id}", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_singular(&from_map/1)
  end

  def list(%Client{} = client, params \\ %{}, opts \\ []) do
    %Request{method: :get, path: "/v1/file_links", params: params, opts: opts}
    |> then(&Client.request(client, &1))
    |> Resource.unwrap_list(&from_map/1)
  end

  def stream!(%Client{} = client, params \\ %{}, opts \\ []) do
    req = %Request{method: :get, path: "/v1/file_links", params: params, opts: opts}
    List.stream!(client, req) |> Stream.map(&from_map/1)
  end
```

**Custom Inspect — URL masking** (same pattern as File, customer.ex lines 467-489):
```elixir
defimpl Inspect, for: LatticeStripe.FileLink do
  import Inspect.Algebra

  def inspect(file_link, opts) do
    # Mask url — public bearer-like download credential (D-19)
    fields = [
      id: file_link.id,
      object: file_link.object,
      expired: file_link.expired,
      livemode: file_link.livemode
    ]
    # ... same pairs/concat pattern as Customer
  end
end
```

---

### `lib/lattice_stripe/client.ex` (modified — upload/4, download/2, download!/2)

**Analog:** Self — extend existing `request/2` pipeline (client.ex lines 177-237)

**defstruct addition** (client.ex lines 52-66):
```elixir
  # Add files_base_url alongside base_url in defstruct (D-03):
  defstruct [
    :api_key,
    :finch,
    :stripe_account,
    base_url: "https://api.stripe.com",
    files_base_url: "https://files.stripe.com",   # ADD THIS
    ...
  ]
```

**@type t addition** (client.ex lines 88-102):
```elixir
  @type t :: %__MODULE__{
          ...
          base_url: String.t(),
          files_base_url: String.t(),   # ADD THIS
          ...
        }
```

**build_headers/5 pattern to copy** (client.ex lines 408-421):
```elixir
  # Upload reuses this exactly, then replaces content-type:
  defp build_headers(method, api_key, api_version, stripe_account, idempotency_key) do
    base_headers = [
      {"authorization", "Bearer #{api_key}"},
      {"stripe-version", api_version},
      {"user-agent", "LatticeStripe/#{@version} ..."},
      {"x-stripe-client-user-agent", client_user_agent_json()},
      {"accept", "application/json"}
    ]
    headers = maybe_add_content_type(base_headers, method)
    headers = maybe_add_stripe_account(headers, stripe_account)
    headers = maybe_add_idempotency_key(headers, idempotency_key)
    headers
  end
  # PITFALL: maybe_add_content_type adds application/x-www-form-urlencoded for :post.
  # Upload must REPLACE (not append) content-type after build_headers/5:
  defp replace_content_type(headers, new_content_type) do
    headers
    |> Enum.reject(fn {k, _v} -> String.downcase(k) == "content-type" end)
    |> then(&[{"content-type", new_content_type} | &1])
  end
```

**resolve_idempotency_key/2 — copy unchanged** (client.ex lines 264-272):
```elixir
  # Upload reuses this helper directly (D-05):
  defp resolve_idempotency_key(method, opts) do
    user_key = Keyword.get(opts, :idempotency_key)
    cond do
      user_key != nil -> user_key
      method == :post -> generate_idempotency_key()
      true -> nil
    end
  end
```

**do_request_with_retries call pattern** (client.ex lines 228-236):
```elixir
  # Upload wraps in telemetry span and calls retry loop — same as request/2:
  LatticeStripe.Telemetry.request_span(client, req, idempotency_key, fn ->
    do_request_with_retries(
      client,
      transport_request,
      req.method,
      idempotency_key,
      effective_max_retries
    )
  end)
```

**do_request/2 pattern — fork for do_download/2** (client.ex lines 491-506):
```elixir
  # do_request/2 always JSON-decodes. do_download/2 skips decode on 2xx (D-11):
  defp do_request(client, transport_request) do
    case client.transport.request(transport_request) do
      {:ok, %{status: status, headers: resp_headers, body: body}} ->
        decode_response(client, status, resp_headers, body, params, req_opts)
      {:error, reason} ->
        {:error, %Error{type: :connection_error, message: inspect(reason)}, []}
    end
  end

  # do_download/2 — new private function, same shape but forks on 2xx:
  defp do_download(client, transport_request) do
    case client.transport.request(transport_request) do
      {:ok, %{status: status, headers: resp_headers, body: body}} ->
        request_id = extract_request_id(resp_headers)
        if status in 200..299 do
          {:ok, %Response{data: body, status: status, headers: resp_headers, request_id: request_id}}
        else
          # Error responses on binary endpoints are still JSON (D-11)
          decode_response(client, status, resp_headers, body, %{}, [])
        end
      {:error, reason} ->
        {:error, %Error{type: :connection_error, message: inspect(reason)}, []}
    end
  end
```

**classify_operation/1 — add :upload** (client.ex lines 576-591):
```elixir
  # Current pattern — add :upload and :download cases (D-05):
  defp classify_operation(%Request{method: method, path: path}) do
    segments = path |> String.replace_prefix("/v1/", "") |> String.split("/", trim: true)
    case {method, segments} do
      {:get, [_resource]} -> :list
      {:get, [_resource, "search"]} -> :search
      {:get, [_resource, _id]} -> :retrieve
      {:post, [_resource]} -> :create
      {:post, [_resource, _id]} -> :update
      {:delete, [_resource, _id]} -> :delete
      _ -> :other
    end
  end
  # Add :upload to @typedoc for operation_timeouts (client.ex lines 83-84).
  # Upload uses path "/v1/files" which would classify as :create — add explicit
  # :upload key to operation_timeouts map for distinct per-op timeout control.
```

---

### `lib/lattice_stripe/config.ex` (modified)

**Analog:** Self — add `files_base_url` alongside `base_url`

**NimbleOptions entry pattern** (config.ex lines 37-41):
```elixir
  # Copy base_url entry and adjust for files_base_url (D-03):
  base_url: [
    type: :string,
    default: "https://api.stripe.com",
    doc: "Stripe API base URL. Override for testing with stripe-mock."
  ],
  # ADD:
  files_base_url: [
    type: :string,
    default: "https://files.stripe.com",
    doc: "Stripe Files API base URL. Override for testing with stripe-mock (use same localhost:12111)."
  ],
```

---

### `lib/lattice_stripe/response.ex` (modified)

**Analog:** Self — widen `@type t` data field

**@type t pattern** (response.ex lines 43-48):
```elixir
  # Current:
  @type t :: %__MODULE__{
          data: map() | LatticeStripe.List.t() | nil,
          ...
        }
  # Widen to include binary() for download responses (D-09):
  @type t :: %__MODULE__{
          data: binary() | map() | LatticeStripe.List.t() | nil,
          ...
        }
```

---

### `lib/lattice_stripe/object_types.ex` (modified)

**Analog:** Self — add two entries to @object_map

**@object_map entry pattern** (object_types.ex lines 4-37):
```elixir
  # Copy existing entries, add after existing single-word keys (D-20):
  "file"      => LatticeStripe.File,
  "file_link" => LatticeStripe.FileLink,
```

---

### `test/lattice_stripe/multipart_encoder_test.exs` (test, unit)

**Analog:** `test/lattice_stripe/form_encoder_test.exs`

**Module structure + describe blocks** (form_encoder_test.exs lines 1-10):
```elixir
defmodule LatticeStripe.MultipartEncoderTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.MultipartEncoder

  describe "encode/4" do
    test "returns deterministic body when boundary injected" do
      {body, boundary} = MultipartEncoder.encode(
        "file-content",
        "evidence.pdf",
        %{"purpose" => "dispute_evidence"},
        boundary: "testboundary123"
      )
      assert boundary == "testboundary123"
      assert body =~ "--testboundary123\r\n"
      assert body =~ ~s(Content-Disposition: form-data; name="purpose"\r\n)
      assert body =~ "dispute_evidence"
      assert body =~ ~s(Content-Disposition: form-data; name="file"; filename="evidence.pdf"\r\n)
      assert body =~ "file-content"
      assert body =~ "--testboundary123--\r\n"
    end
    # ... additional test cases
  end
end
```

---

### `test/lattice_stripe/file_test.exs` (test, Mox-based)

**Analog:** `test/lattice_stripe/account_link_test.exs`

**Module header + setup pattern** (account_link_test.exs lines 1-10):
```elixir
defmodule LatticeStripe.FileTest do
  use ExUnit.Case, async: true

  import Mox
  import LatticeStripe.TestHelpers

  alias LatticeStripe.{File, Error}
  alias LatticeStripe.Test.Fixtures.File, as: Fixtures

  setup :verify_on_exit!
```

**Mox expect + assert pattern** (account_link_test.exs lines 52-59):
```elixir
    test "create/3 sends multipart POST to files_base_url and returns {:ok, %File{}}" do
      client = test_client()

      expect(LatticeStripe.MockTransport, :request, fn req ->
        assert req.method == :post
        assert String.starts_with?(req.url, "https://files.stripe.com")
        assert Enum.any?(req.headers, fn {k, v} ->
          k == "content-type" and String.starts_with?(v, "multipart/form-data; boundary=")
        end)
        ok_response(Fixtures.basic())
      end)

      assert {:ok, %File{purpose: "dispute_evidence"}} =
               File.create(client, %{"file" => "binary-content", "purpose" => "dispute_evidence"})
    end
```

**No-export guard pattern** (account_link_test.exs lines 140-148):
```elixir
    test "update/4, delete/3 are not exported — files are immutable" do
      refute function_exported?(LatticeStripe.File, :update, 4)
      refute function_exported?(LatticeStripe.File, :delete, 3)
    end
```

---

### `test/lattice_stripe/file_link_test.exs` (test, Mox-based)

**Analog:** `test/lattice_stripe/account_link_test.exs`

Same structure as file_test.exs. FileLink has update/4 and no delete/3. Use customer_test.exs update describe block pattern for the update tests.

---

### `test/integration/file_integration_test.exs` (test, integration)

**Analog:** `test/integration/account_link_integration_test.exs`

**Module header + setup_all stripe-mock check** (account_link_integration_test.exs lines 1-39):
```elixir
defmodule LatticeStripe.FileIntegrationTest do
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
        raise "stripe-mock not running on localhost:12111 ..."
    end
  end

  setup do
    # Upload must point files_base_url at stripe-mock localhost (D-23):
    base_client = test_integration_client()
    upload_client = %{base_client | files_base_url: "http://localhost:12111"}
    {:ok, client: base_client, upload_client: upload_client}
  end
```

**Integration test assertion style** (account_link_integration_test.exs lines 45-62):
```elixir
  test "File.create/3 with dispute_evidence purpose returns %File{}", %{upload_client: client} do
    assert {:ok, %File{id: id, purpose: purpose}} =
             File.create(client, %{
               "file" => "fake-pdf-content",
               "purpose" => "dispute_evidence"
             })
    assert is_binary(id)
    assert purpose == "dispute_evidence"
  end
  # Assertions check SHAPE (is_binary, starts_with?) not semantic values — same as other integration tests
```

---

### `test/support/fixtures/file.ex` (test fixture)

**Analog:** `test/support/fixtures/account_link.ex`

**Fixture builder pattern** (account_link.ex lines 1-19):
```elixir
defmodule LatticeStripe.Test.Fixtures.File do
  @moduledoc false

  @doc """
  Basic File fixture. Includes an unknown top-level key to exercise :extra map split.
  """
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
end
```

---

### `test/support/fixtures/file_link.ex` (test fixture)

**Analog:** `test/support/fixtures/account_link.ex`

```elixir
defmodule LatticeStripe.Test.Fixtures.FileLink do
  @moduledoc false

  def basic(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "link_test123",
        "object" => "file_link",
        "created" => 1_700_000_000,
        "expired" => false,
        "expires_at" => nil,
        "file" => "file_test123",
        "livemode" => false,
        "metadata" => %{},
        "url" => "https://files.stripe.com/links/MDB...",
        "zzz_forward_compat_field" => "extra_value"
      },
      overrides
    )
  end
end
```

---

## Shared Patterns

### Mox Transport Mock
**Source:** `test/support/test_helpers.ex` lines 6-16, `test/lattice_stripe/account_link_test.exs` lines 52-59
**Apply to:** All new test files (file_test.exs, file_link_test.exs)
```elixir
# test_client/1 helper — already available via import LatticeStripe.TestHelpers
def test_client(overrides \\ []) do
  defaults = [
    api_key: "sk_test_123",
    finch: :test_finch,
    transport: LatticeStripe.MockTransport,
    telemetry_enabled: false,
    max_retries: 0
  ]
  Client.new!(Keyword.merge(defaults, overrides))
end

# For upload tests, override files_base_url:
# client = test_client() |> then(&%{&1 | files_base_url: "http://mock-files.stripe.com"})
# Note: files_base_url is not in Config schema initially — override the struct field directly in tests.
```

### ok_response / error_response helpers
**Source:** `test/support/test_helpers.ex` lines 31-53
**Apply to:** All new unit test files
```elixir
# Both helpers already available via import LatticeStripe.TestHelpers:
def ok_response(body) do
  {:ok, %{status: 200, headers: [{"request-id", "req_test"}], body: Jason.encode!(body)}}
end

def error_response do
  {:ok, %{status: 400, headers: [{"request-id", "req_err"}], body: Jason.encode!(%{"error" => %{"type" => "invalid_request_error", "message" => "bad request"}})}}
end
```

### @known_fields + extra: %{} forward-compatibility
**Source:** `lib/lattice_stripe/customer.ex` lines 53-59, 461-462
**Apply to:** `file.ex`, `file_link.ex`
```elixir
# All resource modules use @known_fields ~w[...] string sigil (no `a`)
# from_map/1 always ends with: extra: Map.drop(map, @known_fields)
# This ensures unknown future Stripe fields are preserved, not silently dropped.
```

### Resource unwrap helpers
**Source:** `lib/lattice_stripe/resource.ex` lines 31-35, 63-68, 92-93
**Apply to:** All CRUD operations in `file.ex`, `file_link.ex`
```elixir
# Singular: Resource.unwrap_singular(&from_map/1)
# List: Resource.unwrap_list(&from_map/1)
# Bang: result |> Resource.unwrap_bang!()
```

### Integration test stripe-mock connectivity guard
**Source:** `test/integration/account_link_integration_test.exs` lines 25-35
**Apply to:** `test/integration/file_integration_test.exs`
```elixir
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
```

---

## No Analog Found

All files have analogs. No entries in this section.

---

## Metadata

**Analog search scope:** `lib/lattice_stripe/`, `test/lattice_stripe/`, `test/integration/`, `test/support/`
**Files scanned:** 18 source files read in full
**Key line references verified:** All excerpts traced to actual line numbers in codebase
**Pattern extraction date:** 2026-04-16
