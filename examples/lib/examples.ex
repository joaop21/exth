defmodule Examples do
  @moduledoc false

  require Logger

  alias Examples.Provider
  alias Exth.Rpc

  @vitalik_address "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"

  def run(address \\ @vitalik_address) do
    Enum.each([Provider.Ethereum, Provider.Polygon], fn provider ->
      {:ok, block_number} = provider.block_number()
      {:ok, balance} = provider.get_balance(address, block_number)
      Logger.info("#{provider}: block_number: #{block_number}")
      Logger.info("#{provider}: get_balance: #{balance}")
    end)
  end

  def run_with_clients(address \\ @vitalik_address) do
    [Provider.Ethereum, Provider.Polygon]
    |> Enum.map(fn provider -> {provider, provider.get_client()} end)
    |> Enum.each(fn {provider, client} ->
      {:ok, %Rpc.Response.Success{result: block_number}} =
        Rpc.request("eth_blockNumber", []) |> Rpc.send(client)

      {:ok, %Rpc.Response.Success{result: balance}} =
        Rpc.request("eth_getBalance", [address, block_number]) |> Rpc.send(client)

      Logger.info("#{provider} Client: block_number: #{block_number}")
      Logger.info("#{provider} Client: get_balance: #{balance}")
    end)
  end
end
