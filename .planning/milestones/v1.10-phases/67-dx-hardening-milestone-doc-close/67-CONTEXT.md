# Phase 67: DX Hardening & Milestone Doc Close - Context

**Gathered:** 2026-08-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Close the remaining v1.10 DX and documentation gaps: expose useful HTTP response metadata on public errors, promote a safe webhook raw-body reader, make the permanent PaymentIntent-first Charge policy unambiguous, and close the milestone's documentation evidence against the live repository. This phase hardens existing behavior and public guidance; it does not introduce a new payment flow, retry policy, rate limiter, webhook architecture, or general DX redesign.

</domain>

<decisions>
## Implementation Decisions

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

</decisions>

<specifics>
## Specific Ideas

- Required body-reader regression shape: call `CacheBodyReader.read_body(conn, length: 3)` until it yields `{:more, "abc", conn}` then `{:ok, "def", conn}`, and assert `conn.private[:raw_body] == "abcdef"`.
- Required direct server-side payment example:

  ```elixir
  {:ok, intent} =
    LatticeStripe.PaymentIntent.create(client, %{
      "amount" => 4_999,
      "currency" => "usd",
      "payment_method" => "pm_card_visa",
      "confirm" => true
    })
  ```

- Preferred Charge moduledoc language: “`LatticeStripe.Charge.create/3` will not be added. Charge is read/reconciliation. For server-side payment initiation use `PaymentIntent.create/3` with `"confirm" => true`; a successful PaymentIntent creates the resulting Charge.”
- API and documentation UX should follow the principle of least surprise: expose transport facts faithfully, use Stripe's current domain language, lead with the consumer's job, and keep backend implementation history out of public explanations.
- This phase has no visual UI. The applicable design concerns are API ergonomics, documentation information architecture, accessible prose, discoverability, safe defaults, compatibility, observability, security, performance, and consistent terminology.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and product direction
- `.planning/ROADMAP.md` — Phase 67 boundary and success criteria.
- `.planning/REQUIREMENTS.md` — DX-02, DX-03, and DOC-02 requirements.
- `.planning/PROJECT.md` — Project vision, library constraints, and quality bar.
- `.planning/seeds/SEED-005-stripe-native-entitlements.md` §3.3, §3.4, §3.10, §6 — Original error metadata, body-reader, Charge, and documentation-close gaps.
- `.planning/research/accrue-gap-brief-2026-07-27.txt` §3.3, §3.4, §3.10 — Source gap analysis and acceptance intent.
- `.planning/seeds/SEED-006-accrue-dx-ergonomics.md` — Explicit scope boundary for broader deferred DX work.
- `.planning/v1.10-MILESTONE-AUDIT.md` — Historical pre-Phase-67 audit only; rerun after implementation rather than editing this file.

### Error metadata and retry behavior
- `lib/lattice_stripe/error.ex` — Current error structure and response constructor.
- `lib/lattice_stripe/client.ex` — HTTP error construction, final retry result, and retry context integration.
- `lib/lattice_stripe/response.ex` — Established header preservation and lookup semantics.
- `lib/lattice_stripe/retry_strategy.ex` — Internal Retry-After parsing and capped strategy delay that must not leak into the public error value.
- `test/lattice_stripe/error_test.exs` — Error construction/type coverage.
- `test/lattice_stripe/client_test.exs` — HTTP, retry, and final-result behavior.
- `test/lattice_stripe/retry_strategy_test.exs` — Existing retry semantics to preserve.
- `guides/error-handling.md` — Consumer-facing error and retry guidance.

### Webhook raw-body support
- `lib/lattice_stripe/webhook/cache_body_reader.ex` — Implementation to harden and promote.
- `lib/lattice_stripe/webhook/plug.ex` — Consumer and ordering contract.
- `lib/lattice_stripe/webhook.ex` — Signature verification/raw-body expectations.
- `test/lattice_stripe/webhook/plug_test.exs` — Existing integration coverage.
- `guides/webhooks.md` — Canonical Phoenix/Plug setup and advanced body-reader guidance.
- `guides/api_stability.md` — Public API classification that must change deliberately.
- `mix.exs` — Optional Plug compilation and ExDoc module grouping.
- `priv/api/current.txt` and `test/lattice_stripe/api_surface_lock_test.exs` — Deliberate public-surface lock.

### Charge and PaymentIntent guidance
- `lib/lattice_stripe/charge.ex` — Read/reconciliation API and current consumer-facing policy prose.
- `lib/lattice_stripe/payment_intent.ex` — Supported payment-initiation API.
- `guides/payments.md` — Canonical payment workflow guide and Charge reconciliation section.
- `README.md` — Compact PaymentIntent-first cue; not a third full policy surface.
- `test/lattice_stripe/charge_test.exs` — Structural negative capability contract.
- `test/lattice_stripe/docs_truth_test.exs` — Section-scoped consumer-documentation contract.

### Documentation and release evidence
- `mix.exs` — `mix ci`, docs generation, optional-dependency grouping, and warnings-as-errors gate.
- `.github/workflows/ci.yml` — Required quality-job enforcement and ci-gate dependency.
- `CONTRIBUTING.md` — Contributor verification contract.
- `test/lattice_stripe/docs_truth_test.exs` — Documentation claims verified against the API.
- `priv/api/current.txt` and `test/lattice_stripe/api_surface_lock_test.exs` — Public API compatibility evidence.

### Project research lenses
- `prompts/elixir-best-practices-deep-research.md` — Idiomatic Elixir API, supervision, errors, and testing principles.
- `prompts/elixir-opensource-libs-best-practices-deep-research.md` — OSS library ergonomics, compatibility, documentation, and maintenance principles.
- `prompts/elixir-oss-lib-ci-cd-best-practices-deep-research.md` — Strict CI/release verification guidance.
- `prompts/stripe-sdk-api-surface-area-deep-research.md` — Stripe SDK public-surface and parity guidance.
- `prompts/stripe-explanation-domain-language-deep-research.md` — Stripe domain language and explanation model.
- `prompts/stripe-lib-priority-user-flows-deep-research.md` — Priority jobs-to-be-done and user flows.
- `prompts/payments_domain_field_guide.md` — Payment lifecycle and reconciliation concepts.
- `prompts/phoenix-best-practices-deep-research.md` — Phoenix/Plug integration, request lifecycle, and boundary design.
- `prompts/The definitive Stripe library gap in Elixir - a master research document.md` — Ecosystem lessons, parity priorities, and developer-experience goals.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `LatticeStripe.Response.get_header/2`: establishes case-insensitive, all-values header lookup semantics for the new error helper.
- `LatticeStripe.RetryStrategy`: already consumes response headers and recognizes delay-seconds; its policy cap remains an internal scheduling concern.
- `LatticeStripe.Webhook.Plug`: already accepts `conn.private[:raw_body]`, so the body reader can be promoted without inventing a second verification path.
- Documentation truth and API surface lock tests: provide existing enforcement patterns for the Charge policy and newly public module.

### Established Patterns
- Optional Plug support is compile-guarded, so the public body-reader module must retain conditional availability.
- Public surface changes are deliberate, documented, and locked in `priv/api/current.txt`.
- `mix ci` and the GitHub Actions quality job already treat ExDoc warnings as failures; current zero-warning evidence supersedes stale planning text.
- Charge tests already use negative capability assertions to prevent accidental mutation APIs.

### Integration Points
- HTTP response headers flow through `LatticeStripe.Client` into retry context and must also flow into `LatticeStripe.Error.from_response/4` on every HTTP error path.
- CacheBodyReader integrates at Plug parser configuration and feeds `LatticeStripe.Webhook.Plug` through `conn.private[:raw_body]`.
- Charge policy lives at the public module documentation and payments guide, with section-scoped truth tests bridging prose to actual APIs.
- Phase completion feeds the normal milestone re-audit; it must not mutate historical audit evidence in place.

</code_context>

<deferred>
## Deferred Ideas

- Parsing HTTP-date `Retry-After` values into a convenience field; raw headers preserve forward compatibility.
- Configurable CacheBodyReader keys, storage strategies, disk spooling, or multipart support.
- Webhook signature-error unification and other broader DX work tracked by SEED-006.
- Changes to retry policy, delay caps, queue/scheduler integration, or global rate limiting.
- Investigation of the already-tracked retry-telemetry and batch-test flakes.
- Broader Charge-policy duplication across noncanonical or historical documents.

</deferred>

---

*Phase: 67-dx-hardening-milestone-doc-close*
*Context gathered: 2026-08-25*
