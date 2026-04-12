# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/).

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

## [Unreleased]

### Added

- Initial release of LatticeStripe
- Core: Client configuration, transport behaviour, JSON codec, form encoding
- Resources: Customer, PaymentIntent, SetupIntent, PaymentMethod, Refund, Checkout.Session
- Webhook signature verification with Phoenix Plug integration
- Auto-pagination via Elixir Streams
- Automatic retry with exponential backoff and idempotency keys
- Telemetry events for request lifecycle monitoring
- Test helpers for webhook event construction
