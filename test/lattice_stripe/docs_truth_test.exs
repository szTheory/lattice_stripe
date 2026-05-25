defmodule LatticeStripe.DocsTruthTest do
  use ExUnit.Case, async: true

  test "exdoc extras include recipes guide" do
    extras = LatticeStripe.MixProject.project()[:docs][:extras]

    assert "guides/recipes.md" in extras
  end

  test "readme points users to recipes and the published 1.2 line" do
    readme = File.read!("README.md")

    assert readme =~ "recipes.html"
    assert readme =~ "{:lattice_stripe, \"~> 1.2\"}"
    refute readme =~ "What's new in v1.1"
  end
end
