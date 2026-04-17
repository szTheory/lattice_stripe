# Phase 32: File & FileLink - Research

**Researched:** 2026-04-16
**Domain:** Stripe File Upload API, multipart/form-data transport, binary download, Elixir Client extension
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Upload Transport**
- D-01: `Client.upload/4` reuses existing `Transport.request/1` callback — multipart is just a different body encoding + content-type header. No new Transport behaviour callbacks.
- D-02: Hand-roll `LatticeStripe.MultipartEncoder` (~40 lines). Zero new dependencies. RFC 2046 format — one file field + string fields.
- D-03: Add `files_base_url` field to Client struct, defaulting to `"https://files.stripe.com"`.
- D-04: `Client.upload/4` signature: `upload(client, file_binary, params, opts)` — accepts raw binary. Caller controls file reading. Params map requires `"purpose"`, optionally accepts `"filename"` (default `"upload"`) and `"file_link_data"`.
- D-05: Upload fully reuses existing retry loop and telemetry span pipeline. Add `:upload` as an operation type.
- D-06: `MultipartEncoder` accepts injectable `boundary:` option for deterministic test assertions. Production calls use `:crypto.strong_rand_bytes/16`.

**Download Transport**
- D-07: `Client.download/2` and `Client.download!/2` are separate public functions — not a flag on `request/2`.
- D-08: Extract shared request-building logic into a private `build_effective_request/2` helper.
- D-09: Reuse `%Response{}` struct with binary data in the `data` field for downloads. Widen typespec.
- D-10: Buffered only — use existing `Finch.request/3` through Transport behaviour. No streaming.
- D-11: Error responses (4xx/5xx) on binary endpoints are still JSON — only the 2xx success path returns raw binary.
- D-12: Downloads go through the same retry + telemetry pipeline.

**File & FileLink API Design**
- D-13: `File.create/3` wraps `Client.upload/4` internally. Multipart transport detail does not leak to the user.
- D-14: File purpose: pass strings only. No constants or client-side validation. Phase 15 D5 precedent.
- D-15: `LatticeStripe.FileLink` is top-level (not nested under File).
- D-16: File.links nested list deserializes to `%List{data: [%FileLink{}, ...]}` using `Invoice.parse_lines/1` pattern.
- D-17: File API surface: `create/3`, `retrieve/3`, `list/3`, `stream!/3` + bang variants. No `update`, no `delete`.
- D-18: FileLink API surface: `create/3`, `retrieve/3`, `update/4`, `list/3`, `stream!/3` + bang variants. No `delete`.
- D-19: Both modules implement custom `Inspect` masking `url` field.
- D-20: Both modules register in `object_types.ex`: `"file"` and `"file_link"`.

**Testing Strategy**
- D-21: 5-layer testing: MultipartEncoder unit, Client.upload Mox, Client.download Mox, resource Mox + fixtures, integration vs stripe-mock.
- D-22: Mox setup unchanged — upload goes through same `Transport.request/1`.
- D-23: stripe-mock supports multipart to `/v1/files` (confirmed since v0.14.0).
- D-24: Internal fixture builders `file_json/1` and `file_link_json/1` in `test/support/fixtures/`.

### Claude's Discretion
- MultipartEncoder internal implementation (iodata vs binary concatenation, CRLF handling)
- Exact `build_effective_request/2` extraction boundaries
- Test helper naming and organization within existing test structure
- ExDoc grouping for File and FileLink modules

### Deferred Ideas (OUT OF SCOPE)
- Streaming download (`Client.download_stream/3`)
- Streaming upload for files > 512MB
- Public fixture builders in `LatticeStripe.Testing` for File/FileLink
- Content-type auto-detection based on file magic bytes
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FILE-01 | Developer can upload files via multipart to `files.stripe.com` using `File.create/3` | D-01..D-06 + D-13 cover transport + API surface; MultipartEncoder + `Client.upload/4` + `files_base_url` |
| FILE-02 | Developer can retrieve and list files with auto-pagination via `stream!/3` | D-17 + existing `List.stream!/2` + `Resource.unwrap_list/2` pattern |
| FILE-03 | Developer can create, retrieve, update, list file links via `FileLink` CRUDL with `stream!/3` | D-15 + D-18 + standard resource pattern |
| FILE-04 | `Client.upload/3` handles multipart/form-data encoding with correct boundary headers | D-01..D-06 + D-08 cover this end-to-end |
| FILE-05 | `Client.download/3` handles binary responses (skips JSON decode) for file/PDF downloads | D-07..D-12 cover this end-to-end |
</phase_requirements>

---

## Summary

Phase 32 adds two orthogonal capabilities to LatticeStripe: (1) multipart upload transport for files going to `files.stripe.com`, and (2) binary download transport that skips JSON decoding on 2xx responses. Together these support the `LatticeStripe.File` and `LatticeStripe.FileLink` resource modules, which follow the standard codebase CRUDL pattern established by `Customer`, `Invoice`, `AccountLink`, and others.

The transport changes are the most novel part of this phase. `Client.upload/4` must send a `multipart/form-data` body to a different base URL (`files.stripe.com`), while everything else — auth headers, retry loop, telemetry span, idempotency keys — reuses the existing pipeline. `Client.download/2` is a new public function that runs the full request pipeline but short-circuits JSON decoding when the response is 2xx, returning raw binary in `resp.data`.

The resource modules themselves (`LatticeStripe.File`, `LatticeStripe.FileLink`) are straightforward applications of the established `@known_fields` / `defstruct` / `from_map/1` pattern. The only novelty is `File.links` nested list deserialization (same pattern as `Invoice.parse_lines/1`) and custom `Inspect` to mask authenticated download URLs.

**Primary recommendation:** Implement in 5 sequenced plans: (1) `MultipartEncoder`, (2) `Client.upload/4` + `files_base_url` + `Config` schema, (3) `Client.download/2`, (4) `LatticeStripe.File` resource module, (5) `LatticeStripe.FileLink` resource module + `object_types.ex` registration.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Multipart body encoding | Client/Transport | — | RFC 2046 encoding is request serialization; belongs with the transport layer alongside `FormEncoder` |
| Binary boundary generation | Client internals | — | `:crypto.strong_rand_bytes/16` is already used in the Client for idempotency keys |
| `files_base_url` routing | Client struct | Config NimbleOptions | Different base URL per-request, not per-transport; Client selects URL before calling Transport |
| Binary download (skip JSON) | Client `do_download/2` | Response struct | Client owns decode decisions; `do_request/2` decodes JSON, `do_download/2` returns raw binary |
| File CRUDL | `LatticeStripe.File` | Client.upload/4 | File.create/3 wraps Client.upload/4; retrieve/list/stream use standard Client.request/2 |
| FileLink CRUDL | `LatticeStripe.FileLink` | — | Standard resource; all ops via Client.request/2; no transport novelty |
| Nested links deserialization | `LatticeStripe.File.from_map/1` | — | Same tier as Invoice.parse_lines/1 — struct construction responsibility |
| URL masking in Inspect | File/FileLink modules | — | PII-equivalent: authenticated download credentials should not leak in logs |

---

## Standard Stack

### Core (No New Dependencies)

All libraries already in `mix.exs`. This phase adds zero new hex dependencies.

| Library | Version | Purpose | Role in Phase |
|---------|---------|---------|--------------|
| Finch | ~> 0.21 | HTTP transport | Executes multipart POST and binary GET via existing Transport.Finch adapter — no changes needed |
| Jason | ~> 1.4 | JSON decode | Still used for error responses on download path; unused for 2xx binary |
| :telemetry | ~> 1.0 | Instrumentation | Upload and download emit existing `[:lattice_stripe, :request, *]` events |
| :crypto | OTP stdlib | Boundary generation | `:crypto.strong_rand_bytes/16` for random multipart boundary (already used for idempotency keys) |
| NimbleOptions | ~> 1.0 | Config validation | `files_base_url` added as optional string to existing Config schema |
| Mox | ~> 1.2 | Test mocks | `LatticeStripe.MockTransport` works unchanged — Transport.request/1 contract covers multipart body |

[VERIFIED: mix.exs inspection — all packages already present]

---

## Architecture Patterns

### System Architecture Diagram

```
File.create(client, params)
         |
         v
Client.upload/4
  - extract "file" binary from params
  - build_upload_request/4
      - base_url = client.files_base_url ("https://files.stripe.com")
      - MultipartEncoder.encode(file_binary, filename, string_fields, boundary)
      - headers: Authorization + Stripe-Version + content-type: multipart/form-data; boundary=<X>
         |
         v
  telemetry span ([:lattice_stripe, :request, :start/stop/exception])
         |
         v
  retry_loop (do_request_with_retries)
         |
         v
  do_request -> Transport.request/1 -> Finch.build(:post, url, headers, multipart_binary)
         |
         v
  decode_response (JSON decode — file upload returns JSON %File{} response)
         |
         v
  {:ok, %Response{data: file_map}}
         |
         v
Resource.unwrap_singular -> File.from_map(file_map) -> {:ok, %LatticeStripe.File{}}


Client.download/2 (used by Quote.pdf/3 in Phase 36)
         |
         v
  build_effective_request/2 (shared with request/2 — headers, url, timeout)
         |
         v
  telemetry span
         |
         v
  retry_loop -> do_download/2 -> Transport.request/1
         |
         v
  on 2xx: {:ok, %Response{data: raw_binary, status: 200, ...}}
  on 4xx/5xx: JSON decode -> {:error, %Error{}}
```

### Recommended File Structure (New Files)

```
lib/lattice_stripe/
├── multipart_encoder.ex          # NEW: RFC 2046 multipart/form-data encoder (~40 lines)
├── file.ex                       # NEW: LatticeStripe.File resource module
├── file_link.ex                  # NEW: LatticeStripe.FileLink resource module
test/lattice_stripe/
├── multipart_encoder_test.exs    # NEW: unit tests with deterministic boundary
├── file_test.exs                 # NEW: Mox-based resource tests
├── file_link_test.exs            # NEW: Mox-based resource tests
test/integration/
├── file_integration_test.exs     # NEW: stripe-mock integration tests
test/support/fixtures/
├── file.ex                       # NEW: file_json/1 fixture builder
├── file_link.ex                  # NEW: file_link_json/1 fixture builder
```

**Modified files:**
```
lib/lattice_stripe/client.ex      # upload/4, download/2, download!/2, build_effective_request/2
lib/lattice_stripe/config.ex      # add files_base_url to NimbleOptions schema
lib/lattice_stripe/response.ex    # widen @type t data field for binary
lib/lattice_stripe/object_types.ex # register "file" and "file_link"
```

### Pattern 1: MultipartEncoder

**What:** Encodes a file binary + string fields into RFC 2046 multipart/form-data body.
**When to use:** `Client.upload/4` only — not a general-purpose encoder.

```elixir
# Source: CONTEXT.md D-02, D-06; pattern mirrors stripe-python multipart encoder
defmodule LatticeStripe.MultipartEncoder do
  @moduledoc false

  @crlf "\r\n"

  @doc """
  Encodes file binary + string fields as multipart/form-data body.

  Returns {encoded_binary, boundary} where boundary is either the injected
  value (for tests) or a random hex string (for production).

  Options:
    - :boundary - injectable for deterministic test assertions (D-06)
  """
  @spec encode(binary(), String.t(), map(), keyword()) :: {binary(), String.t()}
  def encode(file_binary, filename, string_fields, opts \\ []) do
    boundary = Keyword.get(opts, :boundary) || random_boundary()

    parts =
      string_fields
      |> Enum.map(fn {key, value} -> text_part(boundary, to_string(key), to_string(value)) end)

    file_part = file_part(boundary, file_binary, filename)
    closing = "--#{boundary}--#{@crlf}"

    body = IO.iodata_to_binary([parts, file_part, closing])
    {body, boundary}
  end

  defp text_part(boundary, name, value) do
    [
      "--#{boundary}#{@crlf}",
      "Content-Disposition: form-data; name=\"#{name}\"#{@crlf}",
      @crlf,
      value,
      @crlf
    ]
  end

  defp file_part(boundary, binary, filename) do
    [
      "--#{boundary}#{@crlf}",
      "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"#{@crlf}",
      "Content-Type: application/octet-stream#{@crlf}",
      @crlf,
      binary,
      @crlf
    ]
  end

  defp random_boundary do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
```

### Pattern 2: Client.upload/4

**What:** New public function on Client. Builds multipart request to `files_base_url`, runs full retry + telemetry pipeline, returns JSON-decoded response (file upload returns JSON).
**When to use:** Called by `File.create/3`. Not for direct user use typically.

Key points from D-01 and D-08:
- Shares `build_headers/5` with `request/2` (Authorization, Stripe-Version, User-Agent, Accept)
- Overrides content-type to `multipart/form-data; boundary=<X>` (replaces `application/x-www-form-urlencoded`)
- Uses `client.files_base_url` not `client.base_url`
- Generates idempotency key (POST, same logic as `request/2`)
- Adds `:upload` to `classify_operation/1` for per-op timeout support
- Response is JSON (file upload endpoint returns a File object) — reuses `do_request/2` not `do_download/2`

```elixir
# Source: CONTEXT.md D-01, D-04, D-05, D-08
@spec upload(t(), binary(), map(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
def upload(%__MODULE__{} = client, file_binary, params, opts \\ []) do
  filename = Map.get(params, "filename", "upload")
  string_fields =
    params
    |> Map.drop(["file", "filename"])
    |> Enum.into(%{})

  {body, boundary} = MultipartEncoder.encode(file_binary, filename, string_fields,
    Keyword.take(opts, [:boundary]))

  url = client.files_base_url <> "/v1/files"
  idempotency_key = resolve_idempotency_key(:post, opts)

  effective_api_key = Keyword.get(opts, :api_key, client.api_key)
  effective_api_version = Keyword.get(opts, :stripe_version, client.api_version)
  effective_timeout = resolve_upload_timeout(client, opts)
  effective_stripe_account = Keyword.get(opts, :stripe_account, client.stripe_account)
  effective_max_retries = Keyword.get(opts, :max_retries, client.max_retries)

  headers =
    build_headers(:post, effective_api_key, effective_api_version,
                  effective_stripe_account, idempotency_key)
    |> replace_content_type("multipart/form-data; boundary=#{boundary}")

  transport_opts = [finch: client.finch, timeout: effective_timeout]

  transport_request = %{
    method: :post,
    url: url,
    headers: headers,
    body: body,
    opts: transport_opts,
    _params: params,
    _req_opts: opts
  }

  upload_req = %Request{method: :post, path: "/v1/files", params: params, opts: opts}

  LatticeStripe.Telemetry.request_span(client, upload_req, idempotency_key, fn ->
    do_request_with_retries(client, transport_request, :post, idempotency_key, effective_max_retries)
  end)
end
```

### Pattern 3: Client.download/2

**What:** New public function. Runs standard request pipeline but forks after transport response — 2xx returns raw binary, not JSON-decoded.
**When to use:** `File` binary downloads, `Quote.pdf/3` (Phase 36).

Key implementation note from D-11:
- 2xx: `{:ok, %Response{data: resp_body_binary, status: status, headers: headers, request_id: request_id}}`
- 4xx/5xx: `decode_response/6` (JSON decode) → `{:error, %Error{}}`

```elixir
# Source: CONTEXT.md D-07, D-09, D-11, D-12
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

### Pattern 4: LatticeStripe.File resource module

**What:** Standard resource module following `Customer` / `AccountLink` pattern.
**Key differences from normal resources:**
- `create/3` calls `Client.upload/4` instead of `Client.request/2`
- `File.links` field uses `parse_links/1` (mirrors `Invoice.parse_lines/1`)
- Custom `Inspect` masks `url` (authenticated download credential)
- No `update/4`, no `delete/3` (files are immutable)

Stripe File object fields (verified):
```
id, object, created, expires_at, filename, links, purpose, size, title, type, url
```

```elixir
# File.create/3 — wraps Client.upload/4, not Client.request/2 (D-13)
@spec create(Client.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
def create(%Client{} = client, params \\ %{}, opts \\ []) do
  file_binary = Map.fetch!(params, "file")
  upload_params = Map.drop(params, ["file"])
  Client.upload(client, file_binary, upload_params, opts)
  |> Resource.unwrap_singular(&from_map/1)
end
```

### Pattern 5: File.links nested deserialization

**What:** `File.links` is a nested Stripe list object. Same pattern as `Invoice.parse_lines/1`.

```elixir
# Source: lib/lattice_stripe/invoice.ex parse_lines/1 — exact same pattern (D-16)
defp parse_links(nil), do: nil

defp parse_links(%{"object" => "list"} = links_map) do
  List.from_json(links_map)
  |> Map.update!(:data, fn items ->
    Enum.map(items, &FileLink.from_map/1)
  end)
end

defp parse_links(other), do: other
```

### Pattern 6: Config schema addition

**What:** Add `files_base_url` to NimbleOptions schema in `Config`.

```elixir
# Source: lib/lattice_stripe/config.ex — add alongside base_url (D-03)
files_base_url: [
  type: :string,
  default: "https://files.stripe.com",
  doc: "Stripe Files API base URL. Override for testing with stripe-mock (use same localhost:12111)."
],
```

And add to `Client` struct:
```elixir
# In Client defstruct — add alongside base_url
files_base_url: "https://files.stripe.com",
```

### Pattern 7: object_types.ex registration

```elixir
# Add to @object_map in lib/lattice_stripe/object_types.ex (D-20)
"file"      => LatticeStripe.File,
"file_link" => LatticeStripe.FileLink,
```

### Pattern 8: FileLink resource

Stripe FileLink object fields (verified):
```
id, object, created, expired, expires_at, file, livemode, metadata, url
```

`file` field is expandable — use `ObjectTypes.maybe_deserialize/1` in `from_map/1`.

```elixir
# In FileLink.from_map/1 — file field is expandable (D-15)
file: ObjectTypes.maybe_deserialize(map["file"]),
```

### Anti-Patterns to Avoid

- **Passing binary files through FormEncoder:** `FormEncoder.encode/1` is string-only. Never pass a binary through it — it must go through `MultipartEncoder`.
- **Using `Client.request/2` for uploads:** `File.create/3` must internally use `Client.upload/4`, not `Client.request/2` — the standard request path sets `content-type: application/x-www-form-urlencoded` and sends to `api.stripe.com`.
- **JSON-decoding download successes:** `do_download/2` must return raw binary on 2xx. Do NOT pass the binary through `json_codec.decode/1` — it will crash.
- **Calling `Map.fetch!` on `params["file"]` in `Client.upload/4`:** The file binary extraction should happen in `File.create/3` before calling `Client.upload/4`, per D-04 signature (`upload(client, file_binary, params, opts)`).
- **Streaming multipart body through Transport:** Finch supports streaming uploads but the Stripe max file size is 16MB. Buffered binary (iodata collected to binary) is correct and simpler. Do not introduce streaming complexity (deferred per D-10).
- **Content-Type header duplication:** `build_headers/5` adds `application/x-www-form-urlencoded` for POST methods. The upload path must REPLACE (not append) that header with the multipart content-type. Appending would send two `content-type` headers.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Boundary generation | Custom PRNG or UUID | `:crypto.strong_rand_bytes/16` | Already used in Client for idempotency keys; BEAM stdlib; cryptographically random |
| Retry loop for uploads | Separate upload retry | Existing `do_request_with_retries/7` | All retry semantics (Stripe-Should-Retry, delay, max_retries) are identical for uploads |
| Telemetry for uploads | Separate upload span | Existing `Telemetry.request_span/4` | `request_span/4` takes a `%Request{}` for metadata — pass a synthetic upload request struct |
| Idempotency key for uploads | Skip idempotency | Existing `resolve_idempotency_key/2` | Stripe supports idempotency on file uploads; reuse existing logic |
| Binary response struct | New `%BinaryResponse{}` | Existing `%Response{}` with widened typespec | Users already know `resp.data`; widen typespec to `binary() \| map() \| List.t() \| nil` |

**Key insight:** Every novel behavior in this phase (multipart body, binary response) requires changes at the Client level, but the surrounding pipeline (auth, retry, telemetry, timeouts) is fully reused. The MultipartEncoder is the only genuinely new module.

---

## Common Pitfalls

### Pitfall 1: Content-Type Header Collision

**What goes wrong:** `build_headers/5` unconditionally adds `content-type: application/x-www-form-urlencoded` for all POST methods. If upload headers are built with `build_headers/5` and then the multipart content-type is prepended, two `content-type` headers are sent. Stripe (and some intermediate proxies) will reject or misinterpret the request.

**Why it happens:** `maybe_add_content_type/2` in `Client` appends to the header list without checking for an existing content-type.

**How to avoid:** After building base headers, replace the `content-type` header using a `replace_content_type/2` helper that removes any existing `content-type` before prepending the multipart value.

**Warning signs:** Integration test returns 400 "invalid content type" or "malformed multipart" from stripe-mock.

### Pitfall 2: files_base_url Not Propagated to Client Struct

**What goes wrong:** `Config.validate!/1` validates `files_base_url` but `Client.new!/1` does `struct!(__MODULE__, validated)` — if the field is missing from `Client`'s `defstruct`, it silently fails with an `ArgumentError` at struct construction time.

**Why it happens:** Both `Config` schema and `Client` `defstruct` must be updated in tandem.

**How to avoid:** Add `files_base_url: "https://files.stripe.com"` to `Client`'s `defstruct` and the `@type t` typespec. Verify in a unit test that `Client.new!(...)` produces a struct with the correct default.

**Warning signs:** `** (KeyError) key :files_base_url not found` at `Client.new!` call.

### Pitfall 3: Binary Body Corruption via iodata vs binary

**What goes wrong:** Multipart body contains the raw file binary. If parts are accumulated as iodata and then serialized incorrectly (e.g., passed directly to Finch without `IO.iodata_to_binary/1`), binary content may be mangled.

**Why it happens:** Elixir's iodata is a list of binaries/iolists. Finch accepts binary body, not iodata. If you pass a nested list, Finch will raise `ArgumentError`.

**How to avoid:** Always call `IO.iodata_to_binary/1` on the assembled iodata list before returning from `MultipartEncoder.encode/4`. The Transport contract expects `body: binary() | nil`.

**Warning signs:** `** (ArgumentError) not an iodata term` from Finch, or corrupted file content in stripe-mock response.

### Pitfall 4: JSON Error Decode on Binary Download Path

**What goes wrong:** `do_download/2` receives a 400 error from Stripe (e.g., invalid file ID). The body is JSON. If you mistakenly return the raw binary body as the error, callers get a binary error body instead of a `%Error{}` struct.

**Why it happens:** The "skip JSON decode" logic applies ONLY to 2xx responses. Error bodies on binary endpoints are still standard Stripe JSON error objects.

**How to avoid:** In `do_download/2`, check `status in 200..299`. On 2xx: return raw binary in `%Response{data: body}`. On everything else: call the existing `decode_response/6` function (D-11).

**Warning signs:** Pattern match on `{:error, %Error{}}` fails because `error.raw_body` contains a binary instead of a decoded map.

### Pitfall 5: File.links Circular Dependency

**What goes wrong:** `File.from_map/1` calls `FileLink.from_map/1` (via `parse_links/1`). If `file.ex` compiles before `file_link.ex`, the compiler raises an undefined function error.

**Why it happens:** Module compilation order in Elixir is determined by dependency graph, but within a mix project all files in `lib/` compile together. Circular module references at function-call level are resolved at runtime, not compile time — but if `FileLink` is not yet defined when `File` is loaded, a `UndefinedFunctionError` occurs at runtime (not compile time).

**How to avoid:** Ensure `FileLink` is defined. In practice this is not a circular dependency — `File` calls `FileLink.from_map/1`, but `FileLink` does not call `File.from_map/1` at struct construction time (the `file` field uses `ObjectTypes.maybe_deserialize/1` which resolves at runtime via the object map). No structural issue.

**Warning signs:** `(UndefinedFunctionError) function LatticeStripe.FileLink.from_map/1 is undefined` — only if file_link.ex is accidentally omitted.

### Pitfall 6: Boundary Not in Content-Type Header

**What goes wrong:** Stripe parses the boundary from the `Content-Type` header: `multipart/form-data; boundary=<X>`. If the boundary in the header doesn't match the boundary used in the body parts, Stripe returns 400.

**Why it happens:** The boundary is generated in `MultipartEncoder.encode/4` and must be threaded back to the header. If the caller generates a boundary independently, a mismatch occurs.

**How to avoid:** `MultipartEncoder.encode/4` returns `{body, boundary}`. The caller (Client.upload/4) uses the returned boundary value when building the content-type header, never an independently generated value.

---

## Code Examples

### MultipartEncoder: Deterministic Boundary for Tests

```elixir
# Source: CONTEXT.md D-06 — boundary injection for test assertions
test "encodes file field with boundary" do
  {body, boundary} = MultipartEncoder.encode(
    "file-content",
    "evidence.pdf",
    %{"purpose" => "dispute_evidence"},
    boundary: "testboundary123"
  )

  assert boundary == "testboundary123"
  assert body =~ "--testboundary123\r\n"
  assert body =~ "Content-Disposition: form-data; name=\"purpose\"\r\n"
  assert body =~ "dispute_evidence"
  assert body =~ "Content-Disposition: form-data; name=\"file\"; filename=\"evidence.pdf\"\r\n"
  assert body =~ "file-content"
  assert body =~ "--testboundary123--\r\n"
end
```

### Client.upload/4: Mox-based unit test

```elixir
# Source: test/lattice_stripe/client_test.exs pattern
test "upload/4 sends multipart POST to files_base_url" do
  client = test_client()

  expect(LatticeStripe.MockTransport, :request, fn req ->
    assert req.method == :post
    assert String.starts_with?(req.url, "https://files.stripe.com")
    assert Enum.any?(req.headers, fn {k, v} ->
      k == "content-type" and String.starts_with?(v, "multipart/form-data; boundary=")
    end)
    assert is_binary(req.body)
    ok_response(%{"id" => "file_test123", "object" => "file", "purpose" => "dispute_evidence"})
  end)

  assert {:ok, %Response{data: %{"object" => "file"}}} =
    Client.upload(client, "binary-content", %{"purpose" => "dispute_evidence"}, [])
end
```

### Client.download/2: Mox-based unit test

```elixir
test "download/2 returns raw binary on 200" do
  client = test_client()

  expect(LatticeStripe.MockTransport, :request, fn _req ->
    {:ok, %{status: 200, headers: [{"content-type", "application/pdf"}], body: "pdf-binary-data"}}
  end)

  assert {:ok, %Response{data: "pdf-binary-data", status: 200}} =
    Client.download(client, "/v1/some/file")
end

test "download/2 JSON-decodes error responses" do
  client = test_client()

  expect(LatticeStripe.MockTransport, :request, fn _req ->
    {:ok, %{
      status: 404,
      headers: [{"request-id", "req_test"}],
      body: Jason.encode!(%{"error" => %{"type" => "invalid_request_error", "message" => "No such file"}})
    }}
  end)

  assert {:error, %Error{type: :invalid_request_error}} = Client.download(client, "/v1/files/file_xxx")
end
```

### Stripe Integration: File upload to stripe-mock

```elixir
# stripe-mock accepts multipart to /v1/files since v0.14.0 (D-23)
# Integration test uses files_base_url pointed at localhost:12111
test "File.create/3 with dispute_evidence purpose returns %File{}", %{client: client} do
  # Build a client that sends uploads to stripe-mock
  upload_client = %{client | files_base_url: "http://localhost:12111"}

  file_binary = "fake-pdf-content"

  assert {:ok, %LatticeStripe.File{id: id, purpose: purpose}} =
    LatticeStripe.File.create(upload_client, %{
      "file" => file_binary,
      "purpose" => "dispute_evidence"
    })

  assert is_binary(id)
  assert purpose == "dispute_evidence"
end
```

---

## Stripe API Reference (Verified)

### File Object Fields

[VERIFIED: https://docs.stripe.com/api/files/object]

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | `file_...` prefix |
| `object` | string | `"file"` |
| `created` | integer | Unix timestamp |
| `expires_at` | integer \| nil | When file is no longer available |
| `filename` | string \| nil | Suitable name for filesystem |
| `links` | object \| nil | Nested list of FileLink objects |
| `purpose` | string | enum: `dispute_evidence`, `business_logo`, etc. |
| `size` | integer | Bytes |
| `title` | string \| nil | Document title |
| `type` | string \| nil | `"csv"`, `"pdf"`, `"jpg"`, `"png"` etc. |
| `url` | string \| nil | Authenticated download URL (mask in Inspect) |

### FileLink Object Fields

[VERIFIED: https://docs.stripe.com/api/file_links/object]

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | `link_...` prefix |
| `object` | string | `"file_link"` |
| `created` | integer | Unix timestamp |
| `expired` | boolean | Whether link has expired |
| `expires_at` | integer \| nil | Unix timestamp when link expires |
| `file` | string \| `%File{}` | Expandable reference to File object |
| `livemode` | boolean | |
| `metadata` | map | |
| `url` | string \| nil | Public download URL (mask in Inspect — bearer-like credential) |

### File Upload Endpoint

[VERIFIED: https://docs.stripe.com/api/files/create]

- **URL:** `POST https://files.stripe.com/v1/files`
- **Content-Type:** `multipart/form-data`
- **Required fields:** `file` (binary), `purpose` (string enum)
- **Optional fields:** `file_link_data` (nested object for creating a FileLink on upload)
- **Auth:** `Authorization: Bearer sk_...` (same as other endpoints)
- **Response:** Standard Stripe File JSON object

### File List/Retrieve Endpoints

- `GET https://api.stripe.com/v1/files` — list (standard base URL)
- `GET https://api.stripe.com/v1/files/:id` — retrieve (standard base URL)

Note: Only the **create** (upload) endpoint uses `files.stripe.com`. Retrieve and list use `api.stripe.com`. [VERIFIED: Stripe docs + official SDK source patterns in CONTEXT.md D-03]

### FileLink Endpoints

All use standard `api.stripe.com`:
- `POST /v1/file_links` — create
- `GET /v1/file_links/:id` — retrieve
- `POST /v1/file_links/:id` — update
- `GET /v1/file_links` — list

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|-----------------|--------|
| Separate Transport callback for multipart | Reuse `Transport.request/1` with different body encoding | Zero custom transport changes; all transports get upload support |
| Separate `%BinaryResponse{}` struct | Widen `%Response{}` typespec: `data: binary() \| map() \| List.t() \| nil` | No user-visible API surface change |
| Runtime content-type negotiation | Explicit `do_download/2` private function | Code is clearer about intent; no flag-based branching in hot path |

**No deprecated approaches apply to this phase.** All patterns are established codebase conventions being extended.

---

## Environment Availability

| Dependency | Required By | Available | Notes |
|------------|------------|-----------|-------|
| stripe-mock | Integration tests (D-23) | Requires Docker | `docker run --rm -p 12111:12111 stripe/stripe-mock:latest` |
| `:crypto` | MultipartEncoder boundary generation | Always | OTP stdlib, no installation |
| Finch | Transport | Already in mix.exs | v0.21+ |

**stripe-mock multipart support:** Confirmed since v0.14.0 per CONTEXT.md D-23. Integration tests point `files_base_url` at `localhost:12111` (same port as `base_url`).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (OTP stdlib) |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/lattice_stripe/multipart_encoder_test.exs test/lattice_stripe/file_test.exs test/lattice_stripe/file_link_test.exs` |
| Full suite command | `mix test` |
| Integration tests | `mix test --include integration` (requires stripe-mock running) |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FILE-01 | `File.create/3` encodes multipart and returns `%File{}` | Unit (Mox) + Integration | `mix test test/lattice_stripe/file_test.exs` | Wave 0 |
| FILE-02 | `File.retrieve/3`, `File.list/3`, `File.stream!/3` work | Unit (Mox) | `mix test test/lattice_stripe/file_test.exs` | Wave 0 |
| FILE-03 | Full FileLink CRUDL + stream | Unit (Mox) | `mix test test/lattice_stripe/file_link_test.exs` | Wave 0 |
| FILE-04 | `Client.upload/4` sends multipart POST with boundary header | Unit (Mox) | `mix test test/lattice_stripe/client_test.exs` | Exists (append) |
| FILE-05 | `Client.download/2` returns raw binary on 2xx, JSON error on 4xx | Unit (Mox) | `mix test test/lattice_stripe/client_test.exs` | Exists (append) |

### Sampling Rate

- **Per task commit:** `mix test test/lattice_stripe/multipart_encoder_test.exs test/lattice_stripe/client_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green + integration tests pass before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/lattice_stripe/multipart_encoder_test.exs` — covers FILE-04 (encoding correctness)
- [ ] `test/lattice_stripe/file_test.exs` — covers FILE-01, FILE-02
- [ ] `test/lattice_stripe/file_link_test.exs` — covers FILE-03
- [ ] `test/integration/file_integration_test.exs` — covers FILE-01..FILE-03 against stripe-mock
- [ ] `test/support/fixtures/file.ex` — `file_json/1` fixture builder
- [ ] `test/support/fixtures/file_link.ex` — `file_link_json/1` fixture builder

---

## Open Questions

1. **`classify_operation/1` for upload path**
   - What we know: Current `classify_operation/1` pattern-matches on `%Request{method:, path:}`. Upload has `method: :post`, `path: "/v1/files"` — matches `:create`.
   - What's unclear: D-05 says add `:upload` as an operation type. Does `:upload` need its own timeout key, or should it fall through to `:create`?
   - Recommendation: Add `:upload` as a distinct key in `operation_timeouts` map and in `classify_operation/1`. Document the key in `@typedoc` for `operation_timeouts`. Default: falls back to `client.timeout` if `:upload` not set.

2. **`build_effective_request/2` extraction scope**
   - What we know: D-08 calls for extracting shared request-building logic. Currently `request/2` has ~30 lines of setup before calling `do_request_with_retries`. Upload and download need the same headers, timeout resolution, idempotency resolution.
   - What's unclear: How much of the setup to move into `build_effective_request/2` vs. keeping inline. The URL construction differs (base_url vs files_base_url for uploads).
   - Recommendation: Extract auth/header/timeout/idempotency resolution into `build_effective_request/2`. Pass `base_url` as a parameter. This is a Claude's Discretion item (CONTEXT.md) — implement as the planner/implementer sees fit.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | stripe-mock accepts multipart to `/v1/files` — integration tests will pass without special configuration | Standard Stack / Integration | Integration tests fail; need to skip or stub file create integration test. Low risk — CONTEXT.md D-23 confirms this. |
| A2 | `files.stripe.com` and `api.stripe.com` both accept the same `Authorization: Bearer` header format | Architecture Patterns (upload transport) | Upload returns 401. Extremely low risk — all official Stripe SDKs use the same bearer token. [CITED: docs.stripe.com/api/files/create] |

---

## Sources

### Primary (HIGH confidence)
- `lib/lattice_stripe/client.ex` — Full Client pipeline; `build_headers/5`, `do_request/2`, retry loop, `classify_operation/1`, `build_url_and_body/4` [VERIFIED: codebase read]
- `lib/lattice_stripe/form_encoder.ex` — MultipartEncoder will mirror this module structure [VERIFIED: codebase read]
- `lib/lattice_stripe/transport.ex` — `Transport.request/1` callback contract [VERIFIED: codebase read]
- `lib/lattice_stripe/transport/finch.ex` — Finch adapter; accepts binary body unchanged [VERIFIED: codebase read]
- `lib/lattice_stripe/invoice.ex` parse_lines/1 — exact pattern for `File.parse_links/1` [VERIFIED: codebase read]
- `lib/lattice_stripe/object_types.ex` — Registration pattern [VERIFIED: codebase read]
- `lib/lattice_stripe/config.ex` — NimbleOptions schema pattern for new `files_base_url` field [VERIFIED: codebase read]
- `lib/lattice_stripe/response.ex` — Response struct typespec [VERIFIED: codebase read]
- `lib/lattice_stripe/resource.ex` — `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1` [VERIFIED: codebase read]
- [Stripe File Object API](https://docs.stripe.com/api/files/object) — All File fields [VERIFIED: WebFetch]
- [Stripe FileLink Object API](https://docs.stripe.com/api/file_links/object) — All FileLink fields [VERIFIED: WebFetch]
- [Stripe File Upload Endpoint](https://docs.stripe.com/api/files/create) — URL, content-type, required params [VERIFIED: WebFetch]

### Secondary (MEDIUM confidence)
- CONTEXT.md D-01..D-24 — All implementation decisions locked by user [VERIFIED: file read]
- `test/lattice_stripe/client_test.exs` — Test helper patterns, Mox setup [VERIFIED: codebase read]
- `test/integration/account_link_integration_test.exs` — Integration test boilerplate pattern [VERIFIED: codebase read]
- `test/test_helper.exs` — Mox mock definitions [VERIFIED: codebase read]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages already in mix.exs; no new dependencies
- Architecture: HIGH — all decisions locked in CONTEXT.md; patterns verified in codebase
- Stripe API fields: HIGH — verified from official docs
- Pitfalls: HIGH — derived from reading actual Client code and understanding where the new paths deviate
- Test patterns: HIGH — existing test infrastructure fully covers the new patterns

**Research date:** 2026-04-16
**Valid until:** 2026-05-16 (stable Stripe API; 30 days)
