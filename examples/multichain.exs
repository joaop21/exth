Mix.install([{:exth, path: "../"}, :mint])

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
request = Exth.Rpc.request(client, "eth_blockNumber", [])
{:ok, response} = Exth.Rpc.send(client, request)
Logger.info("RPC: eth_blockNumber: #{inspect(response)}")
