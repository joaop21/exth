defmodule Exth.TestHelpers do
  @doc """
  Generates a random RPC URL for testing purposes.
  """
  def generate_rpc_url do
    "https://#{for _ <- 1..10, into: "", do: <<Enum.random(~c(0123456789abcdef))>>}"
  end
end
