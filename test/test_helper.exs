ExUnit.start()
ExUnit.configure(exclude: [:integration, :real_stripe])

# Transport mock for testing Client.request/2 without real HTTP
Mox.defmock(LatticeStripe.MockTransport, for: LatticeStripe.Transport)
# JSON codec mock for testing codec swapping
Mox.defmock(LatticeStripe.MockJson, for: LatticeStripe.Json)
# RetryStrategy mock for testing retry loop without real delays
Mox.defmock(LatticeStripe.MockRetryStrategy, for: LatticeStripe.RetryStrategy)
