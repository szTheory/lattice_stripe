# Plan 49-01 Summary

**Status:** Complete  
**Completed:** 2026-05-27

## What shipped

- `LatticeStripe.Tax.CustomerDetails`, `ShippingCost`, `ShipFromDetails`, `TaxBreakdown` nested decoders
- `LatticeStripe.Tax.Calculation` with `create/3`, `retrieve/3`, `list_line_items/4` and bang variants
- `LatticeStripe.Tax.Calculation.LineItem` with product expand via ObjectTypes
- ObjectTypes registration for `tax.calculation` and `tax.calculation_line_item`
- Fixtures and unit tests covering CALC-01..03

## Self-Check: PASSED

- `mix compile --warnings-as-errors` — pass
- `mix test test/lattice_stripe/tax/calculation_test.exs test/lattice_stripe/object_types_test.exs` — pass

## key-files.created

- lib/lattice_stripe/tax/calculation.ex
- lib/lattice_stripe/tax/calculation/line_item.ex
- test/lattice_stripe/tax/calculation_test.exs
- test/support/fixtures/tax_calculation.ex
