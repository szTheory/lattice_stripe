defmodule LatticeStripe.CardTest do
  use ExUnit.Case, async: true

  import LatticeStripe.Test.Fixtures.Card

  alias LatticeStripe.Card

  describe "cast/1" do
    test "maps all known fields from a Stripe card map" do
      card = Card.cast(basic())

      assert %Card{} = card
      assert card.id == "card_1OoKqrJ2eZvKYlo2C9hXqGtR"
      assert card.object == "card"
      assert card.account == "acct_1OoKpqJ2eZvKYlo2"
      assert card.brand == "Visa"
      assert card.country == "US"
      assert card.currency == "usd"
      assert card.exp_month == 12
      assert card.exp_year == 2030
      assert card.fingerprint == "fp_card_abcdef1234567890"
      assert card.funding == "debit"
      assert card.last4 == "4242"
      assert card.metadata == %{}
      assert card.name == "Jane Doe"
      assert card.extra == %{}
    end

    test "nil returns nil" do
      assert Card.cast(nil) == nil
    end

    test "preserves unknown fields in :extra (F-001)" do
      card = Card.cast(basic(%{"future_field" => "x"}))

      assert card.extra == %{"future_field" => "x"}
    end

    test "preserves the deleted=true flag from a DELETE response in :extra" do
      card = Card.cast(deleted())

      assert card.id == "card_1OoKqrJ2eZvKYlo2C9hXqGtR"
      assert card.object == "card"
      assert card.extra == %{"deleted" => true}
    end

    test "from_map/1 is an alias for cast/1" do
      assert Card.from_map(basic()) == Card.cast(basic())
    end
  end

  describe "Inspect (PII hide-list)" do
    test "inspect output contains id, object, brand, country, funding" do
      card = Card.cast(basic())
      out = inspect(card)

      assert out =~ "LatticeStripe.Card"
      assert out =~ "card_1OoKqrJ2eZvKYlo2C9hXqGtR"
      assert out =~ "Visa"
      assert out =~ "US"
      assert out =~ "debit"
    end

    test "inspect output does NOT contain last4, fingerprint, exp_month, exp_year, name" do
      card = Card.cast(basic())
      out = inspect(card)

      refute out =~ "4242"
      refute out =~ "fp_card_abcdef1234567890"
      refute out =~ "Jane Doe"
      # exp_year
      refute out =~ "2030"
      # exp_month is 12 — checking it's not a standalone field. Use a keyword-ish match.
      refute out =~ "exp_month"
      refute out =~ "exp_year"
      refute out =~ "last4"
      refute out =~ "fingerprint"
    end
  end
end
