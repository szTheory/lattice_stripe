# v1.12 Next-Milestone Assessment — API Freshness and Adopter Confidence

Updated: 2026-09-23
Status: Assessment complete; candidate only; no milestone started

## Intent Preserved

Make LatticeStripe a Stripe SDK Elixir teams can trust across common business models and
application contexts. Raise correctness, ergonomics, operator confidence, code clarity, and
proof quality where that meaningfully helps adopters. Use breadth research to discover real
gaps, not to create an endpoint-count race. Apply the Pareto principle and account for the
maintenance cost of every public capability.

Evaluate the library through the people who integrate and operate it: application engineers,
billing and finance operators, support and on-call staff, platform teams, security/privacy
reviewers, and SDK maintainers. Consider B2C and B2B SaaS, usage-priced products, commerce and
digital goods, Connect platforms, and regulated/high-sensitivity domains. LatticeStripe owns
Stripe-shaped HTTP resources, typed decoding, retries, errors, telemetry, and test helpers;
the adopting application owns domain policy, compliance, billing orchestration, and durable
business state.

The preferred future confidence model is one small Phoenix adopter app importing
LatticeStripe as a dependency, with a common SaaS spine and a few opt-in profiles for distinct
contracts such as B2B invoicing, usage reconciliation, and Connect tenant context. Do not
build one app per industry or turn the examples into an application billing engine.

## Assessment Method and Provenance

Repo evidence reviewed on 2026-09-23: `PROJECT.md`, `ROADMAP.md`, `STATE.md`,
`MILESTONES.md`, `JTBD-MAP.md`, the post-v1.x maintenance thread, v1.11 audit, README,
scope and adopter guides, CI/drift workflows, API field decoding, and representative tests.
The assessment ran `mix ci`, `mix lattice_stripe.check_drift --summary`, and the detailed
`mix lattice_stripe.check_drift`; findings below preserve the output date and counts. Stripe
release evidence comes from the official [API changelog](https://docs.stripe.com/changelog)
and [API versioning guide](https://docs.stripe.com/api/versioning). No personal data or
secret values are copied into this thread.

## Current Adopter Story

LatticeStripe is a low-level, production-oriented Stripe HTTP SDK, not a Phoenix billing
engine. It already supports mainstream payments, Checkout, subscriptions, invoices, quotes,
metering, Connect, tax, entitlements, snapshot and thin-event webhooks, operations, and test
helpers. The README quick-start is exercised against stripe-mock, and CI has separate unit,
coverage, compatibility, optional-dependency, and stripe-mock integration checks.

It serves Phoenix/Elixir SaaS teams well when they want direct Stripe primitives and a clear
escape hatch. The main verified rough edge is not missing data: newly discovered Stripe
response fields are preserved in each resource's `extra` map. The gap is that meaningful new
fields are not first-class typed fields, and the drift checker does not classify additions by
Stripe API version, adopter impact, or preview status.

**Done estimate: 94–96% for the stated mainstream SaaS SDK scope.** The quality and core
flows are mature; a bounded API freshness wedge remains. “For everybody” means predictable
Stripe primitives across adopter contexts, not every industry policy or Stripe product family.

## Current Quality Signals

| Quality lens | Assessment | Evidence / next question |
| --- | --- | --- |
| API correctness and coverage | Strong mainstream surface; current freshness wedge | 104 candidate fields need version- and adopter-aware triage; unknown response fields remain available in `extra` |
| Public API stability and compatibility | Strong contract | Exact 3,463-entry lock; supported Elixir/OTP CI matrix; decide API-version change separately |
| Reliability and failure semantics | Strong foundation | Retry, idempotency, pagination/streaming, webhook verification, telemetry, and operator guidance are present; use host app to probe joined boundaries |
| CI, test signal, and efficiency | Strong and explicit | `mix ci`, separate integration/coverage/optional-dependency jobs, pinned services; no current evidence for a broad CI redesign |
| Security, privacy, and data handling | Prior STRIDE close is clean; no personal data or real credential was identified in this review | Redaction and credential boundaries are tested; preserve synthetic data and repeat a redacted scan when introducing adopter fixtures |
| Performance and BEAM operation | Useful primitives documented | Lazy streams, batching, per-operation timeouts, warm-up, circuit breaker, and telemetry exist; no evidence yet for another performance feature |
| Developer ergonomics and onboarding | Strong guides and tested entry path | README snippets and canonical docs are covered; a host-app import/supervision test remains a potential gap |
| Maintainability and scope discipline | Strong after reader-first close | Private client decomposition, wrapper/fixture consolidation, and clear SDK/application boundary; avoid introducing generators or abstractions without proof |
| Release and supply-chain confidence | Strong recent release process | 2.2.2 provenance and package gates are recorded in v1.11 audit; routine dependency/security upkeep continues |
| Accessibility / visual UX | Not applicable to the SDK surface | No browser UI is shipped; keep interface quality focused on Elixir API, error messages, docs, and operational behavior |

- Fresh `mix ci`: 2,453 tests, 0 failures, 1 documented skip; 203 tagged tests excluded from
  the default test task. Credo checked 389 source files and 2,376 modules/functions with no
  issues. CI also checks format, warnings-as-errors compilation, API surface, version prose,
  and docs.
- Public API snapshot remains 3,463 entries. Package line is 2.2.2. CI covers Elixir/OTP
  minimum and current supported combinations, compiles without optional dependencies, enforces
  an 80% coverage floor, and runs pinned stripe-mock integrations.
- The v1.11 audit records 0 open high/medium security threats and verified release provenance.
  The configured local git author email had no exact match in tracked files. Ten non-reserved
  email-like strings were reviewed by path and masked context: they are sample/test addresses,
  public vendor material, or a role-based security contact, not personal contact data. Gitleaks
  returned 15 generic-key candidates; masked context review classified them as placeholder
  idempotency keys/client-secret examples or generated/dependency documentation examples, not
  credentials. Candidate values were not copied here. This targeted review cannot prove that
  every possible personal detail is absent, so continue to avoid real adopter data in fixtures.
- There is no StreamData/PropCheck-style dependency or separate host application. Existing
  hand-authored tests are extensive; this alone does not establish a property-testing gap.

## Stripe API Freshness Findings

The SDK currently pins `2026-03-25.dahlia`. The official changelog contains a newer
`2026-08-26.dahlia` stable entry as of this assessment. It includes new behaviors in existing
surfaces and also a breaking removal of `payment_method_types` from PaymentIntents and
SetupIntents. For example, see Stripe's [removal notice](https://docs.stripe.com/changelog/dahlia/2026-08-26/removes-payment-method-types-parameter-from-payment-intents-setup-intents.md).
Do not update the SDK default version by date alone.

The repository drift checker fetched Stripe OpenAPI `master` on 2026-09-23 and reported:

| Signal | Result | Interpretation |
| --- | ---: | --- |
| Modeled resource modules with drift | 31 | Not an API-version-specific count |
| Candidate field additions | 104 across 23 modules | Requires manual version, relevance, and semantic triage |
| Spec-mismatch removal warnings | 155 across 21 modules | Checker itself identifies these as frequent OpenAPI shape noise; do not delete fields automatically |
| Unmodeled object types | 94 | Mix of specialist resources, nested/event objects, and other types; not equivalent to 94 missing adopter workflows |

Examples among modeled mainstream resources include subscription billing/presentment fields,
Checkout session options, invoice payments/tax/parent structures, customer tax/account fields,
and new payment-method variants. Since `from_map/1` preserves unrecognized fields in `extra`,
this is primarily a typed ergonomics and API freshness issue, not demonstrated response-data
loss. The checker exits nonzero while drift exists by design; the weekly radar classifies
additions as action items and does not treat all raw counts as release blockers.

## Candidate Wedges, Ranked

### 1. API freshness for already-supported mainstream resources — recommended next

**Why:** Fresh drift evidence identifies a concrete, ongoing Stripe contract gap; typed access
to high-value new fields helps application engineers and operators without expanding into
unproven product families.

**Done enough:** Classify candidates against stable/versioned Stripe sources; select fields by
common adopter job, operational value, and type/decode safety; add focused tests and docs
truth where public behavior changes; decide the default API version separately after
compatibility tests. Preserve `extra` behavior and the existing public API stability contract.

**Overbuild line:** Promoting all 104 candidates, treating all 94 object types as missing
wrappers, or changing the default Stripe version without testing old/new request and event
semantics.

### 2. Minimal Phoenix adopter (“digital twin”) — pair with or follow the API wedge

**Why:** A real host project can expose dependency/configuration/supervision and integrated
webhook friction that module tests and stripe-mock cannot show. The adopter segmentation now
has a durable home in `JTBD-MAP.md`.

**Done enough:** One private/test-only Phoenix app imports the package via a path dependency
and exercises a common Checkout/subscription/webhook spine, plus only the profile(s) needed
to prove a distinct Connect, B2B, or usage contract. CI uses synthetic data and no live Stripe
credentials.

**Overbuild line:** Multiple full sample products, production deployment infrastructure, or
implementing each industry's business rules.

### 3. Selective property-based tests — evidence-gated

**Why:** Generated cases can cover state spaces around encoding, pagination, redaction, retry,
and webhook boundaries better than a few examples, but no uncovered invariant is demonstrated
yet.

**Done enough:** Add a test-only property library only after the assessment names a high-risk
pure invariant that benefits from generators and shrinking; retain deterministic examples for
readability.

**Overbuild line:** Blanket property conversion, a new dependency for trivial cases, or a
vanity coverage ratchet.

### 4. Specialist resource families and vertical behavior — pull-driven

**Why:** They may help particular fintech/platform, healthcare, gaming, or commerce adopters,
but resource presence alone is not demand and some families introduce material product and
compliance complexity.

**Done enough:** A named adopter job, stable Stripe contract, clear SDK/application boundary,
and testable ongoing support path.

**Overbuild line:** Adding Identity, Treasury, Issuing, Terminal, Financial Connections,
Reporting, Sigma, or Climate solely for completeness.

## Recommendation and Ordering

The highest-leverage next milestone candidate is **API Contract Freshness and Adopter Proof**:
version-aware triage of the current drift plus a minimal host-app proof for a common SaaS flow
and only the edge profiles that demonstrate distinct SDK contracts. Keep the default API pin
unchanged until compatibility evidence justifies a deliberate move. Do not start a milestone
from counts alone; phase planning should set the exact field subset after changelog and OpenAPI
triage.

Order after that: targeted property tests only for invariants exposed by the first milestone;
then adopter-driven specialist resource families. Continue routine bug/security/dependency
maintenance throughout. The roadmap horizons and refresh rule are in `.planning/ROADMAP.md`.

## Maintainer Takeaway

The library already has unusually broad and credible quality gates. The next gains come from
turning noisy API drift into a version-aware adopter priority list and proving a small number
of real consumer paths. “Make it the best” means fewer surprising gaps and clearer evidence,
not zero unmodeled Stripe object types.
