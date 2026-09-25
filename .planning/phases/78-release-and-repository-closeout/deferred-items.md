# Deferred Items

- Existing skipped integration spec at `test/lattice_stripe/billing/meter_event_stream_integration_test.exs:4` remains outside this release-evidence task. Stripe Mock lacks the Stripe v2 billing endpoint; the request shape is covered by Mox. Tracked as skipped-test entry 2 in `.planning/WINDOWS.md`.
