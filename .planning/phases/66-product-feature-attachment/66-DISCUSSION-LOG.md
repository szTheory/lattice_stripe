# Phase 66: Product ↔ Feature Attachment - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-25
**Phase:** 66-product-feature-attachment
**Areas discussed:** Attachment API contract, Typed catalog object graph, Enumeration and removal, Entitlements guide journey

---

## Attachment API Contract

| Option | Description | Selected |
|--------|-------------|----------|
| House-style resource surface | Publish parent-scoped `create`, `retrieve`, `list`, `stream!`, and `delete`, with the ordinary tuple/bang pairs and explicit IDs. | ✓ |
| Domain-style aliases | Add public `attach`, `detach`, or `remove` aliases alongside the canonical resource verbs. | |
| Convenience deletion by definition ID | Accept a `feat_...` ID and internally find then delete its Product attachment. | |

**User's choice:** “accept” — accept the complete researched recommendation set.

**Notes:** Official Stripe OpenAPI exposes item retrieval even though the documentation index emphasizes attach, list, and remove. The selected surface follows existing LatticeStripe conventions while using “attach” and “remove” as teaching language. A hidden lookup/delete convenience was rejected because it adds requests, pagination ambiguity, races, and surprising identity semantics.

---

## Typed Catalog Object Graph

| Option | Description | Selected |
|--------|-------------|----------|
| Separate attachment and marketing concepts | Model `/products/:product/features` results as `Product.Feature`, while preserving Product marketing fields as raw maps for 1.x compatibility. | ✓ |
| Decode `Product.features` as attachments | Treat the legacy Product field as a list of `Product.Feature` structs. | |
| Remove the legacy field | Delete `Product.features` and support only `marketing_features`. | |

**User's choice:** “accept” — accept the complete researched recommendation set.

**Notes:** Research corrected the roadmap premise: Stripe renamed the Product object's display-only `features` field to `marketing_features` in API version 2024-04-10. Neither field is an entitlement attachment collection. `Product.Feature` is instead the dedicated `product_feature` resource, containing a fully expanded `Entitlements.Feature`. Changing existing map values to structs in Hex 1.8.0 would violate the additive-minor compatibility contract. The exact ObjectTypes key is `"product_feature"`; `"product.feature"` in earlier prose is a typo.

---

## Enumeration and Removal

| Option | Description | Selected |
|--------|-------------|----------|
| List-only minimum | Expose only the first-page list endpoint and make callers implement complete pagination. | |
| Complete parent-scoped surface | Return a typed page from `list`, provide `stream!` for complete enumeration, retrieve by `prodft_...`, and delete by `prodft_...` with a typed deleted object. | ✓ |
| Hidden lookup by `feat_...` | Find an attachment from its entitlement definition and delete it implicitly. | |

**User's choice:** “accept” — accept the complete researched recommendation set.

**Notes:** The selected design preserves the distinction between reusable definition IDs (`feat_...`) and Product attachment IDs (`prodft_...`). It reuses the library's cursor state machine so Connect/request options and parent scope survive every page, later-page failures raise, and early stream termination avoids unnecessary requests.

---

## Entitlements Guide Journey

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal stub replacement | Replace only the Phase 66 placeholder with endpoint examples. | |
| Expand the canonical guide | Teach definition → attachment → purchase → active entitlement → webhook reconciliation → local authorization in `guides/entitlements.md`. | ✓ |
| New flagship recipe | Add a separate long-form catalog-to-access guide and navigation surface. | |

**User's choice:** “accept” — accept the complete researched recommendation set.

**Notes:** The existing Entitlements guide is the least-surprising discovery point. It should distinguish display-only marketing features from access-bearing Product attachments, expose inputs and outputs at each job step, retain the no-`entitled?` boundary, and add only a concise route to the JTBD guide. No application UI is in phase scope, and no newer project brandbook was found; established ExDoc structure and microcopy are the applicable design system.

---

## the agent's Discretion

- Exact moduledoc, guide, error-message, and test wording within the accepted contracts.
- Exact private helper organization for path composition, ID validation, and decoding.
- Exact plan/wave decomposition and placement of guide work within it.
- The user explicitly delegated comprehensive research and coherent one-shot recommendations across architecture, ecosystem idioms, DX, JTBD, user psychology, accessibility, performance, safety, maintainability, testing, and applicable UI/UX lenses.

## Deferred Ideas

- A typed `Product.MarketingFeature` runtime migration belongs in a future major release if adopter demand justifies the compatibility cost.
- A separate flagship catalog-to-access recipe remains deferred unless future user pull warrants another durable navigation surface.
- Application-owned catalog reconciliation storage, provisioning policy, and request-time authorization remain outside this primitive SDK phase.

---

*Phase: 66-product-feature-attachment*
*Discussion log generated: 2026-08-25*
