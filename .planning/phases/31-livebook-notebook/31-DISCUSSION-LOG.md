# Phase 31: LiveBook Notebook - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-16
**Phase:** 31-livebook-notebook
**Areas discussed:** Notebook structure, Stripe connectivity, Interactive elements, Exercise coverage
**Mode:** --auto (all decisions auto-selected as recommended defaults)

---

## Notebook Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Single notebook | One `stripe_explorer.livemd` file with progressive sections | ✓ |
| Multiple notebooks | Separate notebooks per topic area (payments.livemd, billing.livemd, etc.) | |

**User's choice:** Single notebook (auto-selected — DX-05 names one file)
**Notes:** Matches success criteria. Single progressive experience is better for guided exploration.

| Option | Description | Selected |
|--------|-------------|----------|
| ExDoc nine-group order | Client → Payments → Billing → Connect → Webhooks | ✓ |
| Complexity-based order | Simple operations first, complex last | |
| Use-case order | Common flows first (checkout, subscriptions) | |

**User's choice:** ExDoc nine-group order (auto-selected — consistent with existing docs)
**Notes:** Developers will see the same grouping on HexDocs.

---

## Stripe Connectivity

| Option | Description | Selected |
|--------|-------------|----------|
| stripe-mock primary | Docker-based, no real API keys needed, document test key alternative | ✓ |
| Real test key primary | Require Stripe test key, document stripe-mock as alternative | |
| Both equally | Present both options without preference | |

**User's choice:** stripe-mock primary (auto-selected — matches project testing philosophy)
**Notes:** Zero-config for most users. Real key documented as alternative.

| Option | Description | Selected |
|--------|-------------|----------|
| Kino.Input with defaults | Text inputs for API key + base URL, pre-filled for stripe-mock | ✓ |
| Hardcoded stripe-mock | No input widgets, hardcode stripe-mock URL | |
| Environment variable | Read from env, document how to set | |

**User's choice:** Kino.Input with defaults (auto-selected — interactive but zero-config)
**Notes:** Best of both: works out of box with stripe-mock, configurable for real keys.

---

## Interactive Elements

| Option | Description | Selected |
|--------|-------------|----------|
| Kino widgets (Input + DataTable + Tree) | Input for config, DataTable for lists, Tree for nested structs | ✓ |
| Minimal (Input only) | Just Kino.Input for API key, raw output everywhere else | |
| Rich (+ Markdown + Charts) | Full Kino suite including Markdown rendering and charts | |

**User's choice:** Kino widgets — Input + DataTable + Tree (auto-selected — practical without over-engineering)
**Notes:** Enough interactivity to be useful without adding complexity.

| Option | Description | Selected |
|--------|-------------|----------|
| Raw struct + Kino.Tree | Simple returns shown raw, nested structs via Tree | ✓ |
| All Kino.Tree | Every response through Tree widget | |
| All raw | No widgets for output, just IO.inspect | |

**User's choice:** Raw struct + Kino.Tree hybrid (auto-selected)
**Notes:** Shows developers the real SDK return types while making nested structs navigable.

---

## Exercise Coverage

| Option | Description | Selected |
|--------|-------------|----------|
| Golden path + one advanced flow | create → retrieve → list per resource, plus one highlight operation | ✓ |
| Minimal (create only) | Just create operations to show the API | |
| Comprehensive (all verbs) | Every operation for every resource | |

**User's choice:** Golden path + one advanced flow (auto-selected — enough to demonstrate without overwhelming)
**Notes:** Balances exploration depth with notebook length.

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated v1.2 highlight sections | Expand deser, Batch, Builders, MeterEventStream each get their own section | ✓ |
| Inline v1.2 features | Weave v1.2 features into existing resource sections | |
| Appendix | v1.2 features in a separate "Advanced" appendix | |

**User's choice:** Dedicated v1.2 highlight sections (auto-selected — makes new features discoverable)
**Notes:** Developers specifically looking for v1.2 features can find them easily.

---

## Claude's Discretion

- Prose tone and density between sections
- Exact Kino widget per response type
- Whether to include resource cleanup section
- Sub-ordering within groups

## Deferred Ideas

None.
