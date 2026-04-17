# Pitfalls Research

**Domain:** Adding Stripe resource families (Dispute, CreditNote, Mandate, SetupAttempt, File/FileLink, Quote) + DX polish to existing Elixir SDK
**Researched:** 2026-04-16
**Confidence:** HIGH (official Stripe API docs + direct codebase analysis); MEDIUM where noted

---

## Critical Pitfalls

### Pitfall 1: File Upload Hits `api.stripe.com` Instead of `files.stripe.com`

**What goes wrong:**
The Stripe Files API lives at `https://files.stripe.com/v1/files`, not
`https://api.stripe.com/v1/files`. If the SDK's `base_url` is not overridden in
`File.create/3`, Stripe will return a routing error or 404. FileLink creation
(`POST /v1/file_links`) does use `api.stripe.com`, so only the upload step
requires the alternate host.

**Why it happens:**
Every other resource in LatticeStripe uses `api.stripe.com`. Finch transport is
built around a single `base_url` on the `Client` struct. A developer implementing
`File.create/3` by copying `Invoice.create/3` will miss the subdomain difference.

**How to avoid:**
Hardcode `"https://files.stripe.com/v1/files"` as the URL in `File.create/3`
rather than deriving it from `client.base_url`. Alternatively, add a
`files_base_url` field to `Client` (defaulted to `"https://files.stripe.com"`)
so integration tests can override it to point at a stripe-mock instance. Verify
whether stripe-mock routes `/v1/files` at the default port; if not, add a Mox
unit test for the multipart body shape and flag the integration test as
infrastructure-dependent.

**Warning signs:**
- `404 Not Found` or unexpected error on `File.create` in integration tests
- URL constructed from `Client.base_url <> "/v1/files"` in the module body

**Phase to address:** File & FileLink phase.

---

### Pitfall 2: Multipart Body Missing `boundary` Parameter in `Content-Type` Header

**What goes wrong:**
Stripe's Files API requires `Content-Type: multipart/form-data; boundary=<value>`.
If the header is set to `"multipart/form-data"` without the boundary parameter,
Stripe (and Finch/Mint internally) rejects the request. The Elixir Forum records
at least one instance of Finch returning "no multipart boundary param in
Content-Type" for this exact mistake.

The boundary value must appear in two places: the `Content-Type` header and as
the delimiter between parts in the body (`--<boundary>\r\n` ... `--<boundary>--`).

**Why it happens:**
Elixir has no stdlib multipart encoder. Developers set the Content-Type from
memory or copy a curl command — curl auto-appends `; boundary=...` transparently,
so the header looks complete when it is not.

**How to avoid:**
Generate a random boundary (e.g., `:crypto.strong_rand_bytes(16) |> Base.encode16()`).
Build the multipart body manually or via the `Multipart` hex library. The minimal
body structure for Stripe file upload:

```
--<boundary>\r\n
Content-Disposition: form-data; name="purpose"\r\n
\r\n
dispute_evidence\r\n
--<boundary>\r\n
Content-Disposition: form-data; name="file"; filename="evidence.pdf"\r\n
Content-Type: application/pdf\r\n
\r\n
<binary file bytes>\r\n
--<boundary>--\r\n
```

Set the header as `{"content-type", "multipart/form-data; boundary=#{boundary}"}`.
Do not use `FormEncoder` (URL-encoded form) for this endpoint — it is exclusively
for `application/x-www-form-urlencoded` requests.

**Warning signs:**
- `400` or `415` from Stripe on file creation
- `content-type` header is a plain string without `boundary=` appended
- `FormEncoder.encode/1` called inside `File.create/3`

**Phase to address:** File & FileLink phase.

---

### Pitfall 3: Quote PDF Endpoint Returns Binary, Not JSON — Standard Pipeline Crashes

**What goes wrong:**
`GET /v1/quotes/:id/pdf` returns a raw PDF binary stream with `Content-Type: application/pdf`,
not a JSON object. The existing `Client.request/2` pipeline calls `Jason.decode!`
on every response body. Routing the PDF endpoint through the standard pipeline
causes a `Jason.DecodeError` at decode time or returns garbled data.

**Why it happens:**
Every other endpoint in LatticeStripe is JSON. Implementing `Quote.pdf/3` by
copying another `get` function will accidentally send the PDF bytes through
`Jason.decode!`.

**How to avoid:**
Add a `raw: true` option to `Client.request/2` (or a dedicated
`Client.request_raw/2` variant) that skips JSON decoding and returns
`{:ok, binary()}` directly. `Quote.pdf/3` must use this path. The return type
annotation must be `{:ok, binary()} | {:error, Error.t()}`, clearly distinct
from other `Quote` functions.

Also validate the quote status before calling: the PDF is only generated for
`open` or `accepted` quotes. Calling against a `draft` or `canceled` quote
returns a Stripe 404. `Quote.pdf/3` should document this precondition prominently.

**Warning signs:**
- `Jason.DecodeError` in tests for `Quote.pdf/3`
- Return type annotated as `{:ok, Quote.t()}`
- No status precondition note in `@doc`

**Phase to address:** Quote phase.

---

### Pitfall 4: Dispute Evidence Submission Replaces All Fields — Partial Updates Silently Drop Previous Evidence

**What goes wrong:**
`PATCH /v1/disputes/:id` with an `evidence` hash is not an incremental merge.
Any call to update dispute evidence submits the entire provided hash for review.
If a user calls `update_evidence` with only `customer_email`, then calls it
again with only `service_documentation`, the second call does not include the
email — Stripe only retains what was in the most recent submission.

If the SDK exposes a naive `update/3` with no documentation of this behavior,
users lose previously-set evidence fields silently. There is no undo.

**Why it happens:**
Standard PATCH semantics imply "send only what you want to change." Stripe
dispute evidence deviates from this expectation — the full intended evidence
set must be sent in each call.

**How to avoid:**
Document this prominently in `@moduledoc` and in each `update_evidence` `@doc`.
The recommended pattern is: retrieve the current dispute with
`Dispute.retrieve/3`, merge desired changes onto `dispute.evidence` in the
calling code, then submit the combined map. Do not implement implicit merge
logic inside the SDK — that would require a hidden HTTP round-trip and violates
the principle that SDK functions make exactly one request per call.

**Warning signs:**
- Integration test makes two sequential evidence update calls without retrieving
  first, and does not assert both fields are present after the second call
- `@doc` for `update_evidence` does not mention the full-replace behavior

**Phase to address:** Dispute phase.

---

### Pitfall 5: Dispute Evidence `submit: true` Is Irreversible — Wrong Default Locks the Dispute

**What goes wrong:**
Including `submit: true` in the `evidence` hash locks the dispute — Stripe
will reject any further evidence updates with an error. If the SDK defaults
`submit` to `true` (or includes it in a guide example without a warning), users
accidentally lock disputes before they have finished gathering evidence.

Stripe's own guide examples use `submit: true`. New implementers copy the example
and make it the default.

**Why it happens:**
The Stripe guide code snippets include `submit: true` as a working example.
Developers ship the guide example as the function's default behavior without
reading the irreversibility note.

**How to avoid:**
Omit `submit` from the request params by default. Users opt in by passing
`submit: true` explicitly. Add a `@doc` warning:
"Passing `submit: true` locks evidence submission — no further updates are
accepted. Default omits `submit`; Stripe treats omission as `false`."

**Warning signs:**
- Function signature includes `submit: true` in default opts
- Integration test calls `update_evidence` with `submit: true` and then a
  subsequent update succeeds — this would indicate a testing gap, not a fix

**Phase to address:** Dispute phase.

---

### Pitfall 6: CreditNote Cannot Be Created on a `draft` Invoice — Integration Tests Must Finalize First

**What goes wrong:**
`CreditNote.create/3` against a `draft` invoice returns a Stripe 400. Credit
notes can only be applied to finalized invoices (`open` or `paid`). Integration
tests that create a draft invoice and immediately try to credit it will fail
against stripe-mock with an unintuitive error.

Additionally, `CreditNote.void/3` has a further constraint: voiding is only
possible on credit notes attached to `open` invoices, not `paid` ones. A voided
credit note reverses its adjustment, increasing the amount due on the invoice.

**Why it happens:**
Developers assume credits work on any invoice, analogous to adding InvoiceItems
to a draft. The Stripe constraint is Invoice lifecycle-gated and is buried in
the CreditNote guide, not the `create` endpoint description.

**How to avoid:**
Document the `open` or `paid` precondition in `CreditNote` `@moduledoc`.
All integration test fixtures for CreditNote must call `Invoice.finalize/3`
before `CreditNote.create/3`. Add a `credited_invoice_fixture/2` helper to
`test/support/fixtures/credit_note.ex` that creates and finalizes. Document
void semantics separately: void is only valid on `open`-invoice credit notes.

**Warning signs:**
- Integration test creates a draft invoice then immediately calls `CreditNote.create/3`
- `CreditNote` `@moduledoc` does not mention invoice state requirements

**Phase to address:** CreditNote phase.

---

### Pitfall 7: CreditNote Line Items Require an Explicit `type` Field — Two Incompatible Subtypes

**What goes wrong:**
CreditNote line items have a `type` field with two values:
- `"invoice_line_item"` — credits a specific line on the original invoice;
  requires an `invoice_line_item` reference ID
- `"custom_line_item"` — freeform credit; requires `description`, `quantity`,
  `unit_amount`

Omitting `type` causes a Stripe 400. Passing `invoice_line_item` params for a
`"custom_line_item"` entry (or vice versa) also fails. The two subtypes are
documented only in the `credit_notes/line_item` sub-resource API page, not on
the main CreditNote creation page.

**Why it happens:**
The `type` distinction is not obvious from the CreditNote overview. Developers
model `lines` as a flat list of maps without enforcing `type`, ship it, and hit
validation errors in production.

**How to avoid:**
Define `CreditNote.LineItem` with `type`, `invoice_line_item`, `unit_amount`,
`quantity`, `description`, and `tax_amounts` fields. Mirror the structure of
`Invoice.LineItem` already in the codebase. The create-guide example must show
both subtype patterns with working minimal params.

**Warning signs:**
- `from_map/1` returns plain maps instead of `%CreditNote.LineItem{}` structs
- Guide or test only covers one subtype

**Phase to address:** CreditNote phase.

---

### Pitfall 8: Mandate and SetupAttempt Are Read-Only — Implementing CRUD Verbs Causes 404s

**What goes wrong:**
`Mandate` has exactly one API endpoint: `GET /v1/mandates/:id`. `SetupAttempt`
has `GET /v1/setup_attempts/:id` and `GET /v1/setup_attempts` (list). Neither
resource can be created, updated, or deleted via the API. Adding `create/3` or
`update/3` by analogy with other resources will return 404 from Stripe and
stripe-mock.

**Why it happens:**
LatticeStripe resource modules follow the CRUDL pattern. Developers scaffolding
a new module copy an existing one (e.g., `Refund`) which includes all five verbs.

**How to avoid:**
`LatticeStripe.Mandate` exposes only `retrieve/3`. `LatticeStripe.SetupAttempt`
exposes `retrieve/3` and `list/3`. Add a comment at the top of each module:
`# Stripe API: read-only resource. No create/update/delete endpoints exist.`

Document that mandates are created implicitly by Stripe when a PaymentIntent or
SetupIntent with `mandate_data` is confirmed. Document that SetupAttempts are
created by Stripe on each SetupIntent confirmation.

**Warning signs:**
- Module defines `create/3`, `update/3`, or `delete/3`
- Integration test attempts to create a Mandate directly

**Phase to address:** Mandate & SetupAttempt phase.

---

### Pitfall 9: Mandate `payment_method_details` Has 15+ Variants — Over-Modeling Creates Maintenance Debt

**What goes wrong:**
`payment_method_details` on a Mandate contains conditional sub-objects for
every supported payment method: `sepa_debit`, `bacs_debit`, `acss_debit`,
`paypal`, `payto`, `pix`, `upi`, `us_bank_account`, `amazon_pay`, `au_becs_debit`,
`card`, `cashapp`, `klarna`, `link`, `naver_pay`, and others. Typing all 15+
variants in v1.3 creates excessive boilerplate and a maintenance surface that
must be updated every time Stripe adds a new payment method.

The same applies to `SetupAttempt.payment_method_details`, which has similarly
broad payment-method coverage.

**Why it happens:**
The impulse toward completeness and the `from_map/1` + nested struct pattern
scales poorly here. The existing approach (e.g., `Payout.TraceId` for a single
nested struct) does not foreshadow this combinatorial case.

**How to avoid:**
For v1.3, store `payment_method_details` as a plain map on `Mandate` and
`SetupAttempt` structs. Add a `TODO v1.4: typed payment_method_details variants`
comment. The `extra` map fallback ensures no crash on unknown variants. The only
case where typed sub-structs are warranted for v1.3 is if a payment method type
is already modeled elsewhere in LatticeStripe (`card`, `sepa_debit`) — and even
then, only if there is concrete downstream demand.

**Warning signs:**
- `payment_method_details` struct has more than 3-4 typed sub-variants modeled
- `from_map/1` contains a `case payment_method_type do` dispatch with 10+ clauses

**Phase to address:** Mandate & SetupAttempt phase.

---

### Pitfall 10: `ObjectTypes` Registry Not Updated for New Resources — Expand Deserialization Silently Returns Raw Maps

**What goes wrong:**
`LatticeStripe.ObjectTypes` maps Stripe `"object"` type strings to module names
for expand-deserialization (Phase 22). If a new resource module is added but not
registered in `@object_map`, then:

1. Any field on an existing resource that expands to the new type returns a raw
   `map()` instead of a typed struct — silently wrong, no crash
2. `Invoice.from_map/1` will not recognize `"quote"` as an expandable type when
   an Invoice has a `quote` field that was expanded
3. The expand deserialization guide becomes incorrect for new resources

The current `@object_map` does not include `"file"`, `"file_link"`,
`"credit_note"`, `"mandate"`, `"setup_attempt"`, or `"quote"`.

**Why it happens:**
`ObjectTypes` is a compile-time module attribute. There is no enforcement
mechanism — the fallback silently returns the raw map, which does not crash but
produces wrong types. It's easy to miss the registry step when adding a module.

**How to avoid:**
Each new resource phase must include an explicit checklist item: "Add
`"<object_type>" => Module` to `ObjectTypes.@object_map`." This applies to
all six new resources: `"file"`, `"file_link"`, `"credit_note"`, `"mandate"`,
`"setup_attempt"`, `"quote"`.

Verification: in at least one integration test per resource, retrieve the object
with `expand:` targeting the new resource type and assert `is_struct(result.field)`.

**Warning signs:**
- `expand: ["invoice.quote"]` returns a raw map instead of `%Quote{}`
- No entry for the new resource in `@object_map` after the phase ships

**Phase to address:** Every new resource phase. Final audit in DX polish phase.

---

### Pitfall 11: Quote Has Two Distinct Line Item Endpoints — Implementing Only One Causes Incorrect Totals

**What goes wrong:**
The Quote API has two line item list endpoints with different semantics:
- `GET /v1/quotes/:id/line_items` — the full set of billable items
- `GET /v1/quotes/:id/computed_upfront_line_items` — upfront-only totals (one-time
  charges that are not recurring)

Implementing only `list_line_items/3` is correct but incomplete for users building
proposal UIs or syncing quote totals. Missing the second endpoint means upfront
charges (e.g., setup fees on a subscription quote) are invisible in the SDK.

**Why it happens:**
The Stripe API reference lists both endpoints on the same page without clearly
distinguishing their semantics. An implementer reads the first, ships it, and
the second is discovered only when a user reports missing charges.

**How to avoid:**
Ship both endpoints with distinct names: `list_line_items/3` and
`list_computed_upfront_line_items/3`. Add a `@moduledoc` section explaining the
distinction between recurring and upfront line items. Both return paginated
`List` responses and should use `Resource.unwrap_list`.

**Warning signs:**
- Quote module has only one line item function
- Integration test only exercises one endpoint

**Phase to address:** Quote phase.

---

### Pitfall 12: Quote `accept/3` Populates `invoice`/`subscription` as Expandable — Must Use `is_map` Guard

**What goes wrong:**
When a quote is accepted, Stripe optionally sets `invoice`, `subscription`, or
`subscription_schedule` on the returned Quote object. By default these fields are
string IDs. With `expand: ["invoice"]` they are full objects. If `Quote.from_map/1`
does not apply the same `is_map(val)` expand guard that `Invoice.from_map/1` uses
for its `charge` and `customer` fields, one of these two modes will produce
silently wrong data:
- Without guard: a string ID gets passed to `ObjectTypes.maybe_deserialize`,
  which is already guarded — but the logic is inconsistent with the rest of
  the codebase and fragile to future changes
- With naive struct wrapping: calling `Invoice.from_map(val)` on a string ID
  crashes

**Why it happens:**
The expand-guard pattern is established (Phase 22) but must be consciously applied
to every new resource. It is easy to forget on the three new expandable fields
unique to Quote.

**How to avoid:**
Apply the same guard used throughout existing `from_map/1` implementations:
```elixir
invoice:
  (if is_map(known["invoice"]),
    do: ObjectTypes.maybe_deserialize(known["invoice"]),
    else: known["invoice"]),
```
This pattern must be applied to `invoice`, `subscription`, and
`subscription_schedule` on `Quote`. The same applies to `Invoice.from_map/1`
for its `quote` field (the back-reference to a Quote object).

**Warning signs:**
- `Quote.from_map/1` calls `ObjectTypes.maybe_deserialize` without an `is_map`
  guard on the expandable fields
- No unit test covering the non-expanded (string ID) case for these fields

**Phase to address:** Quote phase.

---

### Pitfall 13: Test Fixture Under-Coverage — `extra` Field Left Non-Empty

**What goes wrong:**
Fixture helpers in `test/support/fixtures/` mirror Stripe response shapes and are
used in unit tests for `from_map/1`. If the fixture only includes the fields
needed for the current test (minimal fixture anti-pattern), `from_map/1` may have
incomplete `@known_fields`. Stripe fields in a full API response that are not in
`@known_fields` silently fall into the `extra` map, where they are invisible to
users unless they know to look.

A fixture that drives a passing `from_map/1` unit test but produces
`%CreditNote{..., extra: %{"effective_at" => ...}}` is hiding a modeling gap.

**Why it happens:**
Fixtures are written to make a specific test pass, not to model the full API
response. The minimal approach ships fast but leaves `@known_fields` incomplete
relative to what Stripe actually returns.

**How to avoid:**
For each new resource, include all top-level fields from the Stripe API reference
in the initial fixture — not just the fields needed for the first test. Then add
an assertion in at least one unit test:

```elixir
result = fixture |> ResourceModule.from_map()
assert result.extra == %{}
```

This assertion fails if any fixture field is not in `@known_fields`, surfacing
modeling gaps immediately during development rather than in production.

**Warning signs:**
- Fixture has fewer than 10 fields for a resource documented with 30+ in the
  Stripe API reference
- No unit test asserts `result.extra == %{}`
- `extra` field is non-empty in integration test responses

**Phase to address:** Each new resource phase.

---

### Pitfall 14: DX Guides Duplicate Existing `webhooks.md` Content — Creates Drift Between Two Sources

**What goes wrong:**
A new "Phoenix Webhook Recipe" guide that re-explains `Plug.Parsers` raw body
configuration creates a second source of truth for the same content. When Phoenix
changes raw body caching behavior (it has, between major versions), only one of
the two documents gets updated. Users following the stale guide get broken
webhook verification.

Similarly, duplicate Finch supervision tree setup instructions across the
getting-started guide and new recipe guides will drift.

**Why it happens:**
Recipe guides are written by copying complete working examples. The author
includes every prerequisite step for completeness, not realizing the prerequisite
is already documented and maintained elsewhere.

**How to avoid:**
The Phoenix Webhook Recipe must cross-link to the existing `webhooks.md` guide
for `Plug.Parsers` configuration rather than reproducing it. The recipe covers
only the Phoenix-specific routing and handler pattern — the "what to do with the
verified event." Add a `# Last verified against LatticeStripe vX.X, Phoenix 1.7+`
note to each new guide at the top. Avoid Ecto schema examples in SDK guides —
data persistence belongs in Accrue or user applications.

**Warning signs:**
- New guide contains a `Plug.Parsers` configuration block identical to `webhooks.md`
- New guide references `Phoenix.Endpoint` options without a "tested with Phoenix
  1.7+" qualifier
- Guide includes `Ecto.Schema` struct definitions

**Phase to address:** DX polish phase.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Buffer entire file in memory for multipart upload | No streaming API needed; simpler transport layer | OOM risk for files approaching 4.5 MB ceiling under concurrent load | Acceptable for v1.3 — document the 4.5 MB cap; defer streaming to v1.4 |
| Plain map for `Mandate.payment_method_details` | Avoids 15+ struct variants | Users cannot pattern-match on payment method type safely | Acceptable for v1.3 with a `TODO v1.4` comment |
| Omit `submit: false` enforcement in Dispute update | Simpler function signature | Users accidentally lock disputes on first evidence submission | Never — always omit submit from defaults; require explicit opt-in |
| Reuse standard JSON pipeline for Quote PDF | Zero new code | `Jason.DecodeError` crash at runtime | Never — PDF path requires raw binary bypass |
| Implement only one Quote line item endpoint | Faster to ship | Missing upfront charge totals; users report incorrect amounts | Never — both endpoints serve different semantics |
| Skip `ObjectTypes` registry for new resources | One less file to update | Expand deserialization silently returns raw maps forever | Never — always register new resources |
| Minimal fixtures (only fields needed for current test) | Fast test authoring | Modeling gaps stay invisible; `extra` silently fills with missed fields | Never for public-facing resource modules |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Stripe Files API | POST to `api.stripe.com/v1/files` | POST to `files.stripe.com/v1/files` |
| Stripe Files API | Set `Content-Type: multipart/form-data` without boundary | Set `Content-Type: multipart/form-data; boundary=<generated_value>` |
| Stripe Files API | Pass URL-encoded form body (`FormEncoder`) | Build raw multipart body with part delimiters |
| Quote PDF | Decode PDF response with `Jason.decode!` | Use `raw: true` transport path; return `{:ok, binary()}` |
| Quote accept | Assume `invoice` field is always a string ID | Apply `is_map/1` guard before calling `ObjectTypes.maybe_deserialize` |
| Dispute evidence | Call update twice with partial maps | Retrieve current evidence first; merge locally; submit full map once |
| Dispute evidence | Include `submit: true` by default | Omit `submit`; require explicit opt-in |
| CreditNote | Create against a draft invoice | Call `Invoice.finalize/3` first; credit notes require finalized invoices |
| CreditNote void | Void on a paid invoice | Void is only valid on credit notes attached to `open` invoices |
| Mandate / SetupAttempt | Call `create/3` or `update/3` | These resources are read-only; expose only `retrieve` (and `list` for SetupAttempt) |
| stripe-mock | Assume file upload endpoint exists at default base URL | Verify stripe-mock routes `/v1/files`; if not, use Mox for multipart unit tests |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Buffering the full file binary for multipart upload | High process heap per concurrent upload | Document the 4.5 MB ceiling; defer streaming to v1.4 | ~50 concurrent max-size dispute evidence uploads |
| Fetching Quote line items without checking `has_more` | Silent truncation at 10 items | Use `stream!/2` or check `has_more` on list result | Quotes with >10 line items |
| Dispute evidence char count not validated client-side | Stripe 400 after evidence is fully assembled | Optional pre-submission char count check against 150,000 limit | When multiple long text evidence fields are combined |
| Large `Mandate.payment_method_details` dispatch in `from_map/1` | CPU spike on high-volume retrieve | Store as plain map for v1.3; no dispatch overhead | Not a v1.3 concern; becomes relevant only if typed variants are added |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Logging file binary body in transport telemetry | PII exposure — identity documents, signed contracts, dispute evidence images | Ensure telemetry spans omit `body` for `files.stripe.com` requests; follow existing PII-safe Inspect pattern for `BankAccount`/`Card` |
| Caching uploaded file binaries beyond the request | Sensitive document bytes in process memory longer than needed | Return only the File ID after upload; do not retain the binary |
| Not checking `dispute.is_charge_refundable` before refund attempt | API call wasted on a non-refundable dispute; user confusion | Expose `is_charge_refundable` as a typed boolean field on the `Dispute` struct; document the pre-refund check in guides |

---

## "Looks Done But Isn't" Checklist

- [ ] **File.create/3:** URL is `files.stripe.com/v1/files`, not `api.stripe.com/v1/files` — verify the URL literal in the function body
- [ ] **File.create/3:** Multipart `Content-Type` header includes `; boundary=<value>` — verify with a unit test that checks the header sent to the transport
- [ ] **File.create/3:** Does not call `FormEncoder.encode/1` — file uploads use a raw multipart body
- [ ] **Quote.pdf/3:** Return type is `{:ok, binary()} | {:error, Error.t()}` — not `{:ok, Quote.t()}`
- [ ] **Quote.pdf/3:** `@doc` notes that `draft` and `canceled` quotes have no PDF (Stripe 404)
- [ ] **Quote:** Both `list_line_items/3` AND `list_computed_upfront_line_items/3` exist
- [ ] **Quote.from_map/1:** `invoice`, `subscription`, `subscription_schedule` fields use `is_map/1` expand guard
- [ ] **Dispute.update_evidence/3:** `submit` is absent from default params (not `submit: true`)
- [ ] **Dispute.update_evidence/3:** `@doc` warns that evidence submission is a full replace, not an incremental merge
- [ ] **CreditNote:** Integration tests call `Invoice.finalize/3` before `CreditNote.create/3`
- [ ] **CreditNote.from_map/1:** Line items decoded via `CreditNote.LineItem.from_map/1`, not left as plain maps
- [ ] **Mandate:** Only `retrieve/3` is defined — no `create`, `update`, `delete`
- [ ] **SetupAttempt:** Only `retrieve/3` and `list/3` are defined — no `create`, `update`, `delete`
- [ ] **Mandate / SetupAttempt:** `payment_method_details` stored as a plain map; `TODO v1.4` comment present
- [ ] **ObjectTypes:** `"file"`, `"file_link"`, `"credit_note"`, `"mandate"`, `"setup_attempt"`, `"quote"` all registered in `@object_map`
- [ ] **All new resources:** At least one unit test asserts `result.extra == %{}` against the full-field fixture
- [ ] **DX guides:** New Phoenix recipe cross-links to existing `webhooks.md`; no duplicate `Plug.Parsers` block; "Last verified" header present

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Wrong base URL for file uploads | LOW | Fix URL literal in `File.create/3`; bump patch version; no struct changes needed |
| Missing multipart boundary | LOW | Fix header construction; no struct or API changes needed |
| Quote PDF crashes with `Jason.DecodeError` | LOW | Add `raw: true` path to `Client`; change `Quote.pdf/3` return type; bump minor (return type change) |
| Dispute evidence lost between updates | MEDIUM | Document replace semantics clearly in CHANGELOG; no breaking API change; add guide migration note |
| `ObjectTypes` missing a new resource | LOW | Add one line to `@object_map`; recompile; no breaking change |
| CreditNote tests fail due to draft invoice | LOW | Update integration tests to finalize invoice; no API change |
| Guide duplicates webhook setup content | MEDIUM | Refactor guide to use cross-links; update "Last verified" header; verify against current Phoenix |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| File uploads wrong base URL | File & FileLink phase | Unit test asserts URL contains `files.stripe.com` |
| Multipart missing boundary | File & FileLink phase | Mox unit test: assert `content-type` header includes `boundary=` |
| File using `FormEncoder` | File & FileLink phase | Code review: `FormEncoder` not imported in `File` module |
| Quote PDF binary handling | Quote phase | Unit test: `Quote.pdf/3` returns `{:ok, <<_::binary>>}` |
| Quote dual line item endpoints | Quote phase | Integration tests cover both `list_line_items` and `list_computed_upfront_line_items` |
| Quote expand guard for invoice/subscription | Quote phase | Unit test: non-expanded quote has string IDs; expanded quote has typed structs |
| Dispute evidence full-replace semantics | Dispute phase | Integration test: two sequential updates; assert first field retained in second call (by retrieving first) |
| Dispute `submit` default | Dispute phase | Unit test: request params omit `submit` when not passed by caller |
| CreditNote invoice state precondition | CreditNote phase | Integration test: finalize before credit note creation |
| CreditNote line item types | CreditNote phase | Unit tests cover both `invoice_line_item` and `custom_line_item` variants |
| Mandate read-only | Mandate & SetupAttempt phase | No `create`/`update`/`delete` functions in module (verified via `module_info(:exports)`) |
| SetupAttempt read-only | Mandate & SetupAttempt phase | Same as Mandate |
| Mandate `payment_method_details` over-modeling | Mandate & SetupAttempt phase | `payment_method_details` stored as map; `extra == %{}` assertion passes with full fixture |
| `ObjectTypes` registry gaps | Each resource phase + DX polish | `expand:` integration test returns typed struct, not raw map |
| Fixture under-coverage | Each resource phase | `assert result.extra == %{}` in unit test passes with full-field fixture |
| DX guide duplication / staleness | DX polish phase | No `Plug.Parsers` block duplicated from `webhooks.md`; "Last verified" comment present in each new guide |

---

## Sources

- [Stripe File Upload — `files.stripe.com` distinct base URL and multipart requirement](https://docs.stripe.com/file-upload) — HIGH confidence (official docs, 2026)
- [Stripe Files API — purpose enum, multipart/form-data, MIME type requirement](https://docs.stripe.com/api/files/create) — HIGH confidence
- [Elixir Forum — Finch "no multipart boundary param in Content-Type"](https://elixirforum.com/t/how-to-make-a-multipart-http-request-using-finch/36217) — MEDIUM confidence (forum post, corroborated by Stripe docs and RFC 2388)
- [Stripe Quote overview — state machine, accept semantics, upfront vs recurring line items](https://docs.stripe.com/quotes/overview) — HIGH confidence
- [Stripe Quote PDF endpoint](https://docs.stripe.com/api/quotes/pdf) — HIGH confidence (endpoint confirmed; binary return inferred from `application/pdf` MIME type per Stripe standard)
- [Stripe Disputes API — status values, evidence fields, `evidence_details.due_by`, 4.5 MB / 150k char limits](https://docs.stripe.com/api/disputes/object) — HIGH confidence
- [Stripe Disputes — responding with evidence, `submit` behavior](https://docs.stripe.com/disputes/api) — HIGH confidence
- [Stripe CreditNote — line item types `invoice_line_item` vs `custom_line_item`](https://docs.stripe.com/api/credit_notes/line_item) — HIGH confidence
- [Stripe CreditNote — void semantics, open-invoice constraint](https://docs.stripe.com/billing/invoices/credit-notes) — HIGH confidence
- [Stripe Mandate object — status values (active/pending/inactive), 15+ payment_method_details variants](https://docs.stripe.com/api/mandates/object) — HIGH confidence
- [Stripe SetupAttempt object — immutable snapshot fields, read-only constraints](https://docs.stripe.com/api/setup_attempts/object) — HIGH confidence
- LatticeStripe codebase — `ObjectTypes`, `FormEncoder`, `Resource`, `Transport.Finch`, `Invoice.from_map/1` expand guard patterns, fixture structure — HIGH confidence (direct source analysis)

---
*Pitfalls research for: LatticeStripe v1.3 — new resource families (Dispute, CreditNote, Mandate, SetupAttempt, File/FileLink, Quote) + DX polish*
*Researched: 2026-04-16*
