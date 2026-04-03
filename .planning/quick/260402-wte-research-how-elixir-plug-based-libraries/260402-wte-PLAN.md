---
quick_id: 260402-wte
description: Research how Elixir Plug-based libraries handle path matching and mounting strategies
date: 2026-04-03
status: ready
---

# Quick Task 260402-wte: Research — Elixir Plug Path Matching & Mounting Strategies

## Goal

Produce a concrete reference document (RESEARCH.md) covering how real Elixir/Phoenix libraries
handle path matching for Plug-based middleware. Covers stripity_stripe WebhookPlug, Plug.Router
forward/2, Phoenix Router forward/4, Plug.Static, LiveDashboard, Absinthe.Plug, and the two
primary mounting strategies (endpoint.ex vs router.ex).

## Tasks

### Task 1: Research and write RESEARCH.md

**Action:** Use WebSearch + WebFetch to gather concrete source code and docs for each topic in
the brief. Write findings to 260402-wte-RESEARCH.md in the quick task directory.

**Topics to cover:**
1. stripity_stripe WebhookPlug — `at:` option, `init/1` and `call/2` path matching impl
2. Plug.Router `forward/2` — what happens to conn.path_info when forwarded
3. Phoenix Router `forward/4` and `scope` + `post` — conn shape when plug receives forwarded request
4. Other libraries: Plug.Static `at:`, LiveDashboard Router mounting, Absinthe.Plug (no path opts)
5. Endpoint.ex vs router.ex mounting — raw body access tradeoffs, when to choose each
6. Phoenix endpoint.ex conventions for raw-body plugs

**Files:** `.planning/quick/260402-wte-research-how-elixir-plug-based-libraries/260402-wte-RESEARCH.md`

**Verify:** RESEARCH.md exists with concrete code examples and tradeoff analysis

**Done:** RESEARCH.md written and committed
