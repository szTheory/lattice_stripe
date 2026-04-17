# Architecture Research

**Domain:** Elixir Stripe SDK — v1.3 new resource families + DX polish
**Researched:** 2026-04-16
**Confidence:** HIGH (all findings based on direct codebase inspection + official Stripe API docs)

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Resource Layer (PUBLIC)                           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐     │
│  │ Dispute  │ │CreditNote│ │ Mandate  │ │  File/   │ │  Quote   │     │
│  │          │ │          │ │ +Setup   │ │ FileLink │ │          │     │
│  │          │ │          │ │ Attempt  │ │          │ │          │     │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘     │
├───────┴─────────────┴───────────┴─────────────┴────────────┴───────────┤
│                     Request / Resource Helpers (INTERNAL)                │
│  ┌──────────────────┐  ┌────────────────────┐  ┌─────────────────────┐  │
│  │ %Request{} struct│  │ Resource.unwrap_*  │  │ ObjectTypes registry│  │
│  │ FormEncoder      │  │ bang helpers       │  │ maybe_deserialize   │  │
│  └──────────────────┘  └────────────────────┘  └─────────────────────┘  │
├─────────────────────────────────────────────────────────────────────────┤
│                        Client Layer (PUBLIC)                             │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Client.request/2 — retries, idempotency, telemetry, JSON decode │   │
│  │  Client.upload/3  — multipart POST to files.stripe.com (NEW)     │   │
│  │  Client.download/3 — binary GET, skip JSON decode (NEW)          │   │
│  └──────────────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────────┤
│                        Transport Layer (BEHAVIOUR)                       │
│  ┌──────────────────────────┐  ┌──────────────────────────────────────┐  │
│  │ Transport.Finch (default)│  │ Transport (Mox mock in tests)        │  │
│  └──────────────────────────┘  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Integration Points for New Resource Families

### 1. File Upload — Multipart is a Transport-Level Concern

**What changes:** The existing `Client.request/2` path always calls `FormEncoder.encode(params)` and sets `content-type: application/x-www-form-urlencoded`. File uploads require:
- A different base URL: `https://files.stripe.com` (not `https://api.stripe.com`)
- `content-type: multipart/form-data` with boundary
- Binary file payload mixed with text params

**Recommended approach:** Add a dedicated `Client.upload/3` function (new public function) that bypasses `build_url_and_body/4` and `build_headers/5` and instead constructs a multipart body directly. This keeps the existing `request/2` path entirely untouched and avoids contaminating `FormEncoder` with multipart logic.

Alternatively, add a `multipart: true` flag to `Request` opts that triggers a different branch in `Client.request/2`. The dedicated function approach is cleaner — it avoids a new conditional inside the already-complex `Client.request/2`.

**Implementation sketch:**

```elixir
# In Client:
@spec upload(t(), String.t(), binary(), keyword()) :: {:ok, Response.t()} | {:error, Error.t()}
def upload(%__MODULE__{} = client, purpose, file_binary, opts \\ []) do
  # Build multipart body manually — no new hex dep needed (~20 lines raw)
  # POST to https://files.stripe.com/v1/files
  # Response IS JSON — decode normally
  # Returns {:ok, %Response{data: decoded_file_map}} on success
end
```

**No changes needed** to `Transport.request/1` — the transport contract already accepts arbitrary `body` binary and `headers` list. The multipart body is just a specially-formatted binary.

**Finch multipart:** Finch accepts any binary as body. The multipart boundary and `content-type` header construction can be done with a small helper in `File` or a new `LatticeStripe.Multipart` internal module. No new hex dependency needed — raw string construction is approximately 20 lines.

**Confidence:** HIGH. Verified from Stripe docs: `POST https://files.stripe.com/v1/files`, `multipart/form-data`, `purpose` + `file` fields.

---

### 2. Quote PDF — Binary Response Handling

**What changes:** `GET https://files.stripe.com/v1/quotes/:id/pdf` returns `application/pdf` binary, not JSON. The existing `Client.request/2` path calls `json_codec.decode(body)` on every response and branches on success/failure. A PDF body will always fail JSON decoding and currently lands in `build_non_json_error/4`.

**Recommended approach:** Add a `Client.download/3` function that skips JSON decoding and returns `{:ok, binary()}` when the response is 2xx. This mirrors the `upload/3` addition above — both are escape hatches from the standard JSON pipeline.

The `Quote.pdf/3` function would call this binary path and return `{:ok, binary()}` directly (not a `%Quote{}` struct).

```elixir
# In Quote:
@spec pdf(Client.t(), String.t(), keyword()) :: {:ok, binary()} | {:error, Error.t()}
def pdf(%Client{} = client, quote_id, opts \\ []) do
  # Uses Client.download/3
  # Returns {:ok, pdf_binary}
end
```

**No changes needed** to `Transport`, `FormEncoder`, or `ObjectTypes`.

**Confidence:** HIGH. Verified from Stripe docs: `GET https://files.stripe.com/v1/quotes/:id/pdf`, returns `application/pdf`.

---

### 3. Nested Struct Patterns for New Resources

All new resources fit cleanly into the established `from_map/1` + `@known_fields` + `extra` pattern. Below is resource-by-resource analysis:

**Dispute** — Needs two nested struct modules:
- `LatticeStripe.Dispute.Evidence` — approximately 25 fields including file ID references (`customer_communication`, `shipping_documentation`, `uncategorized_file`, etc.). File fields are strings (IDs) or maps when expanded.
- `LatticeStripe.Dispute.EvidenceDetails` — 4 fields: `due_by`, `has_evidence`, `past_due`, `submission_count`. Simple, no sub-nesting.
- `payment_method_details` — leave as raw map (highly polymorphic, same treatment as SetupIntent/PaymentIntent).
- `balance_transactions` — list of maps; leave as `[map()]` initially (BalanceTransaction objects available if needed via expand).
- `Dispute.from_map/1` calls `Evidence.from_map/1` and `EvidenceDetails.from_map/1`.

**CreditNote** — Needs one nested struct:
- `LatticeStripe.CreditNote.LineItem` — mirrors `Invoice.LineItem` pattern; registered in `ObjectTypes`.
- Other nested fields (`discount_amounts`, `total_taxes`, `shipping_cost`, `pretax_credit_amounts`) are list-of-maps; leave as `[map()]` — no typed sub-structs needed for v1.3.

**Mandate** — Needs nested struct:
- `LatticeStripe.Mandate.CustomerAcceptance` — 3 fields (`accepted_at`, `type`, nested `online`/`offline` maps).
- `payment_method_details` — highly polymorphic (15+ payment method types). Leave as raw map, document `from_map` behavior. Do NOT create typed sub-structs per payment method — same scope decision made for PaymentIntent/SetupIntent.

**SetupAttempt** — Needs:
- `payment_method_details` — same polymorphic treatment as above; leave as map.
- `setup_error` — simple `SetupAttempt.SetupError` sub-struct with `code`, `message`, `type` fields. Cleaner than reusing `LatticeStripe.Error` since that is domain-specific to SDK errors.

**File** — Simple flat struct:
- Fields: `id`, `created`, `expires_at`, `filename`, `links`, `purpose`, `size`, `title`, `type`, `url`, `livemode`.
- `links` is a Stripe embedded list object — decode as `[map()]` (FileLink IDs/objects).
- No sub-structs needed.

**FileLink** — Flat struct:
- Fields: `id`, `created`, `expired`, `expires_at`, `file`, `livemode`, `metadata`, `url`.
- `file` is expandable (string ID or `%LatticeStripe.File{}` when expanded) — use `ObjectTypes.maybe_deserialize/1` in `from_map/1`.

**Quote** — Needs several nested structs:
- `LatticeStripe.Quote.Computed` — `upfront` and `recurring` sub-maps; model as a simple struct with map fields.
- `LatticeStripe.Quote.TotalDetails` — discount/tax breakdown.
- `LatticeStripe.Quote.StatusTransitions` — mirrors `Invoice.StatusTransitions`.
- `LatticeStripe.Quote.SubscriptionData` — flat map, leave as map initially.
- `line_items` — Stripe returns a list object; decode as `[map()]` (Quote line items differ from Invoice line items; not worth a separate struct in v1.3).

**Pattern precedent for nested sub-structs** (from codebase):
- `Payout.TraceId.cast/1` — used for optional nested objects that do not have their own `object` type key.
- `Invoice.AutomaticTax.from_map/1` — used for nested objects inside from_map.
- `ObjectTypes.maybe_deserialize/1` — used for expandable references that could be string IDs or full objects.

New resources follow the same hierarchy: struct module lives under `lib/lattice_stripe/<resource>/` directory, e.g., `lib/lattice_stripe/dispute/evidence.ex`.

---

### 4. ObjectTypes Registry — New Entries Required

The `ObjectTypes` module maps Stripe `"object"` strings to modules for expand deserialization. The following new entries are needed:

| Stripe `object` string | Module | Notes |
|------------------------|--------|-------|
| `"dispute"` | `LatticeStripe.Dispute` | Top-level resource |
| `"credit_note"` | `LatticeStripe.CreditNote` | Top-level resource |
| `"credit_note_line_item"` | `LatticeStripe.CreditNote.LineItem` | Embedded in CreditNote `lines` |
| `"mandate"` | `LatticeStripe.Mandate` | Retrieve-only |
| `"setup_attempt"` | `LatticeStripe.SetupAttempt` | List-filterable |
| `"file"` | `LatticeStripe.File` | Upload/download resource |
| `"file_link"` | `LatticeStripe.FileLink` | CRUDL |
| `"quote"` | `LatticeStripe.Quote` | Full lifecycle resource |

**Note on module naming conflict:** `LatticeStripe.File` shadows Elixir's stdlib `File` module when `alias LatticeStripe.File` is used without an `as:` clause. In `ObjectTypes`, the string key `"file"` -> `LatticeStripe.File` is unambiguous (fully qualified). In any module that aliases `LatticeStripe.File`, use `as: StripeFile` — or avoid the alias and use the full name. Document this in the module's `@moduledoc`.

---

### 5. Test Fixture Builders — Module Hierarchy

**Existing pattern:** `LatticeStripe.Test.Fixtures.<Resource>` modules live in `test/support/fixtures/`. Each exposes a `<resource>_json/1` function that returns a plain map with override support.

**For new resources, place fixtures at:**

```
test/support/fixtures/
├── dispute.ex               # LatticeStripe.Test.Fixtures.Dispute
├── credit_note.ex           # LatticeStripe.Test.Fixtures.CreditNote
├── mandate.ex               # LatticeStripe.Test.Fixtures.Mandate
├── setup_attempt.ex         # LatticeStripe.Test.Fixtures.SetupAttempt
├── file.ex                  # LatticeStripe.Test.Fixtures.File
├── file_link.ex             # LatticeStripe.Test.Fixtures.FileLink
└── quote.ex                 # LatticeStripe.Test.Fixtures.Quote
```

**DX polish fixture builders:** The v1.3 milestone includes "test fixture builders" as a DX feature for downstream users. This is distinct from internal test fixtures. The existing `LatticeStripe.Testing` module (in `lib/`, ships with the package) already exposes `generate_webhook_event/3` and `generate_webhook_payload/3`. New fixture builder helpers for v1.3 should live there as well.

Suggested additions to `LatticeStripe.Testing` for downstream use:

```elixir
# Typed struct constructors for downstream test suites
LatticeStripe.Testing.build_dispute/1        # returns %Dispute{} with sensible defaults
LatticeStripe.Testing.build_credit_note/1    # returns %CreditNote{}
LatticeStripe.Testing.build_file/1           # returns %LatticeStripe.File{}
# etc. for each new resource
```

These call the internal `Test.Fixtures.*` builders and then `from_map/1` on the result, giving downstream users typed structs without requiring them to know the raw JSON shape.

---

### 6. Suggested Build Order

Resource dependencies determine ordering. File must exist before Dispute (Dispute evidence fields reference file IDs/objects; File registration in ObjectTypes enables expand deserialization for evidence file fields).

**Recommended phase sequence:**

1. **File + FileLink** — No dependencies on other new resources. Required by Dispute evidence (file upload for dispute evidence documents). Introduces `Client.upload/3` (multipart) and `Client.download/3` (binary) — both needed by Quote as well. Build these first so all later phases can use them.

2. **Dispute** — Depends on File being in ObjectTypes (evidence document expand deserialization). Medium complexity: two nested structs (`Evidence`, `EvidenceDetails`), explicit `submit_evidence/4` verb. Does NOT depend on CreditNote/Mandate/Quote.

3. **Mandate + SetupAttempt** — No inter-dependencies. Mandate is retrieve-only (trivial), SetupAttempt is list-only. Can be built in a single phase. Both are thin resources with no new infrastructure needs.

4. **CreditNote** — Depends on Invoice (must understand Invoice structure; CreditNote `invoice` field references an Invoice). Invoice already exists. One nested struct (`CreditNote.LineItem`). Explicit verbs: `void/3`.

5. **Quote** — Most complex: full lifecycle with `draft -> open -> accepted/canceled` transitions, PDF download (needs `Client.download/3` from step 1), and several nested structs. Build last among resources.

6. **DX polish** — Phoenix webhook recipe, `LatticeStripe.Testing` fixture builders, recipes guide. Purely additive; can run in parallel with or after any resource phase.

**Dependency graph:**

```
File + FileLink  ──►  Dispute
                          │
                          ▼
                      ObjectTypes registry updates
                          ▲
Mandate + SetupAttempt ───┤
                          │
CreditNote (Invoice exists) ─►

Quote  (uses Client.download/3 from File phase)
```

---

## Component Responsibilities

| Component | Responsibility | New in v1.3? |
|-----------|---------------|--------------|
| `LatticeStripe.File` | Upload/retrieve/list files | NEW |
| `LatticeStripe.FileLink` | CRUDL for shareable file URLs | NEW |
| `LatticeStripe.Dispute` | Retrieve/list/update disputes, submit evidence | NEW |
| `LatticeStripe.Dispute.Evidence` | Typed sub-struct for evidence fields | NEW |
| `LatticeStripe.Dispute.EvidenceDetails` | Typed sub-struct for evidence deadline/status | NEW |
| `LatticeStripe.CreditNote` | Create/retrieve/list/void credit notes | NEW |
| `LatticeStripe.CreditNote.LineItem` | Typed sub-struct, registered in ObjectTypes | NEW |
| `LatticeStripe.Mandate` | Retrieve-only mandate access | NEW |
| `LatticeStripe.SetupAttempt` | List-only setup attempt access | NEW |
| `LatticeStripe.Quote` | Full quote lifecycle + PDF download | NEW |
| `LatticeStripe.Quote.Computed` | Sub-struct: upfront/recurring totals | NEW |
| `LatticeStripe.Quote.TotalDetails` | Sub-struct: tax/discount totals | NEW |
| `LatticeStripe.Quote.StatusTransitions` | Sub-struct: status change timestamps | NEW |
| `Client.upload/3` | Multipart POST to files.stripe.com | MODIFIED — new function |
| `Client.download/3` | Binary GET, skip JSON decode | MODIFIED — new function |
| `ObjectTypes` | Registry: 8 new object type entries | MODIFIED |
| `LatticeStripe.Testing` | Public fixture builders for downstream users | MODIFIED |

---

## Recommended Project Structure (New Files Only)

```
lib/lattice_stripe/
├── file.ex                        # LatticeStripe.File
├── file_link.ex                   # LatticeStripe.FileLink
├── dispute.ex                     # LatticeStripe.Dispute
├── dispute/
│   ├── evidence.ex                # LatticeStripe.Dispute.Evidence
│   └── evidence_details.ex        # LatticeStripe.Dispute.EvidenceDetails
├── credit_note.ex                 # LatticeStripe.CreditNote
├── credit_note/
│   └── line_item.ex               # LatticeStripe.CreditNote.LineItem
├── mandate.ex                     # LatticeStripe.Mandate
├── setup_attempt.ex               # LatticeStripe.SetupAttempt
├── quote.ex                       # LatticeStripe.Quote
└── quote/
    ├── computed.ex                # LatticeStripe.Quote.Computed
    ├── total_details.ex           # LatticeStripe.Quote.TotalDetails
    └── status_transitions.ex      # LatticeStripe.Quote.StatusTransitions

test/support/fixtures/
├── dispute.ex
├── credit_note.ex
├── mandate.ex
├── setup_attempt.ex
├── file.ex
├── file_link.ex
└── quote.ex
```

---

## Architectural Patterns

### Pattern 1: from_map/1 + @known_fields + extra

**What:** Every Stripe resource struct defines `@known_fields` as a list of string keys present in the Stripe JSON response. `from_map/1` calls `Map.split(map, @known_fields)` then builds the struct, putting unrecognized fields into `extra: %{}`.

**When to use:** ALL new resource structs must follow this pattern. No exceptions.

**Example:**

```elixir
@known_fields ~w[id object created purpose size filename url livemode expires_at title type]

defstruct Enum.map(@known_fields, &String.to_atom/1) ++ [extra: %{}]

def from_map(nil), do: nil
def from_map(map) when is_map(map) do
  {known, extra} = Map.split(map, @known_fields)
  %__MODULE__{
    id: known["id"],
    object: known["object"] || "file",
    # ... all known fields
    extra: extra
  }
end
```

### Pattern 2: ObjectTypes.maybe_deserialize/1 for expandable references

**What:** When a field can be either a string ID or an expanded full object map (Stripe's `expand:` feature), call `ObjectTypes.maybe_deserialize/1` in `from_map/1`.

**When to use:** Any field that Stripe marks as expandable. In new resources:
- `Dispute.charge` (-> Charge)
- `Dispute.payment_intent` (-> PaymentIntent)
- `FileLink.file` (-> LatticeStripe.File)
- `Quote.customer` (-> Customer)
- `Quote.invoice` (-> Invoice, when accepted)
- `CreditNote.invoice` (-> Invoice)
- `CreditNote.customer` (-> Customer)

```elixir
charge: if is_map(known["charge"]),
  do: ObjectTypes.maybe_deserialize(known["charge"]),
  else: known["charge"]
```

### Pattern 3: Explicit verb functions for state transitions

**What:** Stripe state machine transitions get their own named functions rather than hiding behind `update/3` with magic params. Established verbs: `finalize`, `pay`, `void`, `cancel`, `submit`, `reject`, `deactivate`.

**When to use:** For new resources:
- `Dispute.submit_evidence/4` — not `Dispute.update(client, id, %{"evidence" => ...})`
- `CreditNote.void/3` — not `CreditNote.update(client, id, %{"status" => "void"})`
- `Quote.finalize/3`, `Quote.accept/3`, `Quote.cancel/3` — all distinct verbs

### Pattern 4: Separate Client functions for non-standard request shapes

**What:** When a request requires a different body encoding (multipart) or response handling (binary), add a dedicated `Client` function rather than adding conditionals to `Client.request/2`.

**When to use:**
- File upload -> `Client.upload/3` (multipart body, `files.stripe.com` base URL)
- Quote PDF / File download -> `Client.download/3` (skip JSON decode, return raw binary)

**Trade-off:** Slightly larger public API surface on Client, but keeps `request/2` simple and avoids special-case branching in the hot path.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: GenServer for File Upload State

**What people do:** Wrap multipart upload in a GenServer or use a stream/chunked upload abstraction.

**Why it's wrong:** LatticeStripe's philosophy is "processes only when truly needed." Stripe file uploads are bounded in size (max 8 MB for most purposes), complete in a single HTTP request, and do not benefit from streaming at the SDK layer.

**Do this instead:** Single synchronous `Client.upload/3` call. Callers who need async behavior wrap it in `Task.async/1` themselves.

### Anti-Pattern 2: Adding multipart support to FormEncoder

**What people do:** Extend `FormEncoder` with a `:multipart` mode flag.

**Why it's wrong:** FormEncoder's contract is `encode(map) :: binary()` producing URL-encoded form data. Multipart encoding is fundamentally different (boundary markers, binary sections, content-disposition headers). Mixing them breaks single-responsibility and makes both paths harder to test.

**Do this instead:** Separate internal multipart helper or inline the minimal boundary construction in `Client.upload/3` directly.

### Anti-Pattern 3: Typed sub-structs for highly polymorphic payment_method_details

**What people do:** Create `Dispute.PaymentMethodDetails.Card`, `Dispute.PaymentMethodDetails.Paypal`, etc.

**Why it's wrong:** This pattern was deliberately avoided for PaymentIntent and SetupIntent (15+ payment method types each). The maintenance cost is enormous, and users can access raw fields via `dispute.payment_method_details["card"]["brand"]`.

**Do this instead:** Leave `payment_method_details` as a raw `map()`. Document in the `@moduledoc` that it is a passthrough map.

### Anti-Pattern 4: Unqualified alias of LatticeStripe.File

**What people do:** `alias LatticeStripe.File` then call `File.read/1` expecting stdlib.

**Why it's wrong:** `LatticeStripe.File` shadows Elixir's stdlib `File` module when aliased without an `as:` clause.

**Do this instead:** Use `alias LatticeStripe.File, as: StripeFile` wherever both are needed, or use the full qualified name `LatticeStripe.File` and skip the alias entirely.

---

## Data Flow

### Standard Request Flow (all resources except File upload/PDF)

```
Dispute.retrieve(client, "dp_123")
    |
    v
%Request{method: :get, path: "/v1/disputes/dp_123", params: %{}}
    |
    v
Client.request(client, request)
    |  builds headers, encodes params via FormEncoder
    v
Transport.Finch.request(transport_map)
    |
    v
{:ok, %{status: 200, body: "{\"id\":\"dp_123\",\"object\":\"dispute\",...}"}}
    |
    v
Client.decode_response -- json_codec.decode(body)
    |
    v
{:ok, %Response{data: %{"object" => "dispute", ...}}}
    |
    v
Resource.unwrap_singular -- Dispute.from_map(data)
    |  Map.split(@known_fields), nested struct construction
    v
{:ok, %Dispute{id: "dp_123", status: :needs_response, evidence: %Evidence{...}}}
```

### File Upload Flow (new path)

```
LatticeStripe.File.upload(client, "dispute_evidence", binary, opts)
    |
    v
Client.upload(client, upload_params)
    |  builds multipart body with boundary
    |  POST to https://files.stripe.com/v1/files
    |  content-type: multipart/form-data; boundary=...
    v
Transport.Finch.request(transport_map)  -- unchanged transport contract
    |
    v
{:ok, %{status: 200, body: "{\"id\":\"file_...\",\"object\":\"file\",...}"}}
    |
    v
Client (JSON path -- upload response IS JSON, decode normally)
    |
    v
{:ok, %LatticeStripe.File{id: "file_...", purpose: "dispute_evidence"}}
```

### Quote PDF / Binary Download Flow (new path)

```
Quote.pdf(client, "qt_123", opts)
    |
    v
Client.download(client, "/v1/quotes/qt_123/pdf", base_url: "https://files.stripe.com")
    |  GET request, no body
    v
Transport.Finch.request(transport_map)  -- unchanged transport contract
    |
    v
{:ok, %{status: 200, headers: [{"content-type","application/pdf"}], body: <<pdf bytes>>}}
    |
    v
Client.download path: skip json_codec.decode, return body binary directly
    |
    v
{:ok, <<...pdf binary...>>}
```

---

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| `api.stripe.com` | Existing `Client.request/2` | All resources except File upload and Quote PDF |
| `files.stripe.com` | New `Client.upload/3` and `Client.download/3` | File uploads, Quote PDF; different base URL passed per-call |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `LatticeStripe.File` -> `Dispute` | `Dispute.Evidence` has file ID string fields | File must be in ObjectTypes before Dispute so `expand: ["evidence.customer_communication"]` deserializes correctly |
| `LatticeStripe.File` -> `FileLink` | `FileLink.file` is an expandable File reference | ObjectTypes must map `"file"` -> `LatticeStripe.File` before FileLink expand deserialization works |
| `CreditNote` -> `Invoice` | `CreditNote.invoice` field is an expandable Invoice reference | Invoice already exists; just add `"credit_note"` to ObjectTypes |
| `Quote` -> `Client.download/3` | `Quote.pdf/3` uses the new binary path | `Client.download/3` must exist before Quote can be built |
| New resources -> `ObjectTypes` | All new `from_map/1` modules must be registered | Register all 8 new entries in a single ObjectTypes update |
| `LatticeStripe.Testing` -> new structs | Public fixture builders construct typed structs via `from_map/1` | Build after all resource modules exist |

---

## Sources

- Direct codebase inspection: `lib/lattice_stripe/client.ex`, `transport/finch.ex`, `resource.ex`, `form_encoder.ex`, `object_types.ex`, `request.ex`, `invoice.ex`, `payout/trace_id.ex`
- [Stripe File upload](https://docs.stripe.com/api/files/create) — confirmed `files.stripe.com`, `multipart/form-data`
- [Stripe Quote PDF](https://docs.stripe.com/api/quotes/pdf) — confirmed `files.stripe.com`, returns `application/pdf`
- [Stripe Dispute object](https://docs.stripe.com/api/disputes/object) — Evidence and EvidenceDetails nested shapes
- [Stripe CreditNote object](https://docs.stripe.com/api/credit_notes/object) — LineItem nested shape
- [Stripe Mandate object](https://docs.stripe.com/api/mandates/object) — retrieve-only confirmed
- [Stripe SetupAttempt object](https://docs.stripe.com/api/setup_attempts/object) — list-only confirmed
- [Stripe FileLink operations](https://docs.stripe.com/api/file_links) — full CRUDL confirmed
- [Stripe Quote object](https://docs.stripe.com/api/quotes/object) — Computed, TotalDetails, StatusTransitions shapes

---
*Architecture research for: LatticeStripe v1.3 — new resource families integration*
*Researched: 2026-04-16*
