defmodule Exiris.Rpc.Methods do
  @moduledoc """
  Defines the available Ethereum JSON-RPC methods and their parameters.
  """

  @public_methods %{
    web3_clientVersion: [],
    web3_sha3: [:data],
    net_version: [],
    net_listening: [],
    net_peerCount: [],
    eth_protocolVersion: [],
    eth_syncing: [],
    eth_coinbase: [],
    eth_chainId: [],
    eth_mining: [],
    eth_hashrate: [],
    eth_gasPrice: [],
    eth_accounts: [],
    eth_blockNumber: [],
    eth_getBlockTransactionCountByHash: [:block_hash],
    eth_getBlockTransactionCountByNumber: [:block_number],
    eth_getUncleCountByBlockHash: [:block_hash],
    eth_getUncleCountByBlockNumber: [:block_number],
    eth_estimateGas: [:transaction],
    eth_getBlockByHash: [:block_hash, :full_transactions],
    eth_getBlockByNumber: [:block_number, :full_transactions],
    eth_getTransactionByHash: [:transaction_hash],
    eth_getTransactionByBlockHashAndIndex: [:block_hash, :transaction_index],
    eth_getTransactionByBlockNumberAndIndex: [:block_number, :transaction_index],
    eth_getTransactionReceipt: [:transaction_hash],
    eth_getUncleByBlockHashAndIndex: [:block_hash, :uncle_index],
    eth_getUncleByBlockNumberAndIndex: [:block_number, :uncle_index],
    eth_newFilter: [:filter],
    eth_newBlockFilter: [],
    eth_newPendingTransactionFilter: [],
    eth_uninstallFilter: [:filter_id],
    eth_getFilterChanges: [:filter_id],
    eth_getFilterLogs: [:filter_id],
    eth_getLogs: [:filter]
  }

  @default_block_number_public_methods %{
    eth_getBalance: [:address],
    eth_getStorageAt: [:address, :position],
    eth_getTransactionCount: [:address],
    eth_getCode: [:address],
    eth_call: [:transaction]
  }

  @doc """
  Returns a map of all supported public RPC methods and their parameters.
  """
  @spec public_methods() :: %{atom() => list(atom())}
  def public_methods, do: @public_methods

  @doc """
  Returns a map of all supported public RPC methods with a default block number.
  """
  @spec public_methods_for_block_number() :: %{atom() => list(atom())}
  def public_methods_for_block_number, do: @default_block_number_public_methods

  def default_block_number_public_methods,
    do: @default_block_number_public_methods
end
