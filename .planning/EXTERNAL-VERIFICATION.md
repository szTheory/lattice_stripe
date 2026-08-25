# External verification ledger

This ledger records boundaries that repository automation cannot honestly turn
into stronger claims. An accepted boundary is not a passing live-service test.

**Last audited:** 2026-08-25 20:04 UTC

| ID | Boundary | Disposition | Evidence and consequence |
|----|----------|-------------|--------------------------|
| EXT-01 | Quote downstream follow-through in a real Stripe sandbox (historical Phase 41.1) | accepted and retired | Retired as `accepted-external-verification` in v1.7 Phase 55. `scripts/verify_quote_follow_through.exs` remains optional operator tooling, not an active milestone or release gate. |
| EXT-02 | Stripe v2 billing meter-event stream against stripe-mock | accepted current limitation | stripe-mock v0.202.0 does not implement the v2 endpoints. `meter_event_stream_integration_test.exs` carries the repository's one documented skip, while `meter_event_stream_test.exs` proves request construction through Mox. This does not claim a live Stripe sandbox result. |
| EXT-03 | 2.2.0 public release surfaces | verified and closed | GitHub Release, tag, remote `main`, green CI/release runs, Hex, and HexDocs identify commit `984fa7cd76b338322d5856e1dc7d4a57ff84d19f`; links live in `RELEASE-TRAIN.md`. |
| EXT-04 | 2.2.1 public release surfaces | pending | Remains open until GitHub Release, tag, remote `main`, Hex, HexDocs, and successful CI/release runs all identify the exact future 2.2.1 SHA. |

## Active probe policy

- There are no other active manual probes carried from earlier milestones.
- Do not revive an archived probe merely to create activity. Add one only when a
  new Stripe wire-format claim lacks published provenance or stripe-mock proof.
- Never convert an unavailable live sandbox into a passing result. Record it as
  accepted, pending, or blocked with the exact boundary.
- Phase 73 must re-audit this ledger after the final change and before claiming
  CLOSE-01 or CLOSE-03.
