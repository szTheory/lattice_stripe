# Deferred Items — Phase 61

Out-of-scope discoveries found during execution. Not fixed (not caused by this plan's changes).

## Pre-existing `mix docs --warnings-as-errors` failures (42 warnings)

- **Found during:** Plan 01, `mix ci` gate (SC-5 verification).
- **Status:** Pre-existing. Verified by running `mix docs --warnings-as-errors` against the pre-phase baseline commit `0ca2688` in a throwaway worktree — identical count of **42 warnings**. This plan's changes are warning-neutral (none of the 42 reference `application.ex`, `config.ex`, or `client.ex`).
- **Nature:** Hidden-module type references (`LatticeStripe.Tax.*`, `LatticeStripe.TaxId.*`), references to hidden functions (`LatticeStripe.ObjectTypes.fetch_module/1`, `LatticeStripe.BillingPortal.Guards.check_flow_data!/1`, `LatticeStripe.Webhook.check_tolerance/2`), missing extras files (`../README.md`, `../notebooks/stripe_explorer.livemd`), `File.create/3` undefined refs, and IAL/attribute markdown warnings.
- **Action:** Not fixed — out of scope for Phase 61 (DX-01, default Finch pool). `mix docs --warnings-as-errors` was already red before this phase; fixing the wider doc-reference debt is a separate concern.
