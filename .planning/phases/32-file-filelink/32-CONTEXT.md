# Phase 32: File & FileLink - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Upload and download infrastructure with multipart/binary transport, File and FileLink CRUDL. Developers can upload files to Stripe, manage file links, and download binary content — enabling dispute evidence workflows and compliance document handling.

Requirements: FILE-01, FILE-02, FILE-03, FILE-04, FILE-05

</domain>

<decisions>
## Implementation Decisions

### Upload Transport

- **D-01:** `Client.upload/4` reuses the existing `Transport.request/1` callback — multipart is just a different body encoding + content-type header. No new Transport behaviour callbacks. Custom transports get upload support for free.
- **D-02:** Hand-roll a `LatticeStripe.MultipartEncoder` module (~40 lines) for multipart/form-data encoding. Zero new dependencies. Mirrors how stripe-ruby/python/go all hand-roll their multipart encoders. RFC 2046 format — one file field + string fields.
- **D-03:** Add `files_base_url` field to Client struct, defaulting to `"https://files.stripe.com"`. Mirrors all official SDKs (ruby: `uploads_base`, python: `upload_api_base`, go: `UploadsURL`). Testable with stripe-mock by pointing both URLs at `localhost:12111`.
- **D-04:** `Client.upload/4` signature: `upload(client, file_binary, params, opts)` — accepts raw binary content (result of `File.read!/1`). Caller controls file reading. Params map requires `"purpose"`, optionally accepts `"filename"` (default `"upload"`) and `"file_link_data"`.
- **D-05:** Upload fully reuses the existing retry loop and telemetry span pipeline. Stripe file upload returns same JSON response format, supports idempotency keys, same `Stripe-Should-Retry` header. Add `:upload` as an operation type for per-operation timeout support.
- **D-06:** `MultipartEncoder` accepts an injectable boundary option for deterministic test assertions (stripe-python's trick). Production calls generate a random boundary via `:crypto.strong_rand_bytes/16`.

### Download Transport

- **D-07:** `Client.download/2` and `Client.download!/2` are separate public functions on Client — not a flag on `request/2`. Crystal clear intent: `download` returns binary, `request` returns decoded JSON. Mirrors stripe-go/stripe-python's separate streaming methods.
- **D-08:** Extract shared request-building logic into a private `build_effective_request/2` helper to avoid duplicating header/URL/timeout/idempotency logic between `request/2`, `upload/4`, and `download/2`.
- **D-09:** Reuse `%Response{}` struct with binary data in the `data` field for download responses. Widen the typespec. No new struct — users already know Response, `resp.status`, `resp.request_id`, `resp.headers` all work.
- **D-10:** Buffered only — use existing `Finch.request/3` through Transport behaviour. No streaming. Stripe files max 16MB, BEAM handles multi-MB binaries easily. Streaming can be added as `download_stream/3` later if demand appears.
- **D-11:** Error responses (4xx/5xx) on binary endpoints are still JSON — the download error path always JSON-decodes. Only the 2xx success path returns raw binary.
- **D-12:** Downloads go through the same retry + telemetry pipeline. GET requests are inherently idempotent. Same transient failure handling (429, 500, 503, connection errors).

### File & FileLink API Design

- **D-13:** `File.create/3` wraps `Client.upload/4` internally. User calls `File.create(client, %{"purpose" => "...", "file" => binary})` — same shape as every other resource create. Multipart transport detail does not leak to the user. Matches all 3 official Stripe SDKs.
- **D-14:** File purpose: document only, pass strings. No constants or client-side validation. Consistent with every other Stripe enum in the SDK. Phase 15 D5 precedent ("no fake ergonomics"). Let Stripe's 400 errors flow through.
- **D-15:** `LatticeStripe.FileLink` is top-level (not nested under File). FileLink has its own top-level API endpoints (`/v1/file_links`), not accessed through File endpoints. All official SDKs treat it as top-level. Stripe object type is `"file_link"`.
- **D-16:** File.links nested list deserializes to `%List{data: [%FileLink{}, ...]}` using the exact same pattern as `Invoice.parse_lines/1`. Consistent with established codebase pattern.
- **D-17:** File API surface: `create/3`, `retrieve/3`, `list/3`, `stream!/3` + bang variants. No `update` (files are immutable), no `delete` (files cannot be deleted).
- **D-18:** FileLink API surface: `create/3`, `retrieve/3`, `update/4`, `list/3`, `stream!/3` + bang variants. No `delete` (file links expire, not deleted).
- **D-19:** Both File and FileLink implement custom `Inspect` that masks `url` field — File.url is an authenticated download URL, FileLink.url is a bearer-like public download credential.
- **D-20:** Both modules register in `object_types.ex`: `"file" => LatticeStripe.File`, `"file_link" => LatticeStripe.FileLink`.

### Testing Strategy

- **D-21:** 5-layer testing: (1) MultipartEncoder unit tests, (2) Client.upload unit tests via Mox, (3) Client.download unit tests via Mox, (4) Resource module tests via Mox + fixtures, (5) Integration tests against stripe-mock.
- **D-22:** Mox setup unchanged — upload goes through same `Transport.request/1`, so existing mock patterns work with zero changes.
- **D-23:** stripe-mock supports multipart to `/v1/files` (confirmed since v0.14.0). Integration tests hit stripe-mock with real multipart requests.
- **D-24:** Internal fixture builders `file_json/1` and `file_link_json/1` in `test/support/fixtures/`. Keep test-only for now; promote to `LatticeStripe.Testing` later if downstream demand appears.

### Claude's Discretion

- MultipartEncoder internal implementation details (iodata vs binary concatenation, CRLF handling)
- Exact `build_effective_request/2` extraction boundaries
- Test helper naming and organization within existing test structure
- ExDoc grouping for File and FileLink modules

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Codebase (patterns to follow)
- `lib/lattice_stripe/client.ex` — Current `request/2`, retry loop, header building, `build_url_and_body/4`, `do_request/2`, `decode_response/6`. Upload and download extend this.
- `lib/lattice_stripe/transport.ex` — Transport behaviour contract. `request/1` callback reused for upload (no new callbacks).
- `lib/lattice_stripe/transport/finch.ex` — Finch adapter. No changes needed for multipart (binary body works as-is).
- `lib/lattice_stripe/form_encoder.ex` — Existing encoding module pattern. `MultipartEncoder` mirrors this as an internal encoding module.
- `lib/lattice_stripe/resource.ex` — `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1` helpers.
- `lib/lattice_stripe/customer.ex` — Reference resource module: `@known_fields`, `defstruct`, `from_map/1`, CRUDL pattern.
- `lib/lattice_stripe/invoice.ex` §`parse_lines/1` — Nested list deserialization pattern for File.links.
- `lib/lattice_stripe/object_types.ex` — Object type registry for expand deserialization.
- `lib/lattice_stripe/config.ex` — NimbleOptions schema for Client validation. Must add `files_base_url`.
- `lib/lattice_stripe/response.ex` — Response struct. Typespec widened for binary data.
- `lib/lattice_stripe/telemetry.ex` — Telemetry spans. Upload and download reuse existing `request_span/4`.

### Stripe API Documentation
- [Stripe File Upload API](https://docs.stripe.com/api/files/create) — Multipart POST to `files.stripe.com/v1/files`
- [Stripe File Object](https://docs.stripe.com/api/files/object) — File struct fields, purpose enum values
- [Stripe FileLink Object](https://docs.stripe.com/api/file_links/object) — FileLink struct fields
- [Stripe File Upload Guide](https://docs.stripe.com/file-upload) — Purpose values, size limits, supported types

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Client.request/2` pipeline (header building, retry loop, telemetry span) — reused by upload and download with minimal forking
- `FormEncoder` pattern — `MultipartEncoder` follows same internal module pattern
- `Resource.unwrap_singular/2` and `unwrap_list/2` — used by File and FileLink modules
- `Invoice.parse_lines/1` — exact pattern for File.links nested list deserialization
- `ObjectTypes.maybe_deserialize/1` — for FileLink.file expand deserialization
- Existing Mox setup for `MockTransport.request/1` — works unchanged for upload/download

### Established Patterns
- `@known_fields ~w[...]` + `defstruct` + `from_map/1` + `extra: %{}` — all resource modules follow this
- Bang variants via `Resource.unwrap_bang!/1` — every operation gets a `!` variant
- `stream!/3` via `List.stream!/2 |> Stream.map(&from_map/1)` — consistent auto-pagination
- Custom `Inspect` for sensitive fields — Customer masks PII, File/FileLink mask URLs
- `classify_operation/1` in Client — add `:upload` and `:download` operation types

### Integration Points
- `Client` struct — add `files_base_url` field
- `Config` NimbleOptions schema — validate `files_base_url`
- `object_types.ex` — register `"file"` and `"file_link"` types
- `Client.do_request/2` forking — `do_download/2` skips JSON decode on 2xx
- Telemetry — upload/download emit same `[:lattice_stripe, :request, *]` events

</code_context>

<specifics>
## Specific Ideas

### Architecture Sketch
```
Client.request/2   -> build_effective_request -> telemetry span -> retry_loop -> do_request  (JSON decode)
Client.upload/4    -> build_upload_request    -> telemetry span -> retry_loop -> do_request  (JSON decode, multipart body)
Client.download/2  -> build_effective_request -> telemetry span -> retry_loop -> do_download (raw binary on 2xx, JSON on error)
```

### MultipartEncoder boundary injection
Accept `boundary:` option for test determinism (pin to known value). Production generates via `:crypto.strong_rand_bytes/16`. Follows stripe-python's pattern.

### File.create params shape
```elixir
File.create(client, %{"purpose" => "dispute_evidence", "file" => File.read!("evidence.pdf"), "filename" => "evidence.pdf"})
```
The `"file"` key holds raw binary. `"filename"` is optional metadata (default `"upload"`). `"file_link_data"` passes through as extra multipart text field.

</specifics>

<deferred>
## Deferred Ideas

- Streaming download (`Client.download_stream/3`) — add later if demand for large file streaming appears
- Streaming upload for files > 512MB — not a real Stripe concern
- Public fixture builders in `LatticeStripe.Testing` for File/FileLink — promote from internal test helpers later if downstream demand appears
- Content-type auto-detection based on file magic bytes — unnecessary complexity, let caller set it

None — discussion stayed within phase scope

</deferred>

---

*Phase: 32-file-filelink*
*Context gathered: 2026-04-16*
