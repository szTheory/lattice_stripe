# Phase 33: Disputes - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Full dispute lifecycle management. Developers can retrieve, list, update metadata, stage evidence safely, irreversibly submit evidence to the bank, and accept/close disputes. Typed deserialization for Dispute, Evidence, EvidenceDetails, and PaymentMethodDetails structs.

Requirements: DISP-01, DISP-02, DISP-03, DISP-04, DISP-05, DISP-06, DISP-07

</domain>

<decisions>
## Implementation Decisions

### Evidence API Split

- **D-01:** `update_evidence/4` accepts a flat map of evidence fields — wraps internally into `%{evidence: evidence_map, submit: false}`. Silently strips any stray `submit` key the user passes. The function's contract is safety: impossible to accidentally submit.
- **D-02:** `update/4` does NOT reject evidence fields — it is the general-purpose method for power users who want raw API access. Accepts anything the Stripe API accepts, including `evidence` + `submit: true` for atomic stage+submit.
- **D-03:** `submit_evidence/3` takes NO evidence param — signature is `submit_evidence(client, id, opts \\ [])`. Forces the two-step stage-then-submit workflow. Sends `%{submit: true}` to the Stripe endpoint.
- **D-04:** All three functions (`update/4`, `update_evidence/4`, `submit_evidence/3`) delegate to a shared `defp do_update/4` that calls `POST /v1/disputes/:id`. Single implementation, three semantic entry points.

### Nested Struct Depth

- **D-05:** `Dispute.PaymentMethodDetails` gets its own struct with `@known_fields ~w[type card klarna paypal amazon_pay]` + `extra`. Developers branch on `type` to route dispute handling — the struct catches typos at compile time and enables pattern matching.
- **D-06:** Card/klarna/paypal/amazon_pay sub-objects inside `PaymentMethodDetails` stay as raw maps. ~4 flat string fields each, no sub-branching needed. Promote to structs later if demand appears.
- **D-07:** `balance_transactions` list deserializes elements using existing `BalanceTransaction.from_map/1` via `Enum.map`. `charge` field uses `ObjectTypes.maybe_deserialize/1` for expand deserialization. Both types already exist — no new structs needed.

### Close Verb Semantics

- **D-08:** Function name is `Dispute.close/3` (and `close!/3`). Matches all official Stripe SDKs and the API endpoint name. Signature: `close(client, id, opts \\ [])` — no params map (Stripe endpoint takes no body parameters).
- **D-09:** `@doc` includes a dedicated `## Irreversibility` section: "Closing is irreversible. The dispute status changes to `lost` and the disputed amount plus fees are permanently deducted. This cannot be undone." Follows `Account.reject/4` precedent.
- **D-10:** No runtime confirmation guards (no `:i_understand` atoms). Not idiomatic Elixir, no official SDK does it, inconsistent with existing `cancel`, `reject`, `deactivate` verbs which all lack ceremony parameters.
- **D-11:** `submit_evidence/3` gets the same `## Irreversibility` doc pattern with milder wording: evidence submission locks the response to the bank but does not concede the dispute.

### Status Atomization

- **D-12:** Private `defp atomize_status/1` with clauses for all 8 known Stripe dispute status values: `needs_response`, `warning_needs_response`, `under_review`, `warning_under_review`, `warning_closed`, `won`, `lost`, `charge_refunded`. String passthrough catch-all for forward compatibility.
- **D-13:** Private `defp atomize_reason/1` for ~14 known values: `fraudulent`, `duplicate`, `not_received`, `subscription_canceled`, `product_unacceptable`, `product_not_received`, `unrecognized`, `credit_not_processed`, `general`, `incorrect_account_details`, `insufficient_funds`, `bank_cannot_process`, `debit_not_authorized`, `customer_initiated`. Same passthrough pattern.
- **D-14:** No public `status_atom/1` or `reason_atom/1` functions — that pattern is deprecated per Phase 22 audit. Atomization happens at parse time in `from_map/1`.
- **D-15:** Unknown values pass through as strings via catch-all `defp atomize_status(other), do: other`. No `{:error, :unknown_status}` — passthrough was chosen over error tuples in Phase 22.

### Claude's Discretion

- Internal `do_update/4` implementation details (header building, URL construction)
- `Dispute.Evidence` and `Dispute.EvidenceDetails` struct field ordering and `from_map/1` implementation
- `PaymentMethodDetails.from_map/1` parsing of polymorphic sub-objects
- Test organization and fixture helper naming within existing test structure
- ExDoc grouping placement for Dispute modules within the nine-group layout
- Custom `Inspect` implementation if any Dispute fields contain sensitive data

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Codebase (patterns to follow)
- `lib/lattice_stripe/client.ex` — `request/2`, retry loop, `do_request/2`. Dispute operations use standard `request/2` (no upload/download needed for core dispute ops).
- `lib/lattice_stripe/resource.ex` — `unwrap_singular/2`, `unwrap_list/2`, `unwrap_bang!/1` helpers.
- `lib/lattice_stripe/refund.ex` — Reference resource module with explicit `cancel` verb. Pattern for `close/3`.
- `lib/lattice_stripe/account.ex` — `reject/4` with `## Irreversibility` doc section. Pattern for `close/3` and `submit_evidence/3` doc warnings.
- `lib/lattice_stripe/customer.ex` — Standard CRUDL pattern: `@known_fields`, `defstruct`, `from_map/1`, `extra: %{}`.
- `lib/lattice_stripe/subscription.ex` — `atomize_status/1` pattern at parse time. Reference for `atomize_status/1` and `atomize_reason/1`.
- `lib/lattice_stripe/invoice.ex` §`parse_lines/1` — Nested list deserialization pattern for `balance_transactions`.
- `lib/lattice_stripe/object_types.ex` — Object type registry. Must add `"dispute"` entry.
- `lib/lattice_stripe/balance_transaction.ex` — Existing type reused for `dispute.balance_transactions` list.
- `lib/lattice_stripe/charge.ex` — Existing type reused for `dispute.charge` expand deserialization.
- `lib/lattice_stripe/file.ex` — Phase 32 shipped; `purpose: "dispute_evidence"` is a valid file purpose.

### Stripe API Documentation
- [Stripe Dispute Object](https://docs.stripe.com/api/disputes/object) — Full field reference, nested objects, status/reason enum values
- [Stripe Update Dispute](https://docs.stripe.com/api/disputes/update) — Single endpoint for metadata, evidence, and submit
- [Stripe Close Dispute](https://docs.stripe.com/api/disputes/close) — Close/accept endpoint
- [Stripe Dispute Evidence Object](https://docs.stripe.com/api/disputes/evidence_object) — 27 evidence fields reference

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Client.request/2` pipeline — all dispute ops use standard JSON request path (no multipart/binary)
- `Resource.unwrap_singular/2` and `unwrap_list/2` — used for all retrieve/list/update/close operations
- `ObjectTypes.maybe_deserialize/1` — handles `charge` expand and `balance_transactions` element deserialization
- Existing `BalanceTransaction.from_map/1` and `Charge.from_map/1` — reused directly for nested fields
- `atomize_status/1` private function pattern — copied from Subscription/Invoice/Payout for Dispute status and reason

### Established Patterns
- `@known_fields ~w[...]` + `defstruct` + `from_map/1` + `extra: %{}` — all resource modules
- Bang variants via `Resource.unwrap_bang!/1` — every operation gets a `!` variant
- `stream!/3` via `List.stream!/2 |> Stream.map(&from_map/1)` — auto-pagination
- Explicit verb functions for irreversible ops — `close/3`, `submit_evidence/3` follow `reject/4`, `cancel/3` precedent
- `## Irreversibility` doc section — established by `Account.reject/4`
- Private atomizer functions called at parse time in `from_map/1` — post-Phase 22 standard

### Integration Points
- `object_types.ex` — register `"dispute"` type
- Nine-group ExDoc layout — Dispute modules go in Payments group (disputes are payment-related)
- `test/support/fixtures/` — add `dispute_json/1`, `dispute_evidence_json/1`, `dispute_evidence_details_json/1`

</code_context>

<specifics>
## Specific Ideas

### Three-Function Evidence Architecture
```
update/4            -> do_update(client, id, params, opts)             # Raw pass-through
update_evidence/4   -> do_update(client, id, %{evidence: ..., submit: false}, opts)  # Safety wrapper
submit_evidence/3   -> do_update(client, id, %{submit: true}, opts)   # Irreversible
close/3             -> POST /v1/disputes/:id/close                    # Separate endpoint
```

### Dispute API Surface
- `retrieve/3`, `retrieve!/3` — GET /v1/disputes/:id
- `update/4`, `update!/4` — POST /v1/disputes/:id (metadata + raw evidence)
- `update_evidence/4`, `update_evidence!/4` — POST /v1/disputes/:id (safe evidence staging)
- `submit_evidence/3`, `submit_evidence!/3` — POST /v1/disputes/:id (irreversible submit)
- `close/3`, `close!/3` — POST /v1/disputes/:id/close (accept/forfeit)
- `list/3`, `list!/3` — GET /v1/disputes
- `stream!/3` — auto-paginating lazy stream

No `create` (Stripe creates disputes automatically) and no `delete` (disputes cannot be deleted).

</specifics>

<deferred>
## Deferred Ideas

- `Builders.Dispute` changeset-style evidence builder — explicitly out of scope per REQUIREMENTS.md (flat 27-field struct; raw map sufficient). Add later if user feedback demands it.
- `PaymentMethodDetails.Card` typed struct — promote from raw map if demand appears for compile-time card field checking.
- Deeper `three_d_secure` typing inside card — informational leaf data, not worth the API surface cost now.

None — discussion stayed within phase scope

</deferred>

---

*Phase: 33-disputes*
*Context gathered: 2026-04-17*
