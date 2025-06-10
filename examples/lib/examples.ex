defmodule Examples do
  @moduledoc false

  require Logger

  alias Examples.Provider
  alias Exth.Rpc
  alias Exth.Rpc.Response.SubscriptionEvent

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
        client |> Rpc.request("eth_blockNumber", []) |> Rpc.send()

      {:ok, %Rpc.Response.Success{result: balance}} =
        client |> Rpc.request("eth_getBalance", [address, block_number]) |> Rpc.send()

      Logger.info("#{provider} Client: block_number: #{block_number}")
      Logger.info("#{provider} Client: get_balance: #{balance}")
    end)
  end

  def subscribe_to_new_blocks do
    {:ok, response} =
      Provider.WsEthereum.get_client()
      |> Rpc.request("eth_subscribe", ["newHeads"])
      |> Rpc.send()

    Logger.info("Subscribed to new blocks: #{response.result}")

    receive_loop(response.result)
  end

  defp receive_loop(subscription_id) do
    receive do
      %SubscriptionEvent{params: %{subscription: ^subscription_id, result: result}} ->
        Logger.info("New block received")
        Logger.info("Parent Block Hash: #{result["parentHash"]}")
        Logger.info("Block Hash: #{result["hash"]}")

      event ->
        Logger.info("Unknown event received: #{inspect(event)}")
    end

    receive_loop(subscription_id)
  end
end
