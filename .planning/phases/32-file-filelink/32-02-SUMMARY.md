---
phase: 32-file-filelink
plan: "02"
subsystem: client-transport
tags: [upload, download, multipart, binary, client, transport]
dependency_graph:
  requires:
    - 32-01  # MultipartEncoder.encode/4, Config.files_base_url, Response binary typespec
  provides:
    - Client.upload/4
    - Client.upload!/4
    - Client.download/2
    - Client.download!/2
  affects:
    - lib/lattice_stripe/client.ex
    - test/lattice_stripe/client_test.exs
tech_stack:
  added: []
  patterns:
    - Mirrored do_request_with_retries pattern for do_download_with_retries
    - replace_content_type/2 removes-then-prepends to avoid duplicate headers
    - resolve_timeout/3 per-operation timeout helper shared by upload/download
key_files:
  modified:
    - lib/lattice_stripe/client.ex
    - test/lattice_stripe/client_test.exs
decisions:
  - "upload/4 builds URL from client.files_base_url, not client.base_url"
  - "download/2 builds URL from client.base_url (binary endpoints are on standard API domain)"
  - "do_download_with_retries/5 duplicates retry structure rather than adding parameter to do_request_with_retries — keeps arity clean"
  - "replace_content_type/2 rejects then prepends to guarantee exactly one content-type header"
  - "test_client max_retries must be 0 for error-path download tests to avoid retry storm against single Mox expect"
metrics:
  duration: ~8 minutes
  completed: "2026-04-17T02:56:13Z"
  tasks_completed: 2
  files_modified: 2
---

# Phase 32 Plan 02: Client upload/download Transport Functions Summary

Client extended with `upload/4` and `download/2` transport capabilities using multipart POST to files API and binary-preserving GET, both wired into the existing retry and telemetry pipeline.

## What Was Built

**`Client.upload/4` and `upload!/4`**
- Accepts `file_binary`, `params` map, and `opts`
- Extracts `"filename"` from params (defaults to `"upload"`) and drops it from `string_fields`
- Calls `MultipartEncoder.encode/4` with injectable `:boundary` opt for deterministic tests
- Builds URL from `client.files_base_url <> "/v1/files"` (not `base_url`)
- Calls `build_headers/5` then `replace_content_type/2` to swap form-urlencoded for multipart header
- Wraps `do_request_with_retries/5` in `Telemetry.request_span/4` — identical pipeline to `request/2`

**`Client.download/2` and `download!/2`**
- Accepts path string and opts
- Builds URL from `client.base_url <> path` (binary endpoints on standard Stripe API domain)
- Sends GET with standard auth/version headers (no content-type needed)
- `do_download/2` forks from `do_request/2`: on 2xx returns `{:ok, %Response{data: raw_binary}}`; on non-2xx delegates to `decode_response/6` for JSON error decoding
- `do_download_with_retries/5` mirrors `do_request_with_retries/5` structure

**Private helpers added**
- `resolve_timeout/3` — checks opts, then `operation_timeouts` map, then `client.timeout`
- `replace_content_type/2` — `Enum.reject` then prepend; guarantees single content-type header
- `do_download/2` — binary-aware transport call
- `do_download_with_retries/5,8` — retry loop for download path

## Tasks

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Add upload/4, download/2 and private helpers to Client | 9ed080a |
| 2 | Add Mox tests for upload/4 and download/2 (included in same commit) | 9ed080a |

## Test Coverage

14 new tests added across two describe blocks:

**`describe "upload/4"`** (8 tests):
- Multipart POST to files_base_url with correct content-type
- Injectable boundary for deterministic body assertions
- No duplicate content-type headers
- Authorization and stripe-version headers present
- API error returns `{:error, %Error{}}`
- Bang variant raises on error
- Default filename "upload" when not specified
- Custom filename when specified in params

**`describe "download/2"`** (6 tests):
- Raw binary returned on 200 with correct request_id
- 4xx JSON-decoded to `{:error, %Error{type: :invalid_request_error}}`
- 5xx JSON-decoded to `{:error, %Error{type: :api_error}}`
- Uses base_url not files_base_url
- Bang variant raises on error
- Connection error returns `{:error, %Error{type: :connection_error}}`

Total: 86 tests, 0 failures.

## Deviations from Plan

**1. [Rule 1 - Bug] max_retries: 0 added to two download error tests**
- **Found during:** Task 2 test run
- **Issue:** Default `test_client()` in `client_test.exs` has no `max_retries` override (defaults to `2`). The default retry strategy retries on 5xx and connection errors, so a single `expect(MockTransport, :request, fn -> ... end)` was called twice, causing `Mox.UnexpectedCallError`.
- **Fix:** Added `test_client(max_retries: 0)` to "JSON-decodes error responses on 5xx" and "handles connection error" tests.
- **Files modified:** `test/lattice_stripe/client_test.exs`
- **Commit:** 9ed080a (same commit)

## Self-Check

- [x] `lib/lattice_stripe/client.ex` exists and contains `def upload(`, `def download(`
- [x] `test/lattice_stripe/client_test.exs` exists and contains `describe "upload/4"` and `describe "download/2"`
- [x] Commit 9ed080a exists
- [x] `mix compile --warnings-as-errors` exits 0
- [x] `mix test test/lattice_stripe/client_test.exs` exits 0 (81 tests, 0 failures)
- [x] `mix test test/lattice_stripe/multipart_encoder_test.exs` exits 0 (5 tests, 0 failures)

## Self-Check: PASSED
