defmodule Exth.TestTransport do
  @moduledoc false
  # Test transport implementation for transport tests
  defstruct [:config]

  @known_methods %{
    "eth_blockNumber" => "0x10",
    "eth_chainId" => "0x1",
    "net_version" => "1"
  }

  def get_known_methods, do: @known_methods
end

defimpl Exth.Transport.Transportable, for: Exth.TestTransport do
  def new(_transport, opts), do: %Exth.TestTransport{config: opts}

  def call(_transport, %{method: method, id: id} = _request) do
    case Map.get(Exth.TestTransport.get_known_methods(), method) do
      nil -> {:ok, Exth.Rpc.Response.error(id, -32601, "Method not found")}
      result -> {:ok, Exth.Rpc.Response.success(id, result)}
    end
  end
end
