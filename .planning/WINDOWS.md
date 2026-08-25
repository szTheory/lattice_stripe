---
schema_version: 1
open_count: 1
waived_count: 0
fixed_count: 0
total_count: 1
last_updated: 2026-08-25T14:29:17.069Z
---

# Broken Windows Ledger

> Cross-phase defect register. `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 66 | deviation | test/lattice_stripe/product/feature_stream_test.exs | 34 | Corrected the test's expand query assertion to the repository's indexed expand[0] encoding. | open |  | 2026-08-25T14:29:17.069Z |  |

````json
[
  {
    "id": 1,
    "kind": "deviation",
    "phase": "66",
    "file": "test/lattice_stripe/product/feature_stream_test.exs",
    "line": 34,
    "description": "Corrected the test's expand query assertion to the repository's indexed expand[0] encoding.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-25T14:29:17.069Z",
    "resolved_at": null
  }
]
````
