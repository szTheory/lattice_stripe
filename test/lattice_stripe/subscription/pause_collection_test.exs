defmodule LatticeStripe.Subscription.PauseCollectionTest do
  use ExUnit.Case, async: true

  alias LatticeStripe.Subscription.PauseCollection

  describe "from_map/1" do
    test "returns nil when given nil" do
      assert PauseCollection.from_map(nil) == nil
    end

    test "decodes known fields" do
      pc =
        PauseCollection.from_map(%{
          "behavior" => "keep_as_draft",
          "resumes_at" => 1_730_000_000
        })

      assert pc.behavior == "keep_as_draft"
      assert pc.resumes_at == 1_730_000_000
      assert pc.extra == %{}
    end

    test "collects unknown fields into :extra" do
      pc =
        PauseCollection.from_map(%{
          "behavior" => "void",
          "future_field" => "hello"
        })

      assert pc.behavior == "void"
      assert pc.extra == %{"future_field" => "hello"}
    end
  end

  describe "Inspect" do
    test "renders a compact #LatticeStripe.Subscription.PauseCollection<...> line" do
      pc =
        PauseCollection.from_map(%{"behavior" => "keep_as_draft", "resumes_at" => 1_730_000_000})

      inspected = inspect(pc)

      assert inspected =~ "#LatticeStripe.Subscription.PauseCollection<"
      assert inspected =~ "behavior:"
      assert inspected =~ "keep_as_draft"
      assert inspected =~ "resumes_at:"
    end
  end
end
