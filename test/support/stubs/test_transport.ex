defmodule Exth.TestTransport do
  @moduledoc false

  defstruct [:config]

  @known_methods %{
    "eth_blockNumber" => "0x10",
    "eth_chainId" => "0x1",
    "eth_gasPrice" => "0x1",
    "eth_getBalance" => "0x1000",
    "net_version" => "1"
  }

  def get_known_methods, do: @known_methods
end

defimpl Exth.Transport.Transportable, for: Exth.TestTransport do
  def new(_transport, opts), do: %Exth.TestTransport{config: opts}

  def call(transport, encoded_request) do
    decoded_request = JSON.decode!(encoded_request)
    do_call(transport, decoded_request)
  end

  defp do_call(_transport, %{"method" => method, "id" => id} = _request) do
    case Map.get(Exth.TestTransport.get_known_methods(), method) do
      nil -> {:ok, JSON.encode!(%{id: id, error: %{code: -32_601, message: "Method not found"}})}
      result -> {:ok, JSON.encode!(%{id: id, result: result})}
    end
  end

  defp do_call(transport, requests) do
    requests
    |> Enum.map(&do_call(transport, &1))
    |> Enum.map_join(",", fn {:ok, response} -> response end)
    |> then(fn response -> {:ok, "[#{response}]"} end)
  end
end
