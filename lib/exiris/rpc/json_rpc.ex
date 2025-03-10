defmodule Exiris.Rpc.JsonRpc do
  @type id :: pos_integer()
  @type jsonrpc :: String.t()
  @type method :: String.t()
  @type params :: list(binary())

  @jsonrpc_version "2.0"

  @spec jsonrpc_version() :: jsonrpc()
  def jsonrpc_version(), do: @jsonrpc_version
end
