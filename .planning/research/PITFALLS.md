# Domain Pitfalls

**Domain:** Elixir Stripe SDK / API Client Library
**Researched:** 2026-03-31

## Critical Pitfalls

Mistakes that cause rewrites, security vulnerabilities, or major user frustration.

### Pitfall 1: Webhook Raw Body Consumed by Phoenix Plug.Parsers

**What goes wrong:** Phoenix's `Plug.Parsers` automatically parses the request body into JSON, consuming the raw bytes. Stripe's webhook signature verification requires the exact original bytes. Once parsed, the raw body is gone and HMAC verification fails silently or produces cryptic errors. This is the single most complained-about issue in the Elixir Stripe ecosystem -- multiple ElixirForum threads describe it as the worst DX experience in the Elixir ecosystem. Developers either skip verification entirely (security hole) or copy-paste `Plug.Parsers` source code into their app to hack in raw body capture.

**Why it happens:** Stripe signs the raw HTTP body bytes with HMAC-SHA256. Any transformation (JSON parsing, whitespace normalization, key reordering) invalidates the signature. Phoenix's default plug pipeline parses bodies before user code sees them.

**Consequences:** Webhook verification fails in production. Developers disable verification (security vulnerability). Support burden from confused users dominates library issue trackers.

**Prevention:**
- Provide a dedicated `LatticeStripe.WebhookPlug` that captures the raw body before `Plug.Parsers` runs, using `Plug.Conn.read_body/2` and storing it in `conn.assigns` or `conn.private`
- Document the plug ordering requirement prominently: webhook plug MUST be placed before `Plug.Parsers` in the endpoint pipeline, or use a separate pipeline for the webhook route
- Provide a Phoenix router example showing the correct pipeline configuration
- Include a "troubleshooting webhook verification" guide in ExDoc

**Detection:** Users reporting "webhook signature verification failed" errors when using the library with Phoenix. Integration tests that parse JSON before verification will catch this early.

**Phase:** Foundation (Tier 0) -- webhook infrastructure must solve this from day one.

**Confidence:** HIGH -- documented extensively in ElixirForum, GitHub issues on stripity_stripe (#855), and the master research document.

---

### Pitfall 2: Global Application Config Instead of Per-Request Client Configuration

**What goes wrong:** The library stores API keys and configuration in `Application.get_env/3` (global process dictionary), making it impossible to use multiple Stripe accounts simultaneously. This breaks multi-tenant SaaS apps, Stripe Connect workflows (which need per-request `Stripe-Account` headers), and async test suites.

**Why it happens:** `Application.get_env` is the path of least resistance in Elixir. Early library versions (stripity_stripe v2) used it exclusively. But Elixir's application environment is global mutable state -- changing it in one process affects all others.

**Consequences:**
- Multi-tenant apps cannot use different API keys per tenant
- Stripe Connect (`stripe_account` header) requires per-request overrides that fight the global config
- Tests must use `async: false` because config changes in one test leak into concurrent tests
- Race conditions in production when multiple requests modify shared config

**Prevention:**
- Follow the modern StripeClient pattern (all official SDKs converged on this in 2024+): explicit client structs passed to every function call
- Accept `api_key`, `stripe_account`, `api_version`, `idempotency_key` as per-request options on every API call
- Use `Application.get_env` only as fallback defaults, never as the primary config mechanism
- Design the client struct to be created once and passed through -- `LatticeStripe.client(api_key: "sk_...")` returns a reusable struct
- This enables `async: true` in all user tests

**Detection:** Users filing issues about "how to use different API keys per request" or "Connect account header not working." Test suite requiring `async: false`.

**Phase:** Foundation (Tier 0) -- client configuration architecture must be correct from the start; retrofitting is a breaking change.

**Confidence:** HIGH -- official Stripe SDKs all moved to instance-based clients. ElixirForum threads and the Elixir Application docs explicitly warn against global config in libraries.

---

### Pitfall 3: Timing-Vulnerable Webhook Signature Comparison

**What goes wrong:** Using `==` or `===` to compare HMAC signatures allows timing attacks. An attacker can determine the correct signature byte-by-byte by measuring response times.

**Why it happens:** String equality operators in most languages short-circuit on the first differing byte. This is a subtle security issue that looks correct in code review.

**Consequences:** Webhook endpoint becomes vulnerable to signature forgery via timing side-channel. Attackers can forge webhook events to trigger actions in the application (refunds, subscription changes, etc.).

**Prevention:**
- Use Erlang's `:crypto.hash_equals/2` (available since OTP 25) or implement constant-time comparison via XOR-and-reduce pattern
- Never use `==`, `===`, or pattern matching for signature comparison
- Add explicit code comments explaining why constant-time comparison is required
- Test that the verification module uses the correct comparison function

**Detection:** Security audit or code review catching `==` in signature verification path. No runtime detection possible (that is the nature of timing attacks).

**Phase:** Foundation (Tier 0) -- webhook signature verification is a security-critical path.

**Confidence:** HIGH -- well-documented cryptographic best practice. Stripe's own documentation and all official SDKs use constant-time comparison.

---

### Pitfall 4: Structs That Break on Stripe API Changes

**What goes wrong:** Defining Elixir structs with `defstruct` for every Stripe resource field creates a rigid schema. When Stripe adds new fields (monthly), the library either drops them silently or requires a library update for every Stripe API change. When Stripe removes or renames fields, user code pattern-matching on struct fields breaks.

**Why it happens:** Elixir structs have a fixed set of keys defined at compile time. Stripe's API evolves constantly (the OpenAPI spec has 2,196+ releases). The temptation to provide "type-safe" structs conflicts with the reality of a rapidly changing upstream API.

**Consequences:**
- New Stripe fields silently dropped until library updates
- Users stuck on old library versions miss important response data
- Adding struct fields is technically a non-breaking change but removing them is breaking
- Pattern matching on struct module name (`%LatticeStripe.Customer{}`) couples user code to internal types

**Prevention:**
- Use structs with an `__extra__` or `metadata` catch-all map field that captures unknown keys from the API response
- Or use a hybrid approach: typed structs for well-known fields + pass-through map for the rest
- Store the raw decoded map alongside parsed fields (the Pay gem's `object` column pattern)
- Provide `Access` behaviour implementation so users can do `customer[:unknown_field]`
- Document that structs represent the library's known fields, not the complete Stripe response
- Consider making struct fields liberal (allow nil for most fields) since Stripe responses vary by expand options and API version

**Detection:** Users reporting "missing field X in response" issues. Stripe changelog showing new fields not reflected in library structs.

**Phase:** Foundation (Tier 0) -- response type design is architectural and cannot be easily changed later.

**Confidence:** HIGH -- stripity_stripe's GitHub issues (#878, #879, #568) are dominated by missing/incorrect struct fields. This is the primary maintenance burden of any Stripe library.

---

### Pitfall 5: Incorrect Retry Logic That Causes Double Charges

**What goes wrong:** Retrying non-idempotent requests (or retrying with a new idempotency key) after ambiguous failures (timeouts, 500s) can cause duplicate charges, double subscription creations, or other duplicate side effects.

**Why it happens:** Network timeouts and 500 errors are ambiguous -- the request may have succeeded server-side before the client received the response. Retrying with a different idempotency key creates a new operation. Retrying without an idempotency key on POST endpoints also creates a new operation.

**Consequences:** Customers charged twice. Duplicate subscriptions created. Duplicate refunds issued. Financial and trust damage that is difficult to recover from.

**Prevention:**
- Auto-generate idempotency keys for all POST requests (Stripe recommends this)
- On retry, always reuse the same idempotency key (this is the entire point of idempotency)
- Respect the `Stripe-Should-Retry` response header -- Stripe explicitly tells you when retrying is safe
- Do NOT retry 400-level errors (except 409 Conflict and 429 Rate Limit)
- DO retry 500+ errors and network errors, but with the same idempotency key
- Implement exponential backoff with jitter to avoid thundering herd
- Document that idempotency keys expire after 24 hours
- Raise/warn if user provides an idempotency key AND the library would auto-generate one (avoid confusion)
- Handle the idempotency error case where parameters differ from the original request

**Detection:** Users reporting duplicate charges or subscriptions. Stripe dashboard showing duplicate objects with different IDs but same parameters.

**Phase:** Foundation (Tier 0) -- retry and idempotency logic is core HTTP infrastructure.

**Confidence:** HIGH -- Stripe's official blog post on idempotency design, official SDK implementations, and API documentation all detail these requirements.

---

## Moderate Pitfalls

### Pitfall 6: Finch Pool Lifecycle Mismanagement

**What goes wrong:** The library either (a) forces users to start a Finch pool in their supervision tree with a specific name the library expects, creating tight coupling, or (b) starts its own Finch pool via an OTP application, creating an unnecessary process that conflicts with users' existing Finch instances. Libraries should not start processes users do not expect.

**Why it happens:** Finch requires a named process started in a supervision tree. The question of "who owns the Finch pool" is a design decision with no obvious right answer for a library.

**Prevention:**
- Accept a Finch pool name as a client configuration option (e.g., `LatticeStripe.client(finch: MyApp.Finch)`)
- Provide sensible defaults: if no Finch name given, check if a well-known default exists or start a supervised pool lazily
- Use the Transport behaviour so users can swap out Finch entirely
- Document clearly: "LatticeStripe does not start its own HTTP connection pool. You must include Finch in your supervision tree."
- Provide a copy-paste supervision tree example in the README

**Detection:** Users reporting "Finch pool not started" errors or "I already have Finch, how do I reuse it?"

**Phase:** Foundation (Tier 0) -- transport layer architecture.

**Confidence:** MEDIUM -- this is an Elixir ecosystem convention issue. The Dashbit blog post on Req-based SDKs sidesteps it by using Req (which manages its own pools), but for a Finch-based library this is a real design decision.

---

### Pitfall 7: Auto-Pagination Streams That Exhaust Rate Limits or Memory

**What goes wrong:** Elixir Streams are lazy, which is great for pagination. But without guardrails, `Stream.map(pages, &process/1) |> Enum.to_list()` will eagerly fetch ALL pages, potentially hitting Stripe's rate limit (100 requests/second per API key) or loading millions of objects into memory.

**Why it happens:** Developers unfamiliar with Stripe's data volumes treat auto-pagination like iterating a small list. Stripe accounts can have millions of customers, charges, or events.

**Consequences:** Rate limit errors (429) cascading through the stream. OOM crashes from materializing large lists. Long-running requests that time out.

**Prevention:**
- Document that `Stream` functions are lazy but `Enum` functions materialize everything
- Provide a `max_pages` or `max_items` option on auto-pagination to prevent runaway fetches
- Log or emit telemetry events at page boundaries so users can monitor progress
- Consider built-in rate limiting (respect `Retry-After` headers on 429 responses)
- Provide both `stream_` variants (lazy) and `list_` variants (single page) so the API makes the distinction clear
- Document examples showing `Stream.take/2` for bounded iteration

**Detection:** Users reporting 429 errors when paginating. High memory usage when listing large collections.

**Phase:** Foundation (Tier 0) -- pagination is core infrastructure.

**Confidence:** MEDIUM -- documented in stripe-node issue #575 and general Stripe pagination docs. The Elixir Stream integration is novel territory without direct precedent.

---

### Pitfall 8: API Version Mismatch Between Library Structs and Actual Responses

**What goes wrong:** The library pins to a specific Stripe API version but allows per-request version overrides. When a user overrides the version, the response shape may differ from what the library's structs/decoders expect, causing decoding failures or silently dropped data.

**Why it happens:** Stripe's API version affects response shapes (field names, nesting, presence of fields). The library's decoders are written against one version but users can send any version.

**Consequences:** Decoding crashes on unexpected response shapes. Silent data loss when fields are renamed between versions. Confusing error messages that don't mention version mismatch as the cause.

**Prevention:**
- Pin a default API version per library release (document it prominently)
- When users override the version, log a warning that response shapes may differ from library expectations
- Make decoders tolerant of unknown/missing fields (do not crash on unexpected keys)
- Test against at least two API versions in CI
- Document which Stripe API version the library is built against in the module docs and README
- Consider the Java SDK bug (v27.x.y) as a cautionary tale: version pinning bugs can cascade

**Detection:** Users reporting decoding errors after setting a custom API version. Stripe deprecation notices for the pinned version.

**Phase:** Foundation (Tier 0) -- response decoding architecture.

**Confidence:** HIGH -- documented in Stripe's versioning docs and the Java/dotnet SDK version pinning bug.

---

### Pitfall 9: Expand Parameter Handling That Degrades Performance

**What goes wrong:** The library makes it too easy to expand deeply nested objects on list endpoints, causing Stripe to return massive payloads that are slow to generate and slow to decode. Users copy-paste expand examples without understanding the performance implications.

**Why it happens:** Stripe supports up to 4 levels of expansion nesting. On list endpoints with 100 items, each expansion multiplies the response size. A `list customers` with `expand: ["data.subscriptions.data.default_payment_method"]` on 100 customers generates an enormous response.

**Prevention:**
- Document performance implications of expand on list endpoints prominently
- Consider warning or raising when expand depth exceeds 2 on list endpoints
- Provide examples showing the right way: fetch the list, then expand on individual retrieve calls
- Validate expand paths at request build time (catch typos before the API call)

**Detection:** Users reporting slow API calls or timeouts on list endpoints with expansions.

**Phase:** Foundation (Tier 0) -- expand is part of request building.

**Confidence:** MEDIUM -- Stripe's own docs warn about this. Less of a library design pitfall and more of a documentation/DX pitfall.

---

### Pitfall 10: Testing Strategy That Creates Brittle or Meaningless Tests

**What goes wrong:** The library either (a) encourages mocking at the wrong level (mocking HTTP responses with hardcoded JSON, creating tests that pass but don't verify real behavior), or (b) requires a live Stripe test-mode key for all tests (slow, flaky, requires network, leaks test data into Stripe dashboard).

**Why it happens:** Stripe's `stripe-mock` is stateless and limited. VCR/cassette recording captures exact responses but breaks when the API changes. Mocking at the HTTP level is easy but tests nothing meaningful. There is no perfect testing strategy.

**Prevention:**
- Use the Transport behaviour as the test seam: provide a `LatticeStripe.Transport.Mock` or document how to use Mox with the Transport behaviour
- Test at the right level: unit test request building and response decoding with known fixtures; integration test against stripe-mock or Stripe test mode for API correctness
- Provide test helpers that make it easy to build fixture data (e.g., `LatticeStripe.Testing.customer_fixture()`)
- Document the recommended testing strategy: Mox the transport for unit tests, stripe-mock for integration, Stripe test mode for smoke tests
- Make the test helper module opt-in (`use LatticeStripe.Testing` or a separate hex package)

**Detection:** Users asking "how do I test my Stripe integration?" on forums. Users with 100% passing tests that break in production.

**Phase:** Developer Experience -- but the Transport behaviour enabling this must be in Foundation.

**Confidence:** MEDIUM -- PaperTiger's existence validates this is a real pain point. The testing strategy is well-understood in principle but poorly executed in practice across the ecosystem.

---

## Minor Pitfalls

### Pitfall 11: Inconsistent Error Shapes Across Endpoints

**What goes wrong:** Different API calls return errors in different shapes (card errors have `decline_code`, validation errors have `param`, rate limit errors have `Retry-After` header). The library normalizes some but not all, leaving users to handle raw maps for edge cases.

**Prevention:**
- Define a clear error type hierarchy: `LatticeStripe.Error.CardError`, `.InvalidRequestError`, `.AuthenticationError`, `.RateLimitError`, `.APIError`, `.ConnectionError`
- Each error type carries all relevant fields for that category
- Pattern matching on error types should be the primary error handling mechanism
- Include `request_id` on every error for support debugging

**Phase:** Foundation (Tier 0).

**Confidence:** HIGH -- Stripe's error hierarchy is well-documented and all official SDKs implement it.

---

### Pitfall 12: Not Preserving Request ID for Debugging

**What goes wrong:** When users contact Stripe support, the first thing support asks for is the `Request-Id` header. If the library discards response headers, users cannot provide this, making debugging production issues extremely difficult.

**Prevention:**
- Include `request_id` on every successful response and error response
- Make it accessible without digging into raw HTTP headers
- Log it via Telemetry events so it appears in structured logs automatically
- Consider a "raw response" mode that returns full headers alongside the parsed body

**Phase:** Foundation (Tier 0).

**Confidence:** HIGH -- every official Stripe SDK surfaces request_id prominently.

---

### Pitfall 13: Blocking the Caller During Pagination

**What goes wrong:** Synchronous pagination (fetch page, process, fetch next page) blocks the calling process. In a Phoenix request handler, this means the connection is held open for the entire pagination duration.

**Prevention:**
- Use Elixir Streams (lazy evaluation) so callers can process items incrementally
- Document that long-running pagination should be done in a background Task or GenServer, not in a Phoenix controller
- Consider providing a `LatticeStripe.Task` helper for background processing patterns

**Phase:** Foundation (Tier 0) for Stream-based pagination. Developer Experience for helpers.

**Confidence:** LOW -- this is more of a usage pattern issue than a library design flaw. Most users will not paginate millions of records.

---

### Pitfall 14: Hex Package Name Collision or Confusion

**What goes wrong:** Publishing a Stripe-related package on Hex with a name that is too generic, conflicts with existing packages, or is confusable with the incumbent (`stripity_stripe`). Users install the wrong package.

**Prevention:**
- `lattice_stripe` is already chosen and verified unique on Hex -- this pitfall is mitigated
- Use `LatticeStripe` module prefix consistently (not `Stripe` which would conflict)
- Document the distinction from `stripity_stripe` in the README for users searching

**Phase:** Pre-development (already resolved).

**Confidence:** HIGH -- the `lattice-stripe-oss-lib-name.md` research document addresses this.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Foundation: HTTP Transport | Finch pool ownership confusion (Pitfall 6) | Transport behaviour + documented supervision tree |
| Foundation: Client Config | Global config anti-pattern (Pitfall 2) | Per-request client struct from day one |
| Foundation: Error Handling | Inconsistent error shapes (Pitfall 11) | Comprehensive error type hierarchy |
| Foundation: Retry Logic | Double charges from bad retries (Pitfall 5) | Auto-idempotency + Stripe-Should-Retry |
| Foundation: Response Types | Rigid structs breaking on API changes (Pitfall 4) | Tolerant decoders with extra field capture |
| Foundation: Pagination | Rate limit exhaustion (Pitfall 7) | Stream-based with guardrails and telemetry |
| Foundation: API Versioning | Version mismatch decoding failures (Pitfall 8) | Tolerant decoders + version warning |
| Webhooks | Raw body consumption (Pitfall 1) | Dedicated Plug with raw body capture |
| Webhooks | Timing attack on signature (Pitfall 3) | Constant-time HMAC comparison |
| Testing/DX | Brittle or meaningless tests (Pitfall 10) | Transport behaviour as test seam + fixtures |
| All phases | Request ID not preserved (Pitfall 12) | Surface request_id on every response/error |

## Sources

- [ElixirForum: Is Stripity Stripe maintained?](https://elixirforum.com/t/is-stripity-stripe-maintained/73673)
- [Dashbit Blog: SDKs with Req: Stripe](https://dashbit.co/blog/sdks-with-req-stripe)
- [Stripe: Designing robust APIs with idempotency](https://stripe.com/blog/idempotency)
- [Stripe: Idempotent requests API docs](https://docs.stripe.com/api/idempotent_requests)
- [Stripe: Webhook signature verification](https://docs.stripe.com/webhooks/signature)
- [Stripe: API versioning](https://docs.stripe.com/api/versioning)
- [Stripe: Expanding responses](https://docs.stripe.com/api/expanding_objects)
- [Stripe: Automated testing](https://docs.stripe.com/automated-testing)
- [Stripe: Pagination](https://docs.stripe.com/api/pagination)
- [stripe-node: Auto-pagination rate limiting issue #575](https://github.com/stripe/stripe-node/issues/575)
- [stripe-node: Webhook signature verification issue #341](https://github.com/stripe/stripe-node/issues/341)
- [stripity-stripe: GitHub issues](https://github.com/beam-community/stripity-stripe/issues)
- [Elixir: Application behaviour docs (global config warning)](https://hexdocs.pm/elixir/Application.html)
- [Elixir: Design-related anti-patterns](https://hexdocs.pm/elixir/design-anti-patterns.html)
- [Michal Muskala: Configuring Elixir Libraries](https://michal.muskala.eu/post/configuring-elixir-libraries/)
- [Felt: Tips for improving Elixir configuration](https://felt.com/blog/elixir-configuration)
- [stripe-mock: GitHub (statelessness limitations)](https://github.com/stripe/stripe-mock)
- [Stripe: SDK versioning and support policy](https://docs.stripe.com/sdks/versioning)
- [Hacker News: Stripe Elixir support frustration](https://news.ycombinator.com/item?id=24436079)
- Master research document: `/prompts/The definitive Stripe library gap in Elixir - a master research document.md`
