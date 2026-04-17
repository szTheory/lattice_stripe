# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/).

## [1.2.0](https://github.com/szTheory/lattice_stripe/compare/v1.1.0...v1.2.0) (2026-04-17)


### Features

* **22-01:** create ObjectTypes registry module with maybe_deserialize/1 ([5a446b2](https://github.com/szTheory/lattice_stripe/commit/5a446b22c2baf4fa01eb177ecf27a1f1ce3406f9))
* **22-02:** atomize + expand Charge, Refund, SetupIntent ([f203eae](https://github.com/szTheory/lattice_stripe/commit/f203eaedd25773d33846941de04bd8f868b3a4b5))
* **22-02:** atomize + expand PaymentIntent, Subscription, SubscriptionSchedule ([346dd55](https://github.com/szTheory/lattice_stripe/commit/346dd55bf14728ebac84514012ec6e86f4c0d90d))
* **22-03:** atomize + expand Payout, BalanceTransaction, BankAccount ([d5f4d68](https://github.com/szTheory/lattice_stripe/commit/d5f4d68a26a56bdc83c5c0d68a5ceffc255455cc))
* **22-03:** atomize Checkout.Session + auto-atomize Meter/Capability with deprecation ([3d16642](https://github.com/szTheory/lattice_stripe/commit/3d166427e611182050d3c083455457da4ebde74f))
* **22-04:** add expand guards to Invoice, InvoiceItem, SubscriptionItem, Card, PaymentMethod, PromotionCode + EXPD-02 dot-path expand test ([071c740](https://github.com/szTheory/lattice_stripe/commit/071c740c8b289528d4a971cbdd6d17690f8bf865))
* **22-04:** add expand guards to Transfer/TransferReversal + CHANGELOG migration note ([c3c8c84](https://github.com/szTheory/lattice_stripe/commit/c3c8c8457de9576af564ec0b4255dfbc32518180))
* **23-01:** add 4 Level 2 feature sub-struct modules for BillingPortal.Configuration ([4fa624c](https://github.com/szTheory/lattice_stripe/commit/4fa624cd946cf54649576052ba7a1b0fd927ff53))
* **23-01:** add Features dispatcher, Configuration fixture, and 5 unit test files ([08701df](https://github.com/szTheory/lattice_stripe/commit/08701dff13de490050077b0845c288d07105eccd))
* **23-02:** add BillingPortal.Configuration resource module ([a2723d0](https://github.com/szTheory/lattice_stripe/commit/a2723d08471cbc306907bc4032b9c2c545921114))
* **23-03:** wire Configuration into expand system and ExDoc grouping ([0edc3c3](https://github.com/szTheory/lattice_stripe/commit/0edc3c3f7261269e69e231a47bdf423d51f28723))
* **24-01:** enrich telemetry stop metadata with rate_limited_reason, escalate 429 to :warning ([431f57e](https://github.com/szTheory/lattice_stripe/commit/431f57ef0a6d4f91f420e4a2d2ff242451518416))
* **24-01:** thread resp_headers through Client retry loop as 3-tuple ([92baad0](https://github.com/szTheory/lattice_stripe/commit/92baad05aaedbb9664adf4eade20e3faf5fb8992))
* **24-02:** add fuzzy param suggestion to invalid_request_error ([3e5b693](https://github.com/szTheory/lattice_stripe/commit/3e5b6937e58fc2c117dd7c37dc15927d4292a852))
* **25-01:** add operation_timeouts to Config schema and Client struct ([3972547](https://github.com/szTheory/lattice_stripe/commit/39725477b3e38af69b8dd25a840559b6a3d794b9))
* **25-01:** implement classify_operation/1 and three-tier timeout resolution ([288b1a0](https://github.com/szTheory/lattice_stripe/commit/288b1a09641e84f1944326366a081e888337b722))
* **25-02:** add LatticeStripe.warm_up/1 and warm_up!/1 ([a70a4f8](https://github.com/szTheory/lattice_stripe/commit/a70a4f8b1f06aad099f6572d2059c8d732a2bfc3))
* **27-01:** implement Batch.run/3 with Task.async_stream fan-out ([55eb2db](https://github.com/szTheory/lattice_stripe/commit/55eb2db292490aa45631ee99a926d1e2d475255b))
* **28-01:** add MeterEventStream.Session struct with from_map/1 and Inspect masking ([1ac33b3](https://github.com/szTheory/lattice_stripe/commit/1ac33b3e5b2ad45cbbc5b9f12e2d72849c7c2ece))
* **28-01:** add MeterEventStreamSession fixture and Session unit tests ([36be4aa](https://github.com/szTheory/lattice_stripe/commit/36be4aaf8165bc02efcd952d2b28b32f11312f68))
* **28-02:** add unit tests, integration skeleton, ExDoc groups, and metering guide v2 section ([f47a1e0](https://github.com/szTheory/lattice_stripe/commit/f47a1e0fad580080be0683d6523080cf70266cb2))
* **28-02:** implement MeterEventStream with create_session/2 and send_events/4 ([984b1a4](https://github.com/szTheory/lattice_stripe/commit/984b1a417cd1cf20e97cb68611ad1ff119168596))
* **29-01:** implement SubscriptionSchedule changeset-style param builder ([eeabacb](https://github.com/szTheory/lattice_stripe/commit/eeabacbf2a492bd2ecc61d9b80cd95c6a02a6aad))
* **29-02:** implement BillingPortal FlowData builder ([89150e3](https://github.com/szTheory/lattice_stripe/commit/89150e3cdad9cc4711e77180d24a50195f36f930))
* **30-01:** ObjectTypes.object_map/0 accessor, Drift core module, OpenAPI spec fixture ([9e5a76f](https://github.com/szTheory/lattice_stripe/commit/9e5a76fe7457ea1e2f5e65b4827d806cf7166eb3))
* **30-02:** GitHub Actions weekly drift detection workflow ([92ef010](https://github.com/szTheory/lattice_stripe/commit/92ef010cdaa3a0b04d4084461eb3f1a2aa0050d0))
* **30-02:** Mix task shell for drift detection ([70e5dde](https://github.com/szTheory/lattice_stripe/commit/70e5dde36899904c4ad3deec7eaf951604cbeb8e))
* **31-01:** create stripe_explorer.livemd LiveBook notebook ([48e1085](https://github.com/szTheory/lattice_stripe/commit/48e1085d2515f28a5df9e77d3fd0377c3035b88c))
* **31-02:** complete notebook with WebhookPlug mention and Next Steps section ([005c50a](https://github.com/szTheory/lattice_stripe/commit/005c50a5c45d0c03d9bd57d81ac08a78837c0115))


### Bug Fixes

* **22:** add required parentheses to if-expressions in struct literals + update tests for atomized status ([5d8bc31](https://github.com/szTheory/lattice_stripe/commit/5d8bc318c6a10b8325c9949ac83824bdd02770c2))
* **22:** update deprecated status_atom/1 call in account_test to use apply/3 ([77e0c75](https://github.com/szTheory/lattice_stripe/commit/77e0c75c1481e72017a9768d4afe5ee0ec9cdad9))
* **22:** WR-01 fix stream!/3 error message referencing wrong function name ([9bc4e74](https://github.com/szTheory/lattice_stripe/commit/9bc4e748fb42d3303cc11bc74e6ed51bda21bac3))
* **22:** WR-03 add default object value for Billing.Meter ([0384c4e](https://github.com/szTheory/lattice_stripe/commit/0384c4ea9f67cded16fbe7088d573e0fcad7bddd))
* **24:** revise plans based on checker feedback ([a58d97b](https://github.com/szTheory/lattice_stripe/commit/a58d97b72b88a8e02d6bc018db3829e608364d06))
* **24:** WR-01 bind parse_type result once in from_response/3 ([f636a27](https://github.com/szTheory/lattice_stripe/commit/f636a2728fb62368d14c4d3eedf6c76ca92db92b))
* **24:** WR-02 add missing Stripe ID prefixes to id_segment?/1 ([ea35254](https://github.com/szTheory/lattice_stripe/commit/ea35254d25d9a5797a3cd4bb8eee0e83cb33aaf7))
* **24:** WR-03 document rate_limited_reason nil-on-success invariant in build_stop_metadata ([07153d2](https://github.com/szTheory/lattice_stripe/commit/07153d24b9ddc7b142fb440a6cd4eed9eea1ad25))
* **29:** WR-01 apply stringify_date to phase-level start_date and end_date in phase_build/1 ([8574eca](https://github.com/szTheory/lattice_stripe/commit/8574eca76176dd8a94786f3043c66b7bff6f8e1a))
* **30:** WR-01 exit 1 when new_resources non-empty in check_drift task ([bfc731e](https://github.com/szTheory/lattice_stripe/commit/bfc731e56b7b4e05497d8a3f1ffd76b30229ff81))
* **30:** WR-02 resolve_source_path fallback for cached CI builds in known_fields_for ([34cc82d](https://github.com/szTheory/lattice_stripe/commit/34cc82d1c242b19107064fcdb48d65f8cb1d7c2f))
* **30:** WR-03 replace throw/catch with with-chain in fetch_spec ([a306d2b](https://github.com/szTheory/lattice_stripe/commit/a306d2be3a03ad7aebd5e2513e5b5a7dcdbd10e1))
* **31:** CR-01 correct module for generate_test_signature — Webhook not Testing ([3b8270e](https://github.com/szTheory/lattice_stripe/commit/3b8270ea933c3a5bf489fa44d874b8113fb0e09f))
* **31:** WR-01 document confirmed dependency in Refund cell ([d2345d9](https://github.com/szTheory/lattice_stripe/commit/d2345d91c8677441b7c934aaeb1da17686ddaef7))
* **31:** WR-02 convert expires_at Unix timestamp to readable DateTime ([f83e712](https://github.com/szTheory/lattice_stripe/commit/f83e712f524ef98da35e3e9501d4a4bc95c403e9))

## [Unreleased]

### Changed

- **Expand deserialization** — When you pass `expand: ["customer"]` (or any expandable field), the response struct now contains a fully typed struct (e.g., `%Customer{}`) instead of a raw map. Fields that are not expanded remain as string IDs, unchanged. This applies to all resource modules.

  **Migration note:** If your code pattern-matches on expanded fields expecting a raw map, update to match on the typed struct:

  ```elixir
  # Before (v1.1):
  {:ok, %PaymentIntent{customer: %{"id" => id}}} = PaymentIntent.retrieve(client, id, expand: ["customer"])

  # After (v1.2):
  {:ok, %PaymentIntent{customer: %Customer{id: id}}} = PaymentIntent.retrieve(client, id, expand: ["customer"])
  ```

  If you were not passing `expand:`, your code is unaffected — unexpanded fields are still string IDs.

- **Status atomization** — All resource modules with a documented finite `status` field now return atoms (e.g., `:active`, `:succeeded`) instead of strings from `from_map/1`. Unknown or future status values pass through as raw strings for forward-compatibility.

  **Migration note:** If your code compares status as a string, update to atom comparison:

  ```elixir
  # Before (v1.1):
  if pi.status == "succeeded" do ...

  # After (v1.2):
  if pi.status == :succeeded do ...
  ```

  Affected modules: PaymentIntent, Subscription, SubscriptionSchedule, Charge, Refund, SetupIntent, Payout, BalanceTransaction, BankAccount, Checkout.Session, Billing.Meter, Account.Capability.

- **Deprecated** `Billing.Meter.status_atom/1` and `Account.Capability.status_atom/1` — status is now automatically atomized in `from_map/1`/`cast/1`. Access `.status` directly on the struct.

### Added

- `LatticeStripe.ObjectTypes` — internal module for Stripe object type dispatch (not part of public API).
- Union type specs (`Customer.t() | String.t() | nil`) on all expandable fields across all resource modules.

## [1.1.0](https://github.com/szTheory/lattice_stripe/compare/v1.0.0...v1.1.0) (2026-04-14)

### Highlights

The first post-1.0 minor release. Adds the two downstream unblockers needed by [Accrue](https://github.com/szTheory/accrue): usage-based billing (Billing Metering) and customer self-service (Customer Portal). Full phase history is in [PR #9](https://github.com/szTheory/lattice_stripe/pull/9).

**What's new:**
- **Billing Metering.** `Billing.Meter` CRUDL plus `deactivate/3` and `reactivate/3`, usage event ingestion via `MeterEvent.create/3`, and late corrections via `MeterEventAdjustment.create/3`. A pre-flight guard (`GUARD-03`) raises `ArgumentError` on malformed `value_settings` before the network call, preventing Stripe's silent-zero trap for `sum`/`last` aggregation formulas.
- **Customer Portal.** `BillingPortal.Session.create/3` returns a short-lived portal URL for a given customer. Full deep-link flow support (`subscription_cancel`, `subscription_update`, `subscription_update_confirm`, `payment_method_update`) via a 5-module nested `FlowData` struct tree. A pre-flight guard raises `ArgumentError` with actionable messages for missing required flow sub-fields, so malformed requests fail before they hit Stripe. The `Inspect` protocol masks the portal URL and flow to keep short-lived secrets out of log output.
- **Docs.** New `guides/metering.md` (usage-reporting idiom, idempotency two-layer explainer, reconciliation, backdating window, aggregation semantics) and `guides/customer-portal.md` (all 4 flow types with required sub-fields, Accrue-style Phoenix controller example, Inspect masking security teaching). New ExDoc groups: "Billing Metering" and "Customer Portal". Reciprocal cross-links from existing `guides/subscriptions.md` and `guides/webhooks.md`.

**Verification.** 1488 tests passing. Integration tests run against `stripe-mock`. `mix compile --warnings-as-errors`, `mix credo --strict`, and `mix docs --warnings-as-errors` all clean. Phase 20 and Phase 21 verification reports: passed.

**Upgrading from 1.0.x.** No breaking changes. Additive only — `Billing.Meter`, `Billing.MeterEvent`, `Billing.MeterEventAdjustment`, and `BillingPortal.Session` are new public modules. Existing code keeps working unchanged.

### Features

* **Billing.Meter:** `create/3`, `retrieve/3`, `update/4`, `list/2`, `deactivate/3`, `reactivate/3`
* **Billing.Meter.ValueSettings, DefaultAggregation, CustomerMapping, StatusTransitions:** nested typed structs with `:extra` forward-compat
* **Billing.MeterEvent:** `create/3` with two-layer idempotency (`identifier` vs `idempotency_key:`)
* **Billing.MeterEventAdjustment:** `create/3` with nested `Cancel` struct for late corrections
* **Billing.Guards.check_meter_value_settings!/1:** pre-flight shape guard for `value_settings` (GUARD-03, prevents silent-zero trap)
* **BillingPortal.Session:** `create/3` returns `{:ok, %Session{url: ..., flow: ...}}`
* **BillingPortal.Session.FlowData:** 5-module nested struct tree — `FlowData`, `AfterCompletion`, `SubscriptionCancel`, `SubscriptionUpdate`, `SubscriptionUpdateConfirm`
* **BillingPortal Guards:** pre-flight `check_flow_data!/1` raises `ArgumentError` for missing flow sub-fields, enumerating valid flow types on unknown input
* **Inspect masking for BillingPortal.Session:** hides `:url` and `:flow` fields via explicit allowlist to keep short-lived portal URLs out of logs
* **guides/metering.md:** usage-reporting idiom, idempotency layers, reconciliation, aggregation semantics
* **guides/customer-portal.md:** all 4 flow types, Accrue-style Phoenix controller example, Inspect masking security teaching
* **mix.exs:** `groups_for_modules` entries for "Billing Metering" and "Customer Portal"; both guides added to `extras`

## [1.0.0](https://github.com/szTheory/lattice_stripe/compare/v0.2.0...v1.0.0) (2026-04-13)

### Highlights

LatticeStripe 1.0 marks our commitment to API stability for the Elixir + Stripe integration story. The 0.2 → 1.0 journey spans four major milestones: a solid foundation of transport, retries, pagination, and observability (Phases 1-11); full Billing coverage for Invoices, Subscriptions, SubscriptionItems, and Subscription Schedules (Phases 14-16); end-to-end Connect support including accounts, onboarding links, external accounts, transfers, payouts, balance, and balance transactions (Phases 17-18); and a formalized public API surface with `@moduledoc false` internals and an explicit semver contract (Phase 19). Starting with 1.0.0, LatticeStripe follows standard semver: patch releases for bug fixes, minor releases for additive features, major releases for breaking public API changes — see [API Stability](guides/api_stability.md) for the full contract.

**What's in the box:**
- **Payments.** Customers, PaymentIntents, SetupIntents, PaymentMethods, Refunds, Checkout Sessions.
- **Billing.** Invoices (create, finalize, pay, void, send, search), Subscriptions with lifecycle verbs and pause helpers, Subscription Schedules with proration guards, Invoice Items.
- **Connect.** Accounts (Standard/Express/Custom), Account Links, Login Links, External Accounts (BankAccount/Card), Transfers + TransferReversals, Payouts (with TraceId), Balance + BalanceTransactions, Charge retrieve for fee reconciliation.
- **Webhooks.** Timing-safe signature verification, `Event` struct, Phoenix `Webhook.Plug`, `Webhook.Handler` behaviour.
- **Operational glue.** Pluggable `Transport`/`Json`/`RetryStrategy` behaviours, Telemetry events for every request, `LatticeStripe.Testing` helpers with TestClock support.

**Upgrading from 0.2.x.** No breaking API changes from 0.2. The public surface has been frozen; previously-visible internal modules (`FormEncoder`, `Request`, `Resource`, `Transport.Finch`, `Json.Jason`, `RetryStrategy.Default`, `Webhook.CacheBodyReader`, `Billing.Guards`) are now documented as private via `@moduledoc false` and are excluded from the semver contract.

**Supported versions.** Elixir 1.15+ on OTP 26+, tested up to Elixir 1.19 on OTP 28.

### Features

* **17-01:** add canonical Account/AccountLink/LoginLink fixtures ([a1a101c](https://github.com/szTheory/lattice_stripe/commit/a1a101cc15d87a1d47b15abad4d3a5109edb934a))
* **17-01:** add stripe-mock reject probe script and record result in VALIDATION.md ([e3539e9](https://github.com/szTheory/lattice_stripe/commit/e3539e9ae0a524d27997028fafb5a5d108f7314a))
* **17-02:** Account.Capability (D-02) with safe status_atom/1 ([3a80de4](https://github.com/szTheory/lattice_stripe/commit/3a80de499f52a4f4e93b7ab58ca33fd91c642fa0))
* **17-02:** PII-safe nested structs — TosAcceptance, Company, Individual ([fddb864](https://github.com/szTheory/lattice_stripe/commit/fddb8647e6030f8634ade3c2f92fa3d1b5364e3d))
* **17-02:** plain nested structs — BusinessProfile, Requirements, Settings ([4bd03c9](https://github.com/szTheory/lattice_stripe/commit/4bd03c9f6c0aeea3af1533150077f138dcaa408e))
* **17-03:** LatticeStripe.Account resource module — CRUD + reject + stream + from_map ([92747d0](https://github.com/szTheory/lattice_stripe/commit/92747d09235ce8b8cc839231b807fa1ff41b6336))
* **17-04:** LatticeStripe.AccountLink — create/3, create!/3, from_map/1 + tests ([7161f34](https://github.com/szTheory/lattice_stripe/commit/7161f34cddbce228ed8dfa7e8b91336b7ad166c6))
* **17-04:** LatticeStripe.LoginLink — create/4, create!/4, from_map/1 + tests ([0bd48d7](https://github.com/szTheory/lattice_stripe/commit/0bd48d707a125f63c9d163e43814a8285e0d176f))
* **17-05:** Account full-lifecycle integration test + fix cast_capabilities for stripe-mock ([e1364a6](https://github.com/szTheory/lattice_stripe/commit/e1364a6816d040006eb03a6885748225afaab188))
* **17-05:** AccountLink + LoginLink integration tests (9 tests each) ([ecb7494](https://github.com/szTheory/lattice_stripe/commit/ecb74948400c1535c077ce418b07bbee9e0079c5))
* **17-06:** add guides/connect.md — Connect onboarding narrative ([874dda9](https://github.com/szTheory/lattice_stripe/commit/874dda9ce161c9bb57581e8f58011420a8568836))
* **18-01:** add BankAccount + Card structs with F-001 and PII Inspect ([f775aff](https://github.com/szTheory/lattice_stripe/commit/f775aff07ef162842e544070f75b610f713b8f71))
* **18-01:** add ExternalAccount polymorphic dispatcher + Unknown fallback ([91148ac](https://github.com/szTheory/lattice_stripe/commit/91148ac963ada48c81da3e5d3ce2238c13b22f36))
* **18-02:** add LatticeStripe.Charge retrieve-only resource ([44a0adb](https://github.com/szTheory/lattice_stripe/commit/44a0adb6cf05b2f4a342403cb335dafab7993c42))
* **18-03:** add LatticeStripe.Transfer CRUDL with embedded reversals decoding ([90b1234](https://github.com/szTheory/lattice_stripe/commit/90b1234d730873dd0845f015cfe6818cf8c54fb6))
* **18-03:** add LatticeStripe.TransferReversal standalone module ([5cddcb9](https://github.com/szTheory/lattice_stripe/commit/5cddcb91d4b22ca4bd12278eaff6e7ef94c47b8b))
* **18-04:** add Payout CRUDL + cancel + reverse with TraceId integration ([79605ae](https://github.com/szTheory/lattice_stripe/commit/79605ae8c98fe2b3f9b6616c39a232459fc2bcd1))
* **18-04:** add Payout.TraceId nested typed struct ([52f6d11](https://github.com/szTheory/lattice_stripe/commit/52f6d11647733a80d741a33779734ee7e33082fc))
* **18-05:** add Balance singleton with Amount and SourceTypes nested structs ([5304b80](https://github.com/szTheory/lattice_stripe/commit/5304b80d0235b894b0148d2cd41c8c7e8d1c5d9c))
* **18-05:** add BalanceTransaction retrieve/list/stream + FeeDetail struct ([6873c5f](https://github.com/szTheory/lattice_stripe/commit/6873c5f553773e4e55013a9e835749be3a8f1bf8))
* **19-01:** rewrite mix.exs groups_for_modules to nine-group D-19 layout ([c66223b](https://github.com/szTheory/lattice_stripe/commit/c66223b2ed32a6c02eeddbdf704871cbb6e9288b))


### Bug Fixes

* **17-02:** align nested struct tests with 17-01 canonical fixture values ([025082a](https://github.com/szTheory/lattice_stripe/commit/025082a9fb04ca973394d1e818b8a1df098999ca))
* **18:** IN-01 correct BankAccount docstring account_number reference ([b720afa](https://github.com/szTheory/lattice_stripe/commit/b720afa066fb10e762b6f5e52798c3505f8b234a))
* **18:** IN-02 normalize nil/empty id guards to 'id in [nil, ""]' style ([542fc1b](https://github.com/szTheory/lattice_stripe/commit/542fc1bae0e3c88fae302e97e50b5e019ba95bac))
* **18:** IN-03 derive ExternalAccount.Unknown.cast drop list from [@known](https://github.com/known)_fields ([00d618e](https://github.com/szTheory/lattice_stripe/commit/00d618ed285675fca67836acddd1ee9e6576b351))
* **18:** IN-04 add is_map(params) guard to Payout.update/update! ([bdc4ab8](https://github.com/szTheory/lattice_stripe/commit/bdc4ab8c29f92e271ba0d1c0f83efa2fe8ebb582))
* **18:** IN-05 preserve unexpected Transfer reversals shape in extra ([ae1c85e](https://github.com/szTheory/lattice_stripe/commit/ae1c85e5ffef88a9a903758a738f7bb736e67d5d))
* **18:** WR-01 add map() to Transfer expandable typespecs ([772795e](https://github.com/szTheory/lattice_stripe/commit/772795e34c128552986a9063e75e6e8f3da598a7))
* **18:** WR-01 add map() to TransferReversal expandable typespecs ([fe9bbdd](https://github.com/szTheory/lattice_stripe/commit/fe9bbddab275cfbc7827a73d4ca541be512bfc1a))
* **18:** WR-02 add map() to Charge destination/source_transfer typespecs ([c26187d](https://github.com/szTheory/lattice_stripe/commit/c26187d10bddd32bf5130a2653193462ab0aeaac))
* **18:** WR-03 add nil/empty id guards to BalanceTransaction.retrieve/3 and retrieve!/3 ([e60f220](https://github.com/szTheory/lattice_stripe/commit/e60f2201bf5596ac8357c0dfcee745f3e356cda7))
* **18:** WR-03 add nil/empty id guards to Payout.update/4 and update!/4 ([4614b1c](https://github.com/szTheory/lattice_stripe/commit/4614b1c501443d04208f5fecf6a07b002da998ab))
* **18:** WR-03 restore balance_transaction id error message for test contract ([10a8827](https://github.com/szTheory/lattice_stripe/commit/10a882718bb277f25f39a5e62a5f90894eac70c5))

## [0.2.0](https://github.com/szTheory/lattice_stripe/compare/v0.1.0...v0.2.0) (2026-04-04)


### Features

* **01-01:** configure test infrastructure with Mox mocks, formatter, and Credo ([d75666e](https://github.com/szTheory/lattice_stripe/commit/d75666e3eaefbc8d1bffe5d641e73408cd3ef94d))
* **01-01:** scaffold Elixir project with Phase 1 dependencies ([2e4ae58](https://github.com/szTheory/lattice_stripe/commit/2e4ae5814b004e4e299d8d0244258fbc8cfb1f3e))
* **01-02:** implement JSON codec behaviour and Jason adapter with tests ([bb63aac](https://github.com/szTheory/lattice_stripe/commit/bb63aacd7b431fc5d3579515118547c74054e089))
* **01-02:** implement recursive Stripe-compatible form encoder with tests ([2c232e4](https://github.com/szTheory/lattice_stripe/commit/2c232e41dbb88cf31015adfb4e318b397d0e5391))
* **01-03:** implement Error struct with Stripe error response parsing and tests ([8438a4c](https://github.com/szTheory/lattice_stripe/commit/8438a4c948aaf27c73eea8f84731b36601a8f2cc))
* **01-03:** implement Transport behaviour and Request struct with tests ([192ddc9](https://github.com/szTheory/lattice_stripe/commit/192ddc9903e1774170c08983ff4edfdf60095199))
* **01-04:** implement Finch transport adapter with tests ([b0951e3](https://github.com/szTheory/lattice_stripe/commit/b0951e3efc660fa9c4655c97696811c29c942711))
* **01-04:** implement NimbleOptions config schema and validation with tests ([9441d19](https://github.com/szTheory/lattice_stripe/commit/9441d190846a437f3ff5f3b5289356ce56f2fc1b))
* **01-05:** implement Client struct with new!/1, new/1, and request/2 ([8c384d8](https://github.com/szTheory/lattice_stripe/commit/8c384d812ac996d4d03eec6ac0bbf8e0366e7990))
* **02-01:** add non-bang decode/1 and encode/1 to Json behaviour and Jason adapter ([1666da4](https://github.com/szTheory/lattice_stripe/commit/1666da4aaf59d4197957abf605178a11595350d0))
* **02-01:** enrich Error struct with new fields, idempotency_error, String.Chars ([33da331](https://github.com/szTheory/lattice_stripe/commit/33da331438938466e3e6f6ab7cf04b13db3386cf))
* **02-02:** implement RetryStrategy behaviour and Default implementation ([f2394e7](https://github.com/szTheory/lattice_stripe/commit/f2394e76ca9d518089290c1ced3ef670800c97ab))
* **02-02:** update Config and Client with retry_strategy field and max_retries default 2 ([f3df360](https://github.com/szTheory/lattice_stripe/commit/f3df36074f27fb11cb0b3497117420f5b2e7880c))
* **02-03:** wire retry loop, auto-idempotency, bang variant, non-JSON handling into Client ([9501f91](https://github.com/szTheory/lattice_stripe/commit/9501f91b9951f46ed150091026080669463f9152))
* **03-01:** add List struct, api_version/0, update Config/Client defaults and User-Agent ([f7b30af](https://github.com/szTheory/lattice_stripe/commit/f7b30af27416de107436457da0099d61a5078db6))
* **03-01:** add Response struct with Access behaviour, get_header/2, custom Inspect ([8a97dc8](https://github.com/szTheory/lattice_stripe/commit/8a97dc84b10b37cad84d50f3fb0630b8d3ccb759))
* **03-02:** wrap responses in %Response{} with list auto-detection ([9051f8c](https://github.com/szTheory/lattice_stripe/commit/9051f8c529dfb6a3e01c9e6b52c24e37321acf7b))
* **03-03:** implement stream!/2 and stream/2 auto-pagination on List ([dc2b01a](https://github.com/szTheory/lattice_stripe/commit/dc2b01a15cabdb1ed8ad50c02fbe8b1c156b4ef6))
* **04-01:** implement LatticeStripe.Customer resource module ([420f4a2](https://github.com/szTheory/lattice_stripe/commit/420f4a2868ccf7acb78c43d30ed870cdd21a5d5d))
* **04-02:** implement LatticeStripe.PaymentIntent resource module ([30b55c8](https://github.com/szTheory/lattice_stripe/commit/30b55c80a1f04577e23609f458a32639670af4ca))
* **05-01:** build SetupIntent resource module with full CRUD, lifecycle actions, list/stream, and tests ([7908ede](https://github.com/szTheory/lattice_stripe/commit/7908ededee79e51e98e32bfb3a1f994751d071fc))
* **05-01:** extract Resource helpers, refactor Customer/PaymentIntent, add PI search, shared test helpers ([0a85316](https://github.com/szTheory/lattice_stripe/commit/0a853162f93c4f447443f3611e1fe492e2190e00))
* **05-02:** implement PaymentMethod resource with CRUD, attach/detach, validated list, stream, and tests ([ec48dca](https://github.com/szTheory/lattice_stripe/commit/ec48dca7da388595020c48a80748a4c46f5182dd))
* **06-01:** extract Phase 4/5 test fixtures into dedicated fixture modules ([bd69567](https://github.com/szTheory/lattice_stripe/commit/bd695671dc2c6ec1cde12c955f9752295b6aba06))
* **06-01:** implement Refund resource with CRUD, cancel, list, stream, and tests ([8e4ecad](https://github.com/szTheory/lattice_stripe/commit/8e4ecad6bbd037f957a14ae1c5cc6f7661714c08))
* **06-02:** implement Checkout.Session and LineItem with all endpoints and tests ([99dbadd](https://github.com/szTheory/lattice_stripe/commit/99dbaddec03c69f3361fee3e1bd508cfc422e191))
* **07-01:** add Event struct, Handler behaviour, SignatureVerificationError, deps ([1c04f4b](https://github.com/szTheory/lattice_stripe/commit/1c04f4bbf6823aa2d448b740a131d967b11fb1a5))
* **07-01:** implement LatticeStripe.Webhook with HMAC-SHA256 verification ([b524010](https://github.com/szTheory/lattice_stripe/commit/b52401010825a803778594f77673cafd92dc6b41))
* **07-02:** add CacheBodyReader and Webhook.Plug with NimbleOptions, path matching, handler dispatch, MFA secrets ([08eed78](https://github.com/szTheory/lattice_stripe/commit/08eed78e65b7c0ef06e868638d7817d32bbb095b))
* **08-01:** create LatticeStripe.Telemetry module with event catalog and span helpers ([c8e514e](https://github.com/szTheory/lattice_stripe/commit/c8e514e51bf9876ad27416e01b673a819f73c49f))
* **08-02:** implement webhook_verify_span, attach_default_logger, integrate webhook telemetry ([63de0a4](https://github.com/szTheory/lattice_stripe/commit/63de0a489da038e56b8e3aa7802b1eb683a6912f))
* **09-01:** add 6 resource integration test files ([87cb6ab](https://github.com/szTheory/lattice_stripe/commit/87cb6abc24b9683eb1325b898da03853a10f1aae))
* **09-01:** add integration test infrastructure ([c37a9ec](https://github.com/szTheory/lattice_stripe/commit/c37a9ecc71fef9d9a389fd8b1c00a79ce288ee77))
* **09-02:** add mix ci alias, Credo strict mode, and fix all violations ([152eacc](https://github.com/szTheory/lattice_stripe/commit/152eaccb9c26be837f5d7348d391e85c3bf5c331))
* **09-02:** implement LatticeStripe.Testing public module ([60506ed](https://github.com/szTheory/lattice_stripe/commit/60506ed1fb86cc692e22e5c84ba359b3d01eb2dd))
* **10-01:** complete cheatsheet with two-column layout ([52368ea](https://github.com/szTheory/lattice_stripe/commit/52368eab0046a5b517ab0f5ff1808b95ab5ad71f))
* **10-01:** ExDoc config, README quickstart, CHANGELOG, guide stubs ([677b034](https://github.com/szTheory/lattice_stripe/commit/677b034121ae0a4d22695519f1db6f5a572036b0))
* **10-02:** add [@typedoc](https://github.com/typedoc) and Stripe API reference links to resource modules ([70ab5f4](https://github.com/szTheory/lattice_stripe/commit/70ab5f4f458ca41619cb3c1eeb2a12bff5f885df))
* **10-02:** add @moduledoc/@doc/[@typedoc](https://github.com/typedoc) to core and internal modules ([32b1917](https://github.com/szTheory/lattice_stripe/commit/32b1917f7ce7f3ec1b34eaff8f6d5cf834cec025))
* **10-03:** write checkout and webhooks guides ([3b04b13](https://github.com/szTheory/lattice_stripe/commit/3b04b131f580ef34e15a108a07e8e65601fc8737))
* **10-03:** write getting-started, client-configuration, and payments guides ([781f10e](https://github.com/szTheory/lattice_stripe/commit/781f10e6ebd64074373d8aa96b6251e70eb35da2))
* **11-02:** add Dependabot config and auto-merge workflow ([12078f6](https://github.com/szTheory/lattice_stripe/commit/12078f68eb8a4dfd106cf2fbb9ee0de7e4489e34))
* **11-02:** add Release Please workflow and manifest config ([a478928](https://github.com/szTheory/lattice_stripe/commit/a478928e4ac454efeae0f4f125fbba46744b2916))
* **11-03:** add community files — CONTRIBUTING, SECURITY, issue templates, PR template ([36d6a7a](https://github.com/szTheory/lattice_stripe/commit/36d6a7ab8fffad54db80e95785541318c84114f9))


### Bug Fixes

* **01:** resolve verification gaps — update REQUIREMENTS.md traceability and fix flaky test ([4edc9ad](https://github.com/szTheory/lattice_stripe/commit/4edc9adc7ce78fb755d109883114a8d9f185a2c6))
* **01:** revise plans based on checker feedback ([3226334](https://github.com/szTheory/lattice_stripe/commit/3226334939d90eb1084ebfb5ec17094cab2422d0))
* **03:** remove deferred requirements EXPD-02, EXPD-03, EXPD-05 from Plan 02 ([ca8372e](https://github.com/szTheory/lattice_stripe/commit/ca8372ec46d58cfd8d14e4d7e3bf2c9810583a23))
* **04:** Customer Inspect uses Inspect.Algebra to prevent PII field name leakage ([63ae62e](https://github.com/szTheory/lattice_stripe/commit/63ae62e77eb06dfdb63b356824bda2d908360d0d))
* **04:** remove unused aliases in test files ([9780bdf](https://github.com/szTheory/lattice_stripe/commit/9780bdf01c4216dafe0f39f069265ea5f26839e3))
* **09:** revise plans based on checker feedback ([9a59458](https://github.com/szTheory/lattice_stripe/commit/9a59458a11bf60799feb788d2a00fa8b7705c1d2))
* remove deprecated 'command' input from release-please-action v4 ([3ff8a12](https://github.com/szTheory/lattice_stripe/commit/3ff8a12fa3090eb69344a2c4d4ba418036cb5d7d))
* skip invalid-id integration tests — stripe-mock returns stubs for any ID ([e986f1b](https://github.com/szTheory/lattice_stripe/commit/e986f1bb67c9bf51602d108ab7d6af23a5323844))
* update GitHub org from lattice-stripe to szTheory ([ad46956](https://github.com/szTheory/lattice_stripe/commit/ad469565578f4791ba29c6bb46544750bee7018e))
