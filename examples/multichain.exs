Mix.install([{:exth, path: "../"}, :mint])

# Be cautious when running this example. The RPC URLs are public and may be
# rate-limited or unstable.

defmodule MyProvider do
  defmodule Eth do
    use Exth.Provider,
      transport_type: :http,
      rpc_url: "https://eth.llamarpc.com"
  end

  defmodule Polygon do
    use Exth.Provider,
      transport_type: :http,
      rpc_url: "https://polygon.llamarpc.com"
  end
end

require Logger

vitalik_address = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"

Enum.each([MyProvider.Eth, MyProvider.Polygon], fn provider ->
  {:ok, block_number} = provider.block_number()
  {:ok, balance} = provider.get_balance(vitalik_address, block_number)
  Logger.info("#{provider}: block_number: #{block_number}")
  Logger.info("#{provider}: get_balance: #{balance}")
end)

# Using RPC client directly
client = MyProvider.Eth.get_client()

{:ok, response} =
  Exth.Rpc.request("eth_blockNumber", [])
  |> Exth.Rpc.send(client)

Logger.info("RPC: eth_blockNumber: #{inspect(response)}")
