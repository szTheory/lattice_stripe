# Phase 32: File & FileLink - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-16
**Phase:** 32-file-filelink
**Areas discussed:** Upload transport, Download transport, File & FileLink API, Testing strategy

---

## Upload Transport

### Transport Behaviour Design

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse `Transport.request/1` | Multipart body is just a different encoding + content-type header; no behaviour change | ✓ |
| New `upload/1` callback | Explicit upload semantic at transport layer | |

**User's choice:** Reuse `Transport.request/1`
**Notes:** All official Stripe SDKs (Ruby, Python, Go) funnel uploads through the same HTTP call path. Breaking the Transport behaviour for this is unnecessary.

### Multipart Encoding

| Option | Description | Selected |
|--------|-------------|----------|
| Hand-roll `MultipartEncoder` | ~40 lines, zero deps, matches official SDK pattern | ✓ |
| `multipart` hex package | Well-maintained but adds unnecessary dependency | |

**User's choice:** Hand-roll `MultipartEncoder`
**Notes:** Minimal-dependency philosophy. stripe-ruby, stripe-python both hand-roll theirs.

### Base URL Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Add `files_base_url` to Client struct | Mirrors all official SDKs; testable with stripe-mock | ✓ |
| Hardcode URL | Simplest but untestable | |
| Per-request URL override | Inconsistent with base_url pattern | |

**User's choice:** Add `files_base_url` to Client struct
**Notes:** Universal pattern across official SDKs. Required for stripe-mock testing.

### Upload Signature

| Option | Description | Selected |
|--------|-------------|----------|
| Accept binary content | `upload(client, binary, params, opts)` — caller controls file reading | ✓ |
| Accept file path | SDK does file I/O — impure | |
| Accept both (tagged tuple) | Maximum flexibility but un-Elixir | |

**User's choice:** Accept binary content
**Notes:** Caller does `File.read!/1` and passes binary. Most testable, most composable.

### Retry/Telemetry

| Option | Description | Selected |
|--------|-------------|----------|
| Full reuse | Same retry loop, telemetry span, idempotency key generation | ✓ |
| Separate pipeline | Own retry/telemetry for uploads | |

**User's choice:** Full reuse
**Notes:** File upload returns same JSON response, supports idempotency keys, same Stripe-Should-Retry header.

---

## Download Transport

### Design Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Separate `Client.download/2` | Clear intent; no union types in response | ✓ |
| `:raw` flag on `request/2` | Single entry point but messy types | |
| Content-type sniffing | Implicit magic; every SDK rejects this | |

**User's choice:** Separate `Client.download/2`
**Notes:** Mirrors stripe-go/stripe-python separate methods. Extract shared logic into private helper.

### Response Type

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse `%Response{}` with binary data | Zero new types; widen typespec | ✓ |
| New `%DownloadResponse{}` struct | Distinct type but over-engineered | |

**User's choice:** Reuse `%Response{}`
**Notes:** Users already know Response. Metadata (content-type, request-id) available via headers.

### Streaming vs Buffered

| Option | Description | Selected |
|--------|-------------|----------|
| Buffered only | Simple; adequate for Stripe's file sizes (max 16MB) | ✓ |
| Streaming via Transport extension | Memory-efficient but adds complexity | |

**User's choice:** Buffered only
**Notes:** Can add `download_stream/3` later. Retry works naturally with buffered.

---

## File & FileLink API

### File.create Wrapper

| Option | Description | Selected |
|--------|-------------|----------|
| `File.create/3` wraps `Client.upload/4` | Consistent resource API shape; matches all SDKs | ✓ |
| User calls `Client.upload/3` directly | Transparent but breaks resource pattern | |

**User's choice:** `File.create/3` wraps `Client.upload/4`
**Notes:** Same shape as every other resource create. Multipart is an implementation detail.

### Purpose Typing

| Option | Description | Selected |
|--------|-------------|----------|
| Document only, pass strings | Consistent with every other enum; Phase 15 D5 precedent | ✓ |
| Module attribute constants | Not accessible outside module | |
| Public constant functions | 20 functions polluting namespace | |

**User's choice:** Document only, pass strings
**Notes:** Let Stripe's 400 errors flow through.

### FileLink Placement

| Option | Description | Selected |
|--------|-------------|----------|
| `LatticeStripe.FileLink` (top-level) | Independent API endpoints; all SDKs treat as top-level | ✓ |
| `LatticeStripe.File.Link` (nested) | Would incorrectly suggest sub-resource relationship | |

**User's choice:** `LatticeStripe.FileLink` (top-level)
**Notes:** Stripe object type is `"file_link"`, has own CRUD endpoints.

### Nested Links List

| Option | Description | Selected |
|--------|-------------|----------|
| Deserialize to `%List{data: [%FileLink{}]}` | Matches `Invoice.parse_lines/1` pattern | ✓ |
| Leave as raw map | Inconsistent with existing pattern | |

**User's choice:** Deserialize to typed structs
**Notes:** Follows established codebase pattern exactly.

---

## Testing Strategy

### Approach

| Option | Description | Selected |
|--------|-------------|----------|
| 5-layer testing | Encoder → Client → Resource → Integration | ✓ |

**User's choice:** 5-layer testing
**Notes:** Mox setup unchanged. stripe-mock supports multipart since v0.14.0. Pin boundary in encoder tests for deterministic assertions.

---

## Claude's Discretion

- MultipartEncoder implementation details (iodata vs binary, CRLF handling)
- Exact `build_effective_request/2` extraction boundaries
- Test helper naming and organization
- ExDoc grouping for File and FileLink modules

## Deferred Ideas

- Streaming download (`Client.download_stream/3`) — add if demand appears
- Public fixture builders in `LatticeStripe.Testing` — promote later if needed
- Content-type auto-detection — unnecessary complexity
