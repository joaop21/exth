defmodule Exth.Provider.Methods do
  @moduledoc """
  Defines the available Ethereum JSON-RPC methods and their parameters.

  This module maintains a comprehensive mapping of supported Ethereum JSON-RPC methods,
  their parameter requirements, and whether they accept a default block parameter.

  ## Method Structure

  Each method is defined as a tuple with three elements:
    * RPC method name (atom)
    * List of required parameters (list of atoms)
    * Boolean indicating if method accepts a block parameter (boolean)

  ## Method Categories

  Methods are organized into the following namespaces:

  ### Web3 Namespace
    * Basic web3 operations (clientVersion, sha3)

  ### Net Namespace
    * Network status and information
    * Peer connections
    * Network version

  ### Eth Namespace
    * Basic chain information
    * Block operations
    * Transaction operations
    * Account operations
    * Filter management
    * Contract interaction

  ## Parameter Types

  Common parameter types include:
    * `:address` - 20-byte Ethereum address (hex string)
    * `:block_hash` - 32-byte block hash (hex string)
    * `:block_number` - Block number or tag ("latest", "earliest", "pending")
    * `:transaction_hash` - 32-byte transaction hash (hex string)
    * `:data` - Arbitrary hex data
    * `:filter` - Filter options object
    * `:transaction` - Transaction object
    * `:position` - Storage position (hex string)

  ## Usage

  This module is primarily used internally by the Provider module to:
    * Generate method implementations
    * Validate method parameters
    * Handle default block parameters

  To get the complete list of available methods:

      iex> Exth.Provider.Methods.methods()
      %{
        client_version: {:web3_clientVersion, [], false},
        # ... other methods
      }
  """

  @rpc_methods %{
    # Web3 namespace
    client_version: {:web3_clientVersion, [], false},
    sha3: {:web3_sha3, [:data], false},

    # Net namespace
    net_version: {:net_version, [], false},
    net_listening?: {:net_listening, [], false},
    peer_count: {:net_peerCount, [], false},

    # Eth namespace - Basic info
    protocol_version: {:eth_protocolVersion, [], false},
    syncing?: {:eth_syncing, [], false},
    coinbase: {:eth_coinbase, [], false},
    chain_id: {:eth_chainId, [], false},
    mining?: {:eth_mining, [], false},
    hashrate: {:eth_hashrate, [], false},
    gas_price: {:eth_gasPrice, [], false},
    accounts: {:eth_accounts, [], false},
    block_number: {:eth_blockNumber, [], false},

    # Eth namespace - Block related
    get_block_transaction_count_by_hash:
      {:eth_getBlockTransactionCountByHash, [:block_hash], false},
    get_block_transaction_count_by_number:
      {:eth_getBlockTransactionCountByNumber, [:block_number], false},
    get_uncle_count_by_block_hash: {:eth_getUncleCountByBlockHash, [:block_hash], false},
    get_uncle_count_by_block_number: {:eth_getUncleCountByBlockNumber, [:block_number], false},
    get_block_by_hash: {:eth_getBlockByHash, [:block_hash, :full_transactions], false},
    get_block_by_number: {:eth_getBlockByNumber, [:block_number, :full_transactions], false},

    # Eth namespace - Transaction queries
    estimate_gas: {:eth_estimateGas, [:transaction], false},
    get_transaction_by_hash: {:eth_getTransactionByHash, [:transaction_hash], false},
    get_transaction_by_block_hash_and_index:
      {:eth_getTransactionByBlockHashAndIndex, [:block_hash, :transaction_index], false},
    get_transaction_by_block_number_and_index:
      {:eth_getTransactionByBlockNumberAndIndex, [:block_number, :transaction_index], false},
    get_transaction_receipt: {:eth_getTransactionReceipt, [:transaction_hash], false},

    # Eth namespace - Transaction signing and sending
    sign: {:eth_sign, [:address, :data], false},
    sign_transaction: {:eth_signTransaction, [:transaction], false},
    send_transaction: {:eth_sendTransaction, [:transaction], false},
    send_raw_transaction: {:eth_sendRawTransaction, [:data], false},

    # Eth namespace - Uncle related
    get_uncle_by_block_hash_and_index:
      {:eth_getUncleByBlockHashAndIndex, [:block_hash, :uncle_index], false},
    get_uncle_by_block_number_and_index:
      {:eth_getUncleByBlockNumberAndIndex, [:block_number, :uncle_index], false},

    # Eth namespace - Filter related
    new_filter: {:eth_newFilter, [:filter], false},
    new_block_filter: {:eth_newBlockFilter, [], false},
    new_pending_transaction_filter: {:eth_newPendingTransactionFilter, [], false},
    uninstall_filter: {:eth_uninstallFilter, [:filter_id], false},
    get_filter_changes: {:eth_getFilterChanges, [:filter_id], false},
    get_filter_logs: {:eth_getFilterLogs, [:filter_id], false},
    get_logs: {:eth_getLogs, [:filter], false},

    # Methods that accept a default block number
    get_balance: {:eth_getBalance, [:address], true},
    get_storage_at: {:eth_getStorageAt, [:address, :position], true},
    get_transaction_count: {:eth_getTransactionCount, [:address], true},
    get_code: {:eth_getCode, [:address], true},
    call: {:eth_call, [:transaction], true}
  }

  @doc """
  Returns a map of all supported Ethereum JSON-RPC methods.

  Each method entry contains:
    * Key: The friendly method name used in the generated functions
    * Value: A tuple of {rpc_method_name, parameter_list, accepts_block_param}

  ## Returns

    * Map of method definitions

  ## Examples

      iex> Exth.Provider.Methods.methods()
      %{
        client_version: {:web3_clientVersion, [], false},
        get_balance: {:eth_getBalance, [:address], true},
        # ... other methods
      }
  """
  @spec methods() :: %{atom() => {atom(), list(atom()), boolean()}}
  def methods, do: @rpc_methods
end
