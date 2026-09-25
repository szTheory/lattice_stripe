---
schema_version: 1
open_count: 1
waived_count: 0
fixed_count: 1
total_count: 2
last_updated: 2026-09-25T00:03:37.442Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 66 | deviation | test/lattice_stripe/product/feature_stream_test.exs | 34 | Corrected the test's expand query assertion to the repository's indexed expand[0] encoding. | fixed | The committed assertion matches FormEncoder's established indexed-list contract and is covered by the passing stream test. | 2026-08-25T14:29:17.069Z | 2026-08-25T20:04:00.000Z |
| 2 | 78 | skipped-test | test/lattice_stripe/billing/meter_event_stream_integration_test.exs | 4 | Existing stripe-mock-incompatible meter-event stream integration spec remains skipped; Mox covers request shape. | open |  | 2026-09-25T00:03:37.442Z |  |

````json
[
  {
    "id": 1,
    "kind": "deviation",
    "phase": "66",
    "file": "test/lattice_stripe/product/feature_stream_test.exs",
    "line": 34,
    "description": "Corrected the test's expand query assertion to the repository's indexed expand[0] encoding.",
    "status": "fixed",
    "reason": "The committed assertion matches FormEncoder's established indexed-list contract and is covered by the passing stream test.",
    "recorded_at": "2026-08-25T14:29:17.069Z",
    "resolved_at": "2026-08-25T20:04:00.000Z"
  },
  {
    "id": 2,
    "kind": "skipped-test",
    "phase": "78",
    "file": "test/lattice_stripe/billing/meter_event_stream_integration_test.exs",
    "line": 4,
    "description": "Existing stripe-mock-incompatible meter-event stream integration spec remains skipped; Mox covers request shape.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-25T00:03:37.442Z",
    "resolved_at": null,
    "milestone": "v1.12"
  }
]
````
