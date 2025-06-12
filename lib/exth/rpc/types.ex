defmodule Exth.Rpc.Types do
  @moduledoc """
  Common types used across the RPC modules.
  """

  @type id :: pos_integer()
  @type jsonrpc :: String.t()
  @type method :: String.t()
  @type params :: list(term())

  @jsonrpc_version "2.0"

  @doc """
  Returns the JSON-RPC protocol version used.
  """
  def jsonrpc_version, do: @jsonrpc_version
end
