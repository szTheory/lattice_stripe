# Phase 67: DX Hardening & Milestone Doc Close - Research

**Researched:** 2026-08-25
**Domain:** Elixir SDK public-error metadata, Plug webhook raw-body integration, API documentation contracts
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### HTTP error response metadata
- **D-01:** Add both `headers: [{String.t(), String.t()}]` (default `[]`) and `retry_after: non_neg_integer() | nil` (default `nil`) to `LatticeStripe.Error`. This is an additive, one-way public API decision: consumers receive the response evidence and a common convenience without inheriting internal retry-policy details.
- **D-02:** Preserve response headers in transport order, including duplicates, original casing, and values. Add `LatticeStripe.Error.get_header/2`, case-insensitive like `LatticeStripe.Response.get_header/2`, returning all matching values rather than collapsing duplicates.
- **D-03:** Derive `retry_after` from the first case-insensitive `Retry-After` header whose trimmed value is a valid non-negative decimal delay in seconds. Keep the value uncapped. Missing, malformed, negative, and HTTP-date values produce `nil`; their raw header values remain available in `headers`.
- **D-04:** Add `LatticeStripe.Error.from_response/4` to accept response headers and retain `from_response/3` as a compatibility delegate with empty headers. Populate metadata for both decoded Stripe JSON errors and non-JSON HTTP errors. Connection errors retain `headers: []` and `retry_after: nil`.
- **D-05:** The error returned after retry exhaustion must describe the final response attempt. Retry-strategy context and the eventual public error must receive the same response headers. Do not expose the strategy's five-second cap, change retry eligibility/backoff, add blocking sleeps, introduce queueing, or add a global rate limiter. Documentation must warn that headers and raw bodies may contain sensitive data and should not be logged wholesale; Phoenix consumers should schedule delayed background work rather than block request processes.

### Public webhook body reader
- **D-06:** Do not promote the current implementation unchanged. Fix its latent multi-chunk bug first: every `:more` chunk and the terminal `:ok` chunk must be accumulated in original byte order, while each call still returns exactly the tag and current chunk returned by `Plug.Conn.read_body/2`.
- **D-07:** Promote only `LatticeStripe.Webhook.CacheBodyReader.read_body/2`. Its stable public invariant is that, after the terminal `:ok`, `conn.private[:raw_body]` contains the exact complete request body binary. Keep the framework-owned data in `conn.private`, use the fixed `:raw_body` key, and do not add configurable keys, storage backends, disk spooling, or unrelated options.
- **D-08:** Keep the module behind the existing optional-Plug compile guard and document conditional availability. The canonical Phoenix/Plug setup mounts `LatticeStripe.Webhook.Plug` before `Plug.Parsers`; document the body-reader route as the advanced alternative when ordering cannot be changed. Warn that a global parser body reader retains another body copy for the connection lifetime, can retain PII, must not be logged, and is not intended for multipart requests.
- **D-09:** Move the module into the public API stability contract, remove its exclusion from `guides/api_stability.md`, ensure ExDoc's existing Webhooks grouping includes it, and intentionally refresh the API surface lock. Tests must force a multi-call body read (for example, `"abc"` then `"def"`) and prove the final raw body is `"abcdef"`, while retaining return/error behavior and `Webhook.Plug` integration coverage.

### Charge creation policy and payment-flow guidance
- **D-10:** `LatticeStripe.Charge.create/3` is a permanent exclusion. Charge is a read/reconciliation resource; server-side payment initiation goes through `LatticeStripe.PaymentIntent.create/3`. State the complete policy in exactly two canonical surfaces: `LatticeStripe.Charge` moduledoc and the Charge reconciliation section of `guides/payments.md`. Keep the existing README statement as a compact cue rather than duplicating the full explanation.
- **D-11:** Replace internal decision archaeology such as “Phase 18 decision D-06” in consumer-facing docs with durable task-oriented language. The payments guide must include an exact server-side example creating a PaymentIntent with amount, currency, payment method, and `"confirm" => true`; explain that a successful PaymentIntent produces the resulting Charge for reconciliation.
- **D-12:** Distinguish the direct server-side Charges replacement from browser/client flows that create a PaymentIntent server-side and confirm it with Stripe.js or an equivalent client SDK for authentication. Never imply that `"confirm" => true` universally eliminates customer action or SCA.
- **D-13:** Retain the existing structural test proving prohibited Charge mutations are absent. Add section-scoped documentation-truth coverage proving both canonical surfaces explicitly name `Charge.create/3`, route initiation to `PaymentIntent.create/3`, and include `"confirm" => true` where the direct server-side replacement is explained.
- **D-14:** Do not use broad repository grep as policy proof and do not spread the full explanation into scope, changelog, or historical planning documents. Tests must verify the intended consumer surfaces so unrelated prose cannot satisfy the contract.

### Milestone documentation close
- **D-15:** The previously recorded 38-warning ExDoc state is stale. Live evidence on 2026-08-25 is `mix docs --warnings-as-errors` exiting successfully with zero warnings, after the existing docs-gate work. Do not plan warning-cleanup implementation and do not introduce a differential warning baseline.
- **D-16:** Preserve zero warnings as the only accepted baseline. Phase verification must include the strict ExDoc command plus the normal documentation-truth, API-surface-lock, and full project gates. `mix ci` and the required GitHub Actions quality job remain the enforcement path.
- **D-17:** Treat `.planning/v1.10-MILESTONE-AUDIT.md` as a historical pre-Phase-67 audit and do not rewrite it in place. Rerun the milestone audit after Phase 67 so the new audit records current evidence. Project state should stop presenting the already-resolved warning count as live debt through the normal state/audit workflow.
- **D-18:** The already-tracked retry-telemetry and batch-test flakes are outside this phase. They do not weaken the documentation gate and must not expand this phase's implementation scope.

### the agent's Discretion
- Exact module documentation prose, guide headings, test names, and internal helper factoring, provided every public invariant and consumer-facing statement above remains explicit.
- Whether `LatticeStripe.Error.get_header/2` shares a private implementation with response header lookup or uses a small local implementation, provided behavior stays identical.
- Exact placement of security cautions and advanced body-reader guidance within the relevant guides.

### Deferred Ideas (OUT OF SCOPE)
- Parsing HTTP-date `Retry-After` values into a convenience field; raw headers preserve forward compatibility.
- Configurable CacheBodyReader keys, storage strategies, disk spooling, or multipart support.
- Webhook signature-error unification and other broader DX work tracked by SEED-006.
- Changes to retry policy, delay caps, queue/scheduler integration, or global rate limiting.
- Investigation of the already-tracked retry-telemetry and batch-test flakes.
- Broader Charge-policy duplication across noncanonical or historical documents.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DX-02 | `LatticeStripe.Error` exposes headers and/or parsed `retry_after` so consumers can honor Stripe Retry-After. | Extend the exception struct/typespec/constructors, flow headers through both HTTP-error builders, and lock JSON, non-JSON, connection, lookup, and final-retry behavior. |
| DX-03 | `LatticeStripe.Webhook.CacheBodyReader` is public and covered by the semver contract. | Accumulate all chunks in `conn.private[:raw_body]`, document conditional Plug availability, remove its stability exclusion, and refresh the API snapshot. |
| DOC-02 | Documentation permanently says Charge creation is absent by design and points to `PaymentIntent.create(confirm: true)`. | Restrict full policy to the Charge moduledoc and Charge-reconciliation guide section; add section-scoped documentation truth tests plus retain the structural no-mutation test. |
</phase_requirements>

## Summary

Phase 67 is an additive public-contract hardening pass, not new Stripe behavior. The existing transport already preserves response headers as ordered tuples and makes them available to retry strategy context, but `LatticeStripe.Client` currently constructs public errors without them. [VERIFIED: codebase grep] Wire the exact attempted response headers into `Error.from_response/4` and the non-JSON error builder; leave connection errors empty. The existing retry loop returns the `error` passed from its final `do_request/2` invocation, so correct construction on every attempt automatically satisfies the final-response requirement. [VERIFIED: codebase grep]

The webhook reader is the only correctness bug: it currently overwrites `conn.private[:raw_body]` on both `:more` and `:ok`. Plug documents that `read_body/2` may return successive `:more` chunks and that the returned `conn` must be threaded; `Plug.Parsers` explicitly supports a body-reader MFA for retaining raw input before it is discarded, but does not use that option for multipart parsing. [CITED: https://hexdocs.pm/plug/Plug.Parsers.html] Make the reader an accumulator while preserving the return tuple's current chunk exactly.

Documentation work should treat consumer surfaces as executable contracts: one Charge moduledoc, the Charge-reconciliation section of `guides/payments.md`, `guides/error-handling.md`, and `guides/webhooks.md`. Existing docs-truth totality and API-snapshot tests already establish the right enforcement style. The current baseline is clean: the focused regression suite passed 254 tests and `mix docs --warnings-as-errors` completed successfully during this research. [VERIFIED: local command]

**Primary recommendation:** Implement in three small plans: public error metadata first, body-reader correctness/publicization second, then documentation truth plus strict final gates and post-phase milestone re-audit.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| HTTP header evidence and `retry_after` parsing | API / Backend | — | The Elixir library owns transport decoding and public error construction; consumers choose scheduling policy. [VERIFIED: codebase grep] |
| Retry decision and final exhausted response | API / Backend | — | `Client` supplies the retry context and returns the terminal error; `RetryStrategy.Default` owns only internal retry scheduling. [VERIFIED: codebase grep] |
| Raw webhook body cache | Frontend Server (SSR) | API / Backend | Plug/Phoenix owns request reads and `conn.private`; the SDK supplies a safe optional integration helper. [CITED: https://hexdocs.pm/plug/Plug.Parsers.html] |
| Charge-policy discoverability | API / Backend | Static documentation | Public moduledocs and HexDocs guides express the semver-level SDK policy. [VERIFIED: codebase grep] |
| Documentation-warning enforcement | CI / Static | API / Backend | `mix ci` and the Quality workflow invoke strict ExDoc generation. [VERIFIED: codebase grep] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir standard library | installed Elixir 1.19.5 / OTP 28 | Struct defaults, binary concatenation, `String.downcase/1`, `Integer.parse/1` | Existing project conventions already use it; no new dependency is needed. [VERIFIED: local command; VERIFIED: codebase grep] |
| Plug | `~> 1.16` (project constraint) | `Plug.Conn.read_body/2`, `conn.private`, `Plug.Parsers` body-reader integration | This is the project's existing optional integration boundary and documented standard body-reader mechanism. [VERIFIED: codebase grep; CITED: https://hexdocs.pm/plug/Plug.Parsers.html] |
| ExUnit / Mox | project test stack | Unit contracts for error construction and mocked HTTP retry attempts | Existing tests use these seams; Mox avoids real Stripe calls for this behavior. [VERIFIED: codebase grep] |
| ExDoc | `~> 0.34` (project constraint) | Public docs grouping and warning gate | Existing `mix ci` uses `docs --warnings-as-errors`. [VERIFIED: codebase grep] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|
| Existing `LatticeStripe.Response.get_header/2` semantics | repository source | Case-insensitive, all-values header lookup reference | Mirror it in `Error.get_header/2`; a private shared helper is optional. [VERIFIED: codebase grep] |
| Existing `LatticeStripe.ApiSurface` snapshot task | repository source | Semver lock refresh | Run only after the intentional public reader and error-surface additions are complete. [VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Preserve raw header tuples | Collapse into a normalized map | Rejected by D-02: loses duplicates, order, and original casing. |
| Decimal-seconds convenience field | HTTP-date parsing or scheduler policy | Rejected by D-03/D-05: raw values remain available while policy stays with the adopter. |
| Fixed private raw-body key | Configurable cache/spool abstraction | Rejected by D-07/D-08: broader lifetime/storage semantics add unsupported API surface. |

**Installation:** No packages are installed in this phase. [VERIFIED: phase context]

## Architecture Patterns

### System Architecture Diagram

```text
HTTP transport response
  -> Client.decode_response(headers, body)
     -> 2xx: Response{headers, request_id}
     -> non-2xx JSON: Error.from_response(status, decoded, request_id, headers)
     -> non-JSON: Error{headers, retry_after, raw_body}
  -> retry context receives the same headers
     -> retry? -> next request OR terminal {:error, final Error}

Phoenix/Plug request
  -> Plug.Parsers body_reader MFA (advanced route)
     -> CacheBodyReader.read_body(conn, opts)
        -> {:more, chunk, conn(private.raw_body = accumulated)}
        -> {:ok, final_chunk, conn(private.raw_body = full_binary)}
  -> Webhook.Plug reads private.raw_body -> signature verification
```

### Recommended Project Structure

```text
lib/lattice_stripe/
├── error.ex                       # public error fields, constructor, lookup/parser
├── client.ex                      # all HTTP error construction call sites
└── webhook/cache_body_reader.ex   # guarded public Plug helper
guides/
├── error-handling.md              # consumer Retry-After/security guidance
├── webhooks.md                    # canonical and advanced raw-body routes
└── payments.md                    # Charge reconciliation policy
test/lattice_stripe/
├── error_test.exs
├── client_test.exs
├── webhook/plug_test.exs
└── docs_truth_test.exs
```

### Pattern 1: Preserve wire evidence; derive a narrow convenience
**What:** Store the complete header tuple list verbatim and derive only the explicitly defined decimal-seconds `retry_after` field.
**When to use:** Every HTTP error, including non-JSON bodies; never connection failures.
**Example:**

```elixir
@spec get_header(t(), String.t()) :: [String.t()]
def get_header(%__MODULE__{headers: headers}, name) do
  downcased = String.downcase(name)
  for {key, value} <- headers, String.downcase(key) == downcased, do: value
end

defp retry_after(headers) do
  headers
  |> get_header("retry-after")
  |> Enum.find_value(fn value ->
    case Integer.parse(String.trim(value)) do
      {seconds, ""} when seconds >= 0 -> seconds
      _ -> nil
    end
  end)
end
```

This intentionally requires an empty post-parse remainder: `"3x"`, `"-1"`, and HTTP-date forms return `nil`; `" 3 "` returns `3`. [VERIFIED: locked D-03]

### Pattern 2: Append every body chunk, return the native tuple
**What:** Read once per invocation, retain the old cached binary plus the returned chunk, then return the exact result tag and chunk.
**When to use:** `:more` and terminal `:ok`; do not cache/update on `{:error, reason}`.
**Example:**

```elixir
case Plug.Conn.read_body(conn, opts) do
  {tag, chunk, conn} when tag in [:more, :ok] ->
    raw_body = Map.get(conn.private, :raw_body, "") <> chunk
    {tag, chunk, Plug.Conn.put_private(conn, :raw_body, raw_body)}

  {:error, reason} ->
    {:error, reason}
end
```

This follows Plug's documented `:more`/`:ok` contract and threads the returned connection. [CITED: https://hexdocs.pm/plug/Plug.Conn.html]

### Pattern 3: Section-scoped prose locks
**What:** Extract the intended section boundaries before asserting policy anchors, rather than scanning the whole repository.
**When to use:** Charge moduledoc and the `## Charge reconciliation` segment only.
**Example:**

```elixir
assert charge_moduledoc =~ "Charge.create/3"
assert charge_moduledoc =~ "PaymentIntent.create/3"
assert charge_reconciliation =~ "Charge.create/3"
assert charge_reconciliation =~ "PaymentIntent.create/3"
assert charge_reconciliation =~ ~s/"confirm" => true/
```

The test must additionally retain the existing negative structural capability assertion, so accurate prose cannot conceal a newly added prohibited mutation. [VERIFIED: locked D-13/D-14]

### Anti-Patterns to Avoid

- **Reuse `RetryStrategy.Default.retry_after_delay/1` for public metadata:** It accepts looser parsing and caps milliseconds at 5 seconds; it would leak scheduling policy and violate D-03/D-05. [VERIFIED: codebase grep]
- **Build non-JSON errors manually without a shared metadata helper:** This creates the most likely divergent error path. Route it through a common field builder or test it explicitly. [VERIFIED: codebase grep]
- **Update cache only with the latest chunk:** This is the existing bug and loses preceding bytes, invalidating signature verification. [VERIFIED: codebase grep]
- **Use `CacheBodyReader` with multipart:** Plug documents `:body_reader` is not used by `Plug.Parsers.MULTIPART`; keep the docs' exclusion explicit. [CITED: https://hexdocs.pm/plug/Plug.Parsers.html]
- **Use `confirm: true` prose as a universal SCA claim:** Stripe documents `requires_action` transitions where additional authentication is needed. [CITED: https://docs.stripe.com/api/payment_intents/confirm?javascript=false]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP retry scheduling | New rate limiter, queue, or sleep policy | Existing configurable `RetryStrategy` and adopter background jobs | D-05 deliberately separates transport facts from application scheduling. |
| Raw-body request integration | New webhook parsing pipeline | `Plug.Parsers` body-reader MFA plus existing `Webhook.Plug` | Plug supplies the correct request lifecycle and the SDK already consumes `conn.private[:raw_body]`. [CITED: https://hexdocs.pm/plug/Plug.Parsers.html; VERIFIED: codebase grep] |
| Public API compatibility detection | Manual public-module checklist | `mix lattice_stripe.api_surface --update` and lock test | The repository's committed snapshot makes intentional surface changes reviewable. [VERIFIED: codebase grep] |
| Documentation-policy verification | Broad grep or human assertion | `docs_truth_test.exs` section-scoped tests | A specific consumer surface must contain the policy; unrelated text is invalid evidence. [VERIFIED: locked D-14] |

**Key insight:** This phase must expose facts and preserve existing framework contracts, not encode adopter retry or payment orchestration policy in the SDK.

## Common Pitfalls

### Pitfall 1: Header parsing accidentally accepts suffixes
**What goes wrong:** `Integer.parse/1` yields `{3, "seconds"}` or `{3, "x"}` and an implementation treats it as valid.
**Why it happens:** The retry strategy's parser is deliberately permissive for internal behavior, while the public contract is stricter.
**How to avoid:** Trim first, accept only `{seconds, ""}` with `seconds >= 0`, and test duplicate/first-valid ordering, whitespace, malformed, negative, and HTTP-date inputs.
**Warning signs:** `retry_after` becomes non-`nil` for a value other than a decimal delay. [VERIFIED: locked D-03; VERIFIED: codebase grep]

### Pitfall 2: Missing a response-error construction path
**What goes wrong:** JSON errors gain headers but non-JSON errors, download errors, or terminal retries do not.
**Why it happens:** `Client` has separate JSON and non-JSON builders and retries operate on a three-tuple internally.
**How to avoid:** Test JSON and non-JSON `Client.request/2`, JSON `download/3`, connection errors, retry context headers, and a two-attempt final-response case with different headers.
**Warning signs:** A public error has the correct `request_id` but empty `headers` after an HTTP response. [VERIFIED: codebase grep]

### Pitfall 3: Publishing the reader without protecting the invariant
**What goes wrong:** A future edit returns correct chunks but stores only the last one.
**Why it happens:** Single-chunk `Plug.Test.conn/3` tests cannot exercise `:more`.
**How to avoid:** Force `length: 3` on a six-byte body and assert `{:more, "abc", conn}`, then `{:ok, "def", conn}`, then the final `"abcdef"` private value; keep error and Webhook.Plug integration tests.
**Warning signs:** The raw body equals the terminal chunk. [VERIFIED: locked D-06/D-09]

### Pitfall 4: ExDoc change is incomplete
**What goes wrong:** `@moduledoc false` is removed but the stability guide and snapshot are not intentionally changed.
**Why it happens:** ExDoc grouping is regex-based and groups do not themselves prove semver policy.
**How to avoid:** Keep the existing Webhooks regex group, remove only the cache-reader exclusion, run the totality/docs-truth test, then update and review `priv/api/current.txt`.
**Warning signs:** Surface lock fails unexpectedly or docs list the module as internal. [VERIFIED: codebase grep]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Internal-only response headers for retry decisions | Public error retains raw headers plus narrow `retry_after` convenience | Phase 67 | Consumers can implement their own safe delayed recovery after final failure without SDK policy leakage. [VERIFIED: locked D-01–D-05] |
| Hidden body-reader helper that overwrites cache | Public conditional Plug helper accumulating all chunks | Phase 67 | Signature verification has an explicit raw-body invariant for advanced parser ordering. [VERIFIED: locked D-06–D-09] |
| Decision-history rationale in Charge docs | Durable PaymentIntent-first task guidance | Phase 67 | Documentation stays useful after planning artifacts age. [VERIFIED: locked D-10–D-14] |

**Deprecated/outdated:** The 38-warning state in `.planning/STATE.md` and its historical audit framing are stale; strict docs generation is already green and no differential baseline is permitted. [VERIFIED: local command; VERIFIED: locked D-15–D-17]

## Assumptions Log

All implementation decisions are locked in CONTEXT.md or verified from the repository and official documentation; no unverified claim must become a planning decision.

## Open Questions

None blocking. Keep post-phase milestone-audit invocation as a final documentation task rather than editing the historical audit in place. [VERIFIED: locked D-17]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir / Mix | implementation and tests | ✓ | Elixir 1.19.5 / OTP 28 | — [VERIFIED: local command] |
| Plug optional dependency | reader compilation and tests | ✓ | resolved by project dependencies | no fallback; feature remains conditionally compiled for consumers without Plug. [VERIFIED: codebase grep] |
| Docker | optional integration lane / stripe-mock | ✓ | Docker 29.5.2 | unit tests do not require it. [VERIFIED: local command] |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** None.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with Mox transport seams [VERIFIED: codebase grep] |
| Config file | `test/test_helper.exs` [VERIFIED: codebase grep] |
| Quick run command | `mix test test/lattice_stripe/error_test.exs test/lattice_stripe/client_test.exs test/lattice_stripe/webhook/plug_test.exs test/lattice_stripe/charge_test.exs test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/api_surface_lock_test.exs` |
| Full suite command | `mix ci` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DX-02 | Error defaults/typespec, case-insensitive all-value lookup, strict Retry-After parser | unit | `mix test test/lattice_stripe/error_test.exs` | ✅ extend |
| DX-02 | HTTP JSON/non-JSON/download/connection errors preserve correct metadata | unit/Mox | `mix test test/lattice_stripe/client_test.exs` | ✅ extend |
| DX-02 | Final retry error and retry context use final headers | unit/Mox | `mix test test/lattice_stripe/client_test.exs test/lattice_stripe/retry_strategy_test.exs` | ✅ extend |
| DX-03 | Reader accumulates `:more` + final `:ok` in byte order and preserves tuple/error behavior | unit | `mix test test/lattice_stripe/webhook/plug_test.exs` | ✅ extend |
| DX-03 | Reader becomes public and grouped | API/docs lock | `mix test test/lattice_stripe/api_surface_lock_test.exs test/lattice_stripe/docs_truth_test.exs` | ✅ existing locks |
| DOC-02 | Exact canonical Charge-policy surfaces contain correct route and direct-server `confirm` example | docs truth + structural unit | `mix test test/lattice_stripe/docs_truth_test.exs test/lattice_stripe/charge_test.exs` | ✅ extend |

### Sampling Rate

- **Per task commit:** targeted command above plus `mix format --check-formatted`.
- **Per wave merge:** `mix docs --warnings-as-errors`, API-surface lock, and docs-truth test.
- **Phase gate:** `mix ci` green before verification, followed by the normal milestone audit rerun. [VERIFIED: codebase grep; VERIFIED: locked D-16/D-17]

### Wave 0 Gaps

- [ ] Add error-header/parser and final-retry-response test cases in existing `error_test.exs` and `client_test.exs`.
- [ ] Add forced multi-chunk reader regression in existing `webhook/plug_test.exs`.
- [ ] Add section-scoped Charge policy truth tests in existing `docs_truth_test.exs`.
- [ ] No framework installation: existing infrastructure covers the phase. [VERIFIED: codebase grep]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No new authentication surface. |
| V3 Session Management | no | No session behavior changes. |
| V4 Access Control | no | No authorization behavior changes. |
| V5 Input Validation | yes | Strict decimal parsing for public convenience field; preserve unparsed raw evidence. [VERIFIED: locked D-03] |
| V6 Cryptography | yes | Reuse existing webhook HMAC verification; raw-body reader must preserve bytes exactly. [VERIFIED: codebase grep] |

### Known Threat Patterns for Elixir/Plug boundary

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Sensitive response headers/body logged wholesale | Information disclosure | Docs explicitly warn consumers; retain existing inspect sanitization and expose values only as application data. [VERIFIED: locked D-05/D-08; VERIFIED: codebase grep] |
| Webhook signature failure from altered/truncated bytes | Tampering | Byte-order accumulation and integration assertion through `Webhook.Plug`. [VERIFIED: locked D-06/D-09] |
| Retained global parser body copy increases PII lifetime | Information disclosure / DoS | Position as advanced non-multipart route, document memory/PII warning, do not add disk spooling or configurable retention. [CITED: https://hexdocs.pm/plug/Plug.Parsers.html; VERIFIED: locked D-08] |
| Blocking Phoenix request process while honoring retry delay | Denial of service | Document delayed background work for final failures; do not add SDK queueing/sleeps. [VERIFIED: locked D-05] |

## Sources

### Primary (HIGH confidence)
- Repository source/tests listed in `67-CONTEXT.md` — current error, retry, webhook, docs, snapshot, and CI seams. [VERIFIED: codebase grep]
- Local focused suite and `mix docs --warnings-as-errors` — 254 tests passed; strict docs generation passed. [VERIFIED: local command]

### Secondary (MEDIUM confidence)
- https://hexdocs.pm/plug/Plug.Parsers.html — body-reader MFA purpose, multipart exclusion, parser lifecycle. [CITED: https://hexdocs.pm/plug/Plug.Parsers.html]
- https://hexdocs.pm/plug/Plug.Conn.html — `read_body/2` `:more`/`:ok` and returned-connection semantics. [CITED: https://hexdocs.pm/plug/Plug.Conn.html]
- https://docs.stripe.com/api/payment_intents/create — `confirm=true` creation/confirmation semantics. [CITED: https://docs.stripe.com/api/payment_intents/create]
- https://docs.stripe.com/api/payment_intents/confirm — possible `requires_action` transition. [CITED: https://docs.stripe.com/api/payment_intents/confirm?javascript=false]

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependency; all libraries and versions come from `mix.exs` and installed runtime.
- Architecture: HIGH — direct tracing of source and tests establishes every proposed edit seam.
- Pitfalls: HIGH — derived from locked decisions, existing bug, and official Plug/Stripe behavior.

**Research date:** 2026-08-25
**Valid until:** 2026-09-24 (stable project-local patterns; recheck Plug/Stripe docs before changing locked scope)
