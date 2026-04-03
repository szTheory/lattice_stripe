# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/).

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
