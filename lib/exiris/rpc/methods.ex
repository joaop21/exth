defmodule Exiris.Rpc.Methods do
  @public_methods %{
    eth_blockNumber: [],
    eth_getBlockByNumber: [:block_number, :full_transactions],
    eth_getBlockByHash: [:block_hash, :full_transactions]
  }

  def public_methods, do: @public_methods
end
