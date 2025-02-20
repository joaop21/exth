defmodule Exiris.Rpc.Methods do
  @moduledoc """
  Defines the available Ethereum JSON-RPC methods and their parameters.
  """

  @public_methods %{
    eth_blockNumber: [],
    eth_getBlockByNumber: [:block_number, :full_transactions],
    eth_getBlockByHash: [:block_hash, :full_transactions]
  }

  @doc """
  Returns a map of all supported public RPC methods and their parameters.
  """
  @spec public_methods() :: %{atom() => list(atom())}
  def public_methods, do: @public_methods
end
