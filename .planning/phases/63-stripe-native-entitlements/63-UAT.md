---
status: complete
phase: 63-stripe-native-entitlements
source:
  - 63-01-SUMMARY.md
  - 63-02-SUMMARY.md
  - 63-03-SUMMARY.md
  - 63-04-SUMMARY.md
  - 63-05-SUMMARY.md
  - 63-06-SUMMARY.md
  - 63-07-SUMMARY.md
started: 2026-07-28T15:33:00Z
updated: 2026-07-28T15:40:00Z
coverage_mode: coverage
auto_passed: 56
human_checkpoints: 7
human_approved: 7
---

## Current Test

[testing complete]

## Tests

### 1. Archiving vocabulary split is taught where the reader hits it
expected: |
  `lib/lattice_stripe/entitlements/feature.ex` `## Archiving` names both `active`
  (the object field) and `archived` (the list filter), states the inverted sense,
  carries the `{: .warning}` "Archived is not deleted" admonition describing the
  false-deletion consequence, and prescribes `%{"archived" => true}` for
  reconciliation. Documentation is the only available mitigation here — stripe-mock's
  response does not vary by filter, so no test can prove the behavior.
coverage_id: D10
plan: 63-03
requirement: ENT-04
threat: T-63-08
result: pass
source: human-approved

### 2. lookup_key immutability is documented as the reason it is safe to key on
expected: |
  `lib/lattice_stripe/entitlements/feature.ex` `## Using lookup_key as your system
  identifier` states that `lookup_key` is immutable after create (absent from the
  update body schema, so Stripe silently ignores changes), shows the
  `%{"lookup_key" => ...}` list filter form, and explains the return is a list not a
  singleton — with the rationale for shipping no `retrieve_by_lookup_key/3`.
  Judgement call: does this give you enough confidence to key your own host
  configuration on lookup keys?
coverage_id: D11
plan: 63-03
requirement: ENT-04
decision: D-12
result: pass
source: human-approved

### 3. Auto-pagination is unprovable at the stripe-mock leg — accepted risk
expected: |
  Auto-pagination across pages for a customer with more than one active entitlement
  is NOT asserted in the integration suite. stripe-mock returns exactly one synthetic
  item per list and ignores both page size and cursor, so multi-page behavior is
  structurally unprovable there. The proof lives instead in the Mox multi-page suites
  (`test/lattice_stripe/entitlements/active_entitlement_stream_test.exs`, plan 63-02),
  which do assert cursor construction, wire order, and exactly-N transport calls.
  Live-Stripe confirmation remains a backstop with no live key in this environment.
  Judgement call: accept Mox-level pagination proof as sufficient (accepted risk A1)?
coverage_id: D7
plan: 63-05
requirement: ENT-01
result: pass
source: human-approved

### 4. Phase 65 fixture promotion recorded as move-plus-rename
expected: |
  `.planning/ROADMAP.md`'s Phase 65 build-constraints line records that promoting the
  private fixtures to public is a file move PLUS a module rename — naming
  `LatticeStripe.Testing.Fixtures.Entitlements`, `test/support/fixtures/entitlements.ex`,
  and all four function names — so Phase 65 cannot be planned as a verbatim file move.
  Judgement call: is that constraint recorded clearly enough that Phase 65 planning
  will not get it wrong?
coverage_id: D8
plan: 63-05
requirement: ENT-03
decision: D-27
result: pass
source: human-approved

### 5. Guide refuses the gate helper by name and ships the replacement
expected: |
  `guides/entitlements.md` `## Scope boundary` says "There is no `entitled?` helper,
  and there will not be one", explains that a network-calling authorization gate fails
  **open** under partition (granting access to something not bought, exactly when you
  are least able to notice), and then ships the working four-step fail-closed
  replacement in the same section: reconcile on webhook → persist locally → gate
  locally on every request → fail closed on staleness.
  Judgement call: does refusing the helper AND supplying the recipe together read as
  a complete answer rather than a missing feature?
coverage_id: D3
plan: 63-06
requirement: ENT-01
threat: T-63-04
result: pass
source: human-approved

### 6. Three pre-cut stub sections let Phases 65/66 append, not restructure
expected: |
  `guides/entitlements.md` has `## Attaching features to products`, `## Testing`, and
  `## Webhooks` — each already present with a paragraph naming what will live there
  and pointing at the guide that covers the pattern today (testing.md / webhooks.md)
  plus the interim workaround. Phases 65 and 66 fill them in rather than reorganizing
  the guide.
  Judgement call: are the stubs useful to a reader *today*, or do they read as
  unfinished?
coverage_id: D7
plan: 63-06
requirement: ENT-01
result: pass
source: human-approved

### 7. Exactly three prose locks for this family — no generic pagination sentence
expected: |
  The docs-truth suite locks exactly three prose anchors for the entitlements family
  and deliberately locks NO generic pagination sentence (no `has_more` /
  `starting_after` prose is asserted against any source). The structural pagination
  proof is the ten-assertion stream suite from 63-02 instead.
  Judgement call: is three the right amount of prose to freeze — enough that the
  safety-critical wording cannot silently rot, not so much that ordinary doc edits
  start failing CI?
coverage_id: D8
plan: 63-07
requirement: ENT-05
result: pass
source: human-approved

<!-- Entries 8-63 are deterministically covered by passing tests (coverage mode, #1602). Not presented as checkpoints. -->

### 8. [63-01 D1] ActiveEntitlement.list/3 issues one GET to /v1/entitlements/active_entitlements with the customer filter and returns {:ok, %Response{data: %List{data:
expected: ActiveEntitlement.list/3 issues one GET to /v1/entitlements/active_entitlements with the customer filter and returns {:ok, %Response{data: %List{data: [%ActiveEntitlement{}]}}} — typed structs, not raw maps
result: pass
source: automated
coverage_id: D1
plan: 63-01
requirement: ENT-01
verification: unit:pass, unit:pass

### 9. [63-01 D2] The expandable feature field decodes to %Entitlements.Feature{} when Stripe expands it and stays the bare feat_ id string when it does not
expected: The expandable feature field decodes to %Entitlements.Feature{} when Stripe expands it and stays the bare feat_ id string when it does not
result: pass
source: automated
coverage_id: D2
plan: 63-01
requirement: ENT-01
verification: unit:pass, unit:pass

### 10. [63-01 D3] from_map/1 is total and idempotent — nil maps to nil, an already-decoded struct returns unchanged, unknown wire keys land in :extra
expected: from_map/1 is total and idempotent — nil maps to nil, an already-decoded struct returns unchanged, unknown wire keys land in :extra
result: pass
source: automated
coverage_id: D3
plan: 63-01
requirement: ENT-01
verification: unit:pass, unit:pass, unit:pass, unit:pass

### 11. [63-01 D4] Decoding is order- and identity-preserving: an empty page is a typed empty %List{}, and two entitlements sharing a lookup_key stay two distinct struct
expected: Decoding is order- and identity-preserving: an empty page is a typed empty %List{}, and two entitlements sharing a lookup_key stay two distinct structs in wire order
result: pass
source: automated
coverage_id: D4
plan: 63-01
requirement: ENT-01
verification: unit:pass, unit:pass

### 12. [63-01 D5] T-63-01: the customer filter is mandatory and enforced BEFORE any transport call — list/3 without it raises ArgumentError with zero Mox expectations c
expected: T-63-01: the customer filter is mandatory and enforced BEFORE any transport call — list/3 without it raises ArgumentError with zero Mox expectations consumed
result: pass
source: automated
coverage_id: D5
plan: 63-01
requirement: ENT-01
verification: unit:pass, unit:pass

### 13. [63-01 D6] T-63-04: no per-request network gate helper exists and the module is read-only — entitled?/2,3,4, create, update, and delete are all structurally abse
expected: T-63-04: no per-request network gate helper exists and the module is read-only — entitled?/2,3,4, create, update, and delete are all structurally absent while the shipped read surface is pinned positively
result: pass
source: automated
coverage_id: D6
plan: 63-01
requirement: ENT-01
verification: unit:pass, unit:pass, unit:pass

### 14. [63-01 D7] Test-support scaffolding for the whole phase: four wire-shaped fixtures with the exact Phase 65 promotion names, and TestHelpers.list_json/3 widened b
expected: Test-support scaffolding for the whole phase: four wire-shaped fixtures with the exact Phase 65 promotion names, and TestHelpers.list_json/3 widened backward-compatibly
result: pass
source: automated
coverage_id: D7
plan: 63-01
requirement: 
verification: unit:pass

### 15. [63-01 D8] Clean-HEAD ExDoc warning baseline captured as a plain integer (42) for the 63-07 differential docs gate
expected: Clean-HEAD ExDoc warning baseline captured as a plain integer (42) for the 63-07 differential docs gate
result: pass
source: automated
coverage_id: D8
plan: 63-01
requirement: 
verification: other:pass

### 16. [63-02 D9] ENT-03: retrieve/3 GETs /v1/entitlements/active_entitlements/{id} and returns a single typed %ActiveEntitlement{}; retrieve!/3 returns the bare struct
expected: ENT-03: retrieve/3 GETs /v1/entitlements/active_entitlements/{id} and returns a single typed %ActiveEntitlement{}; retrieve!/3 returns the bare struct and raises LatticeStripe.Error on a Stripe error payload
result: pass
source: automated
coverage_id: D9
plan: 63-02
requirement: ENT-03
verification: unit:pass, unit:pass, unit:pass

### 17. [63-02 D10] ENT-02: stream!/3 auto-follows has_more, emits every item from every page as a typed struct in wire order with no duplicates at the seam, and the page
expected: ENT-02: stream!/3 auto-follows has_more, emits every item from every page as a typed struct in wire order with no duplicates at the seam, and the page-2 cursor is starting_after = the LAST id of page 1
result: pass
source: automated
coverage_id: D10
plan: 63-02
requirement: ENT-02
verification: unit:pass, unit:pass, unit:pass

### 18. [63-02 D11] T-63-02 (high, Information Disclosure): the customer filter survives cursor construction — page 2 still carries customer=cus_123. Mutation-checked: ze
expected: T-63-02 (high, Information Disclosure): the customer filter survives cursor construction — page 2 still carries customer=cus_123. Mutation-checked: zeroing base_params in List.build_next_page_request/1 fails exactly this test and no other.
result: pass
source: automated
coverage_id: D11
plan: 63-02
requirement: ENT-02
verification: unit:pass, other:pass

### 19. [63-02 D12] T-63-03 / T-63-05: the stripe-account header carries to the page-2 request; the idempotency-key header does not
expected: T-63-03 / T-63-05: the stripe-account header carries to the page-2 request; the idempotency-key header does not
result: pass
source: automated
coverage_id: D12
plan: 63-02
requirement: ENT-02
verification: unit:pass, unit:pass

### 20. [63-02 D13] ENT-02 prohibition: enumeration is complete or it fails loudly — a 500 on page 2 raises LatticeStripe.Error rather than silently truncating
expected: ENT-02 prohibition: enumeration is complete or it fails loudly — a 500 on page 2 raises LatticeStripe.Error rather than silently truncating
result: pass
source: automated
coverage_id: D13
plan: 63-02
requirement: ENT-02
verification: unit:pass

### 21. [63-02 D14] The stream is lazy and total at the boundaries: Stream.take/2 over a two-page stream makes exactly one transport call, and an empty first page yields 
expected: The stream is lazy and total at the boundaries: Stream.take/2 over a two-page stream makes exactly one transport call, and an empty first page yields [] from exactly one call
result: pass
source: automated
coverage_id: D14
plan: 63-02
requirement: ENT-02
verification: unit:pass, unit:pass

### 22. [63-02 D15] Order stability under ties: entitlements sharing a lookup_key keep their relative wire order across the page seam
expected: Order stability under ties: entitlements sharing a lookup_key keep their relative wire order across the page seam
result: pass
source: automated
coverage_id: D15
plan: 63-02
requirement: ENT-02
verification: unit:pass

### 23. [63-02 D16] D-10 / Pitfall 6: stream!/3 raises ArgumentError at CALL time with no Enum step and zero Mox expectations consumed, and the surface lock forbids a non
expected: D-10 / Pitfall 6: stream!/3 raises ArgumentError at CALL time with no Enum step and zero Mox expectations consumed, and the surface lock forbids a non-bang stream/1,2,3 twin
result: pass
source: automated
coverage_id: D16
plan: 63-02
requirement: ENT-02
verification: unit:pass, unit:pass, unit:pass

### 24. [63-03 D1] create/3 POSTs /v1/entitlements/features and returns {:ok, %Feature{}} with lookup_key and name on the wire
expected: create/3 POSTs /v1/entitlements/features and returns {:ok, %Feature{}} with lookup_key and name on the wire
result: pass
source: automated
coverage_id: D1
plan: 63-03
requirement: ENT-04
verification: unit:pass, unit:pass

### 25. [63-03 D2] T-63-08 half one / D-10: create/3 guards BOTH required params before any transport call, in wire order, and an empty params map names lookup_key first
expected: T-63-08 half one / D-10: create/3 guards BOTH required params before any transport call, in wire order, and an empty params map names lookup_key first
result: pass
source: automated
coverage_id: D2
plan: 63-03
requirement: ENT-04
verification: unit:pass, unit:pass, unit:pass

### 26. [63-03 D3] T-63-09: a retried create/3 carrying the same idempotency_key opt sends the same idempotency-key header on BOTH attempts, so Stripe de-duplicates rath
expected: T-63-09: a retried create/3 carrying the same idempotency_key opt sends the same idempotency-key header on BOTH attempts, so Stripe de-duplicates rather than creating a second feature
result: pass
source: automated
coverage_id: D3
plan: 63-03
requirement: ENT-04
verification: unit:pass

### 27. [63-03 D4] retrieve/3 GETs the item path and update/4 POSTs it; update/4 with active: false is the archive operation and decodes an archived %Feature{active: fal
expected: retrieve/3 GETs the item path and update/4 POSTs it; update/4 with active: false is the archive operation and decodes an archived %Feature{active: false}
result: pass
source: automated
coverage_id: D4
plan: 63-03
requirement: ENT-04
verification: unit:pass, unit:pass, unit:pass

### 28. [63-03 D5] list/3 passes archived and lookup_key filters through to the query string unchanged, and a single-match lookup_key filter returns a %LatticeStripe.Lis
expected: list/3 passes archived and lookup_key filters through to the query string unchanged, and a single-match lookup_key filter returns a %LatticeStripe.List{} of one — a list, never a singleton
result: pass
source: automated
coverage_id: D5
plan: 63-03
requirement: ENT-04
verification: unit:pass, unit:pass

### 29. [63-03 D6] Decoding is total and order-preserving: an empty page is a typed empty %List{}, and two features sharing a name keep their relative wire order
expected: Decoding is total and order-preserving: an empty page is a typed empty %List{}, and two features sharing a name keep their relative wire order
result: pass
source: automated
coverage_id: D6
plan: 63-03
requirement: ENT-04
verification: unit:pass, unit:pass

### 30. [63-03 D7] D-13: stream!/3 emits typed %Feature{} values and carries filters onto every page it fetches, so full catalog enumeration under a filter is not silent
expected: D-13: stream!/3 emits typed %Feature{} values and carries filters onto every page it fetches, so full catalog enumeration under a filter is not silently truncated at page 1
result: pass
source: automated
coverage_id: D7
plan: 63-03
requirement: ENT-04
verification: unit:pass, unit:pass

### 31. [63-03 D8] from_map/1 is total and idempotent — nil maps to nil, an already-typed struct returns unchanged, unknown wire keys land in :extra
expected: from_map/1 is total and idempotent — nil maps to nil, an already-typed struct returns unchanged, unknown wire keys land in :extra
result: pass
source: automated
coverage_id: D8
plan: 63-03
requirement: ENT-04
verification: unit:pass, unit:pass, unit:pass

### 32. [63-03 D9] D-23 L1: the COMPLETE surface is locked in both directions — every shipped function pinned at every exported arity, and delete, archive, unarchive, se
expected: D-23 L1: the COMPLETE surface is locked in both directions — every shipped function pinned at every exported arity, and delete, archive, unarchive, set_active, retrieve_by_lookup_key and a non-bang stream all refuted
result: pass
source: automated
coverage_id: D9
plan: 63-03
requirement: ENT-04
verification: unit:pass, unit:pass, unit:pass, unit:pass, unit:pass

### 33. [63-04 D1] ENT-05: an entitlements.active_entitlement_summary wire payload deserializes into a %ActiveEntitlementSummary{} — never a raw map, never nil — with cu
expected: ENT-05: an entitlements.active_entitlement_summary wire payload deserializes into a %ActiveEntitlementSummary{} — never a raw map, never nil — with customer, livemode and object populated
result: pass
source: automated
coverage_id: D1
plan: 63-04
requirement: ENT-05
verification: unit:pass

### 34. [63-04 D2] F-02: the struct has no :id field at all — asserted as a design decision, not merely observed
expected: F-02: the struct has no :id field at all — asserted as a design decision, not merely observed
result: pass
source: automated
coverage_id: D2
plan: 63-04
requirement: ENT-05
verification: unit:pass, other:pass

### 35. [63-04 D3] D-02: the nested entitlements field is a %LatticeStripe.List{} whose data is [%ActiveEntitlement{}], with has_more preserved from the wire
expected: D-02: the nested entitlements field is a %LatticeStripe.List{} whose data is [%ActiveEntitlement{}], with has_more preserved from the wire
result: pass
source: automated
coverage_id: D3
plan: 63-04
requirement: ENT-05
verification: unit:pass, unit:pass

### 36. [63-04 D4] D-05 / T-63-12 (medium, DoS): _last_id is non-nil and equals the id of the last RAW item — cursor derivation ran before the data was typed. Mutation-c
expected: D-05 / T-63-12 (medium, DoS): _last_id is non-nil and equals the id of the last RAW item — cursor derivation ran before the data was typed. Mutation-checked: typing data before List.from_json/3 fails exactly this test.
result: pass
source: automated
coverage_id: D4
plan: 63-04
requirement: ENT-05
verification: unit:pass, other:pass

### 37. [63-04 D5] D-04 / Pitfall 2: the nested list's url is rewritten to /v1/entitlements/active_entitlements and is not the webhook-shaped path the fixture carried in
expected: D-04 / Pitfall 2: the nested list's url is rewritten to /v1/entitlements/active_entitlements and is not the webhook-shaped path the fixture carried in
result: pass
source: automated
coverage_id: D5
plan: 63-04
requirement: ENT-05
verification: unit:pass

### 38. [63-04 D6] T-63-13 (high, Information Disclosure): the nested list's _params is %{\"customer\" => customer}, so a page-2 fetch off the nested list stays tenant-s
expected: T-63-13 (high, Information Disclosure): the nested list's _params is %{\"customer\" => customer}, so a page-2 fetch off the nested list stays tenant-scoped
result: pass
source: automated
coverage_id: D6
plan: 63-04
requirement: ENT-05
verification: unit:pass

### 39. [63-04 D7] D-26: a summary whose nested data is [] with has_more: true still deserializes — the real 'customer paid but has no feature provisioned yet' Stripe st
expected: D-26: a summary whose nested data is [] with has_more: true still deserializes — the real 'customer paid but has no feature provisioned yet' Stripe state
result: pass
source: automated
coverage_id: D7
plan: 63-04
requirement: ENT-05
verification: unit:pass

### 40. [63-04 D8] D-03 / T-63-11 (high, DoS): stream_entitlements!/3 performs a full canonical re-fetch keyed on summary.customer with limit 100 and ignores the inline 
expected: D-03 / T-63-11 (high, DoS): stream_entitlements!/3 performs a full canonical re-fetch keyed on summary.customer with limit 100 and ignores the inline page; no non-bang twin, and no retrieve at any arity
result: pass
source: automated
coverage_id: D8
plan: 63-04
requirement: ENT-05
verification: unit:pass, unit:pass, other:pass

### 41. [63-04 D9] D-26 tail: from_map/1 is idempotent and nil-tolerant, and unknown wire keys land in extra
expected: D-26 tail: from_map/1 is idempotent and nil-tolerant, and unknown wire keys land in extra
result: pass
source: automated
coverage_id: D9
plan: 63-04
requirement: ENT-05
verification: unit:pass, unit:pass

### 42. [63-05 D1] ActiveEntitlement.list/3 routes to /v1/entitlements/active_entitlements against a server generated from Stripe's own OpenAPI spec, and decodes into a 
expected: ActiveEntitlement.list/3 routes to /v1/entitlements/active_entitlements against a server generated from Stripe's own OpenAPI spec, and decodes into a %Response{} wrapping a %List{} of %ActiveEntitlement{} structs
result: pass
source: automated
coverage_id: D1
plan: 63-05
requirement: ENT-01
verification: integration:pass

### 43. [63-05 D2] ActiveEntitlement.retrieve/3 routes to the item path and decodes a typed struct carrying the entitlements.active_entitlement object tag
expected: ActiveEntitlement.retrieve/3 routes to the item path and decodes a typed struct carrying the entitlements.active_entitlement object tag
result: pass
source: automated
coverage_id: D2
plan: 63-05
requirement: ENT-01
verification: integration:pass

### 44. [63-05 D3] Feature.create/3 POSTs /v1/entitlements/features and the server echoes lookup_key and name back with active: true — proof the form-encoded body is acc
expected: Feature.create/3 POSTs /v1/entitlements/features and the server echoes lookup_key and name back with active: true — proof the form-encoded body is accepted, not merely constructed
result: pass
source: automated
coverage_id: D3
plan: 63-05
requirement: ENT-04
verification: integration:pass

### 45. [63-05 D4] Feature.retrieve/3 and update/4 both route to the item path and decode typed %Feature{} structs
expected: Feature.retrieve/3 and update/4 both route to the item path and decode typed %Feature{} structs
result: pass
source: automated
coverage_id: D4
plan: 63-05
requirement: ENT-04
verification: integration:pass, integration:pass

### 46. [63-05 D5] Feature.list/3 routes to the canonical list path, and the archived filter is accepted with a 200 — acceptance only, since stripe-mock's synthetic resp
expected: Feature.list/3 routes to the canonical list path, and the archived filter is accepted with a 200 — acceptance only, since stripe-mock's synthetic response does not vary by filter
result: pass
source: automated
coverage_id: D5
plan: 63-05
requirement: ENT-04
verification: integration:pass, integration:pass

### 47. [63-05 D6] T-63-15: the suite never reports green when stripe-mock is absent — setup_all raises with the exact docker command, invalidating every test in the mod
expected: T-63-15: the suite never reports green when stripe-mock is absent — setup_all raises with the exact docker command, invalidating every test in the module
result: pass
source: automated
coverage_id: D6
plan: 63-05
requirement: ENT-03
verification: other:pass

### 48. [63-06 D1] A reader arriving at the published docs finds the Entitlements guide in the Canonical Guides sidebar group, between customer-portal and metering
expected: A reader arriving at the published docs finds the Entitlements guide in the Canonical Guides sidebar group, between customer-portal and metering
result: pass
source: automated
coverage_id: D1
plan: 63-06
requirement: ENT-01
verification: other:pass

### 49. [63-06 D2] The three Entitlements modules appear together under their own sidebar group adjacent to Billing Metering
expected: The three Entitlements modules appear together under their own sidebar group adjacent to Billing Metering
result: pass
source: automated
coverage_id: D2
plan: 63-06
requirement: ENT-01
verification: other:pass

### 50. [63-06 D4] The reconciler example is one call with no has_more branch — the reader never learns that Stripe inlines ten
expected: The reconciler example is one call with no has_more branch — the reader never learns that Stripe inlines ten
result: pass
source: automated
coverage_id: D4
plan: 63-06
requirement: ENT-05
verification: other:pass

### 51. [63-06 D5] T-63-17 (medium, Repudiation): the refused gate helper is recorded on the project-wide, docs-truth-locked deferred-scope page, not only in a phase art
expected: T-63-17 (medium, Repudiation): the refused gate helper is recorded on the project-wide, docs-truth-locked deferred-scope page, not only in a phase artifact
result: pass
source: automated
coverage_id: D5
plan: 63-06
requirement: ENT-01
verification: other:pass, unit:pass

### 52. [63-06 D6] The Managing features section is a verb table, so a future verb appends one row rather than rewriting prose
expected: The Managing features section is a verb table, so a future verb appends one row rather than rewriting prose
result: pass
source: automated
coverage_id: D6
plan: 63-06
requirement: ENT-04
verification: other:pass

### 53. [63-06 D8] mix docs builds the guide with no new warnings and no warning naming the new surface
expected: mix docs builds the guide with no new warnings and no warning naming the new surface
result: pass
source: automated
coverage_id: D8
plan: 63-06
requirement: ENT-01
verification: other:pass

### 54. [63-06 D9] Every function documented in the guide exists at the documented arity, and every claimed absence is a real absence
expected: Every function documented in the guide exists at the documented arity, and every claimed absence is a real absence
result: pass
source: automated
coverage_id: D9
plan: 63-06
requirement: ENT-01
verification: other:pass

### 55. [63-07 D1] A docs-truth test fails if guides/entitlements.md is dropped from either extras: or the Canonical Guides group
expected: A docs-truth test fails if guides/entitlements.md is dropped from either extras: or the Canonical Guides group
result: pass
source: automated
coverage_id: D1
plan: 63-07
requirement: ENT-01
verification: unit:pass, other:pass

### 56. [63-07 D2] A docs-truth test fails if the Entitlements module group is removed from mix.exs or loses a module
expected: A docs-truth test fails if the Entitlements module group is removed from mix.exs or loses a module
result: pass
source: automated
coverage_id: D2
plan: 63-07
requirement: ENT-01
verification: unit:pass

### 57. [63-07 D3] T-63-04 (high, EoP): a docs-truth test fails if the ActiveEntitlement moduledoc loses `gate`, `fail closed`, or `stream!/3`
expected: T-63-04 (high, EoP): a docs-truth test fails if the ActiveEntitlement moduledoc loses `gate`, `fail closed`, or `stream!/3`
result: pass
source: automated
coverage_id: D3
plan: 63-07
requirement: ENT-01
verification: other:pass

### 58. [63-07 D4] A docs-truth test fails if the ActiveEntitlementSummary moduledoc loses `no top-level`
expected: A docs-truth test fails if the ActiveEntitlementSummary moduledoc loses `no top-level`
result: pass
source: automated
coverage_id: D4
plan: 63-07
requirement: ENT-05
verification: other:pass

### 59. [63-07 D5] T-63-08 (medium, Tampering): the archiving vocabulary warning cannot be silently deleted
expected: T-63-08 (medium, Tampering): the archiving vocabulary warning cannot be silently deleted
result: pass
source: automated
coverage_id: D5
plan: 63-07
requirement: ENT-04
verification: unit:pass

### 60. [63-07 D6] `entitled?` is asserted present and never refuted
expected: `entitled?` is asserted present and never refuted
result: pass
source: automated
coverage_id: D6
plan: 63-07
requirement: ENT-01
verification: other:pass

### 61. [63-07 D7] T-63-17 (medium, Repudiation): the guides/scope.md lock now covers the refused gate helper alongside its existing anchors
expected: T-63-17 (medium, Repudiation): the guides/scope.md lock now covers the refused gate helper alongside its existing anchors
result: pass
source: automated
coverage_id: D7
plan: 63-07
requirement: ENT-01
verification: other:pass

### 62. [63-07 D9] T-63-19 (high, Repudiation): all five phase gates green, measured rather than asserted
expected: T-63-19 (high, Repudiation): all five phase gates green, measured rather than asserted
result: pass
source: automated
coverage_id: D9
plan: 63-07
requirement: ENT-01
verification: other:pass

### 63. [63-07 D10] mix docs emits no warning naming the new surface and the total has not risen above the clean-HEAD baseline
expected: mix docs emits no warning naming the new surface and the total has not risen above the clean-HEAD baseline
result: pass
source: automated
coverage_id: D10
plan: 63-07
requirement: ENT-01
verification: other:pass

## Summary

total: 63
passed: 63
issues: 0
pending: 0
skipped: 0

auto_passed: 56
human_approved: 7

## Coverage Notes

Test suite run at UAT start (2026-07-28):
- `mix test` — 2188 tests, 0 failures, 1 skipped (204 excluded)
- `mix test --only integration` (stripe-mock v0.199.0 on :12111) — 192 tests, 0 failures, 11 skipped
- `mix test --only integration test/integration/entitlements_integration_test.exs` — 7 tests, 0 failures

Schema defects found in SUMMARY `coverage:` blocks (surfaced per #1602, non-blocking —
entries were treated as human checkpoints rather than dropped):
- 63-03 D10, 63-05 D7: `verification[].status: deferred` is not one of {pass, fail, unknown}
- 63-03 D10, 63-03 D11, 63-05 D7, 63-05 D8, 63-06 D3, 63-06 D7, 63-07 D8:
  `rationale` is required when `human_judgment: true` but was omitted

`COVERAGE.md` verify:pre gate: initially blocked with 6 over-length `reason` cells
(>200 chars); reasons were condensed without changing any decision. Gate now passes —
28 capabilities, 18 INTEGRATE, 10 OPT-OUT.

## Human Approval

The 7 human-judgment checkpoints (tests 1-7) were presented together with the
verified evidence behind each and batch-approved by the user on 2026-07-28
("approve u do it pass"). All factual claims underlying them were confirmed
present in source before presentation; what the user approved is the taste /
accepted-risk judgment on top.

Notable accepted risk — test 3 (A1): multi-page auto-pagination is proven at the
Mox layer (63-02) only. stripe-mock cannot prove it (one synthetic item per list,
cursor ignored) and no live Stripe key exists in this environment.

## Gaps

[none]
