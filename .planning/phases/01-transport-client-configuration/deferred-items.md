# Deferred Items - Phase 01

## Out-of-scope Credo Issues (from Plan 03)

These pre-existing Credo warnings in `lib/lattice_stripe/form_encoder.ex` are from
Plan 01-03 (form encoder) and were not caused by Plan 01-05 changes. They are
deferred to avoid scope creep.

### Issue 1: Enum.map/2 |> Enum.join/2 can be Enum.map_join/3
- **File:** `lib/lattice_stripe/form_encoder.ex:46`
- **Function:** `LatticeStripe.FormEncoder.encode/0`
- **Credo check:** `Credo.Check.Refactor.MapJoin`

### Issue 2: Enum.map/2 |> Enum.join/2 can be Enum.map_join/3
- **File:** `lib/lattice_stripe/form_encoder.ex:106`
- **Function:** `LatticeStripe.FormEncoder.encode_key/0`
- **Credo check:** `Credo.Check.Refactor.MapJoin`

**Recommended fix:** Replace in a future cleanup or when revisiting Plan 03.
