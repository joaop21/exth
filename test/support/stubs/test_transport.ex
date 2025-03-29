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

  def call(_transport, %{method: method, id: id} = _request) do
    case Map.get(Exth.TestTransport.get_known_methods(), method) do
      nil -> {:ok, Exth.Rpc.Response.error(id, -32_601, "Method not found")}
      result -> {:ok, Exth.Rpc.Response.success(id, result)}
    end
  end

  def call(transport, requests) do
    requests
    |> Enum.map(&call(transport, &1))
    |> Enum.map(fn {:ok, response} -> response end)
    |> then(fn response -> {:ok, response} end)
  end
end
