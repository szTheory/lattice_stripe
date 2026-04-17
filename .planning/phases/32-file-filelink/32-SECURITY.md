---
phase: 32-file-filelink
asvs_level: 1
audited: 2026-04-17
threats_total: 9
threats_closed: 9
threats_open: 0
block_on: high
result: SECURED
---

# Phase 32 Security Audit

**Phase:** 32 — file-filelink
**ASVS Level:** 1
**Threats Closed:** 9/9
**Threats Open:** 0/9

## Threat Verification

| Threat ID | Category | Disposition | Evidence |
|-----------|----------|-------------|----------|
| T-32-01 | Tampering | accept | Accepted: boundary is RFC 2046 HTTP framing only, not a security boundary. Injectable boundary is test-only (opts[:boundary]). Documented in plan 01 threat model. |
| T-32-02 | Information Disclosure | accept | Accepted: `files_base_url` is developer-configured at client construction, same trust model as `base_url`. No user input reaches this field. Documented in plan 01 threat model. |
| T-32-03 | Spoofing | mitigate | CLOSED: `build_headers/5` at client.ex:628 sets `{"authorization", "Bearer #{api_key}"}`. `upload/4` at client.ex:285 calls `build_headers(:post, effective_api_key, ...)` at line 307, same auth path as `request/2`. |
| T-32-04 | Tampering | accept | Accepted: multipart body assembled locally in-process; sent over HTTPS via Finch. No intermediate modification vector. Documented in plan 02 threat model. |
| T-32-05 | Information Disclosure | accept | Accepted: binary content returned only to the caller who initiated the request. No additional disclosure surface. Documented in plan 02 threat model. |
| T-32-06 | Denial of Service | accept | Accepted: Stripe files max 16MB; BEAM handles multi-MB binaries without issue. Streaming deferred. Documented in plan 02 threat model. |
| T-32-07 | Information Disclosure | mitigate | CLOSED: `defimpl Inspect, for: LatticeStripe.File` at file.ex:181 renders only `id, object, purpose, filename, size`. The `url` field is absent from the field list — authenticated download URL does not appear in logs or IEx output. |
| T-32-08 | Information Disclosure | mitigate | CLOSED: `defimpl Inspect, for: LatticeStripe.FileLink` at file_link.ex:162 renders only `id, object, expired, livemode`. The `url` field is absent — public bearer-like download URL does not appear in logs or IEx output. |
| T-32-09 | Elevation of Privilege | accept | Accepted: params passed to `MultipartEncoder` are serialized as string fields in the HTTP body. No shell execution path exists. Stripe validates server-side. Documented in plan 03 threat model. |

## Accepted Risks Log

| Threat ID | Category | Rationale | Accepted By |
|-----------|----------|-----------|-------------|
| T-32-01 | Tampering | Multipart boundary is HTTP framing, not a security control. Random boundary (`:crypto.strong_rand_bytes/16`) prevents accidental collision; test injection is scoped to opts keyword and cannot be set by end users. | Phase 32 threat model |
| T-32-02 | Information Disclosure | `files_base_url` is a developer-supplied config value with the same trust level as `base_url`. Developers already control `api_key` and `base_url`; adding control over `files_base_url` introduces no new trust boundary. | Phase 32 threat model |
| T-32-04 | Tampering | Body is assembled in-process from caller-supplied data and sent directly to Stripe via TLS. No writable intermediary. | Phase 32 threat model |
| T-32-05 | Information Disclosure | Download response is returned to the calling process only. No logging, caching, or secondary transmission of binary content occurs in the SDK. | Phase 32 threat model |
| T-32-06 | Denial of Service | Stripe enforces a 16 MB file size limit server-side. BEAM allocates binaries efficiently and the default 30s timeout provides a backstop. Streaming support is deferred to a future phase. | Phase 32 threat model |
| T-32-09 | Elevation of Privilege | MultipartEncoder produces an HTTP body — no shell, OS, or eval path exists. String fields are written as-is to the multipart body; Stripe's API validates content and purpose server-side. | Phase 32 threat model |

## Unregistered Threat Flags

None — all three SUMMARY.md `## Threat Flags` sections report "None". No new attack surface was flagged by the executor during implementation.
