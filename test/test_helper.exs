ExUnit.start()

# Transport mock for testing Client.request/2 without real HTTP
Mox.defmock(LatticeStripe.MockTransport, for: LatticeStripe.Transport)
# JSON codec mock for testing codec swapping
Mox.defmock(LatticeStripe.MockJson, for: LatticeStripe.Json)
