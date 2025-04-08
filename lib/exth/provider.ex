defmodule Exth.Provider do
  @moduledoc """
  Provides a macro for generating Ethereum JSON-RPC client methods with built-in client caching.

  This module automatically generates functions for common Ethereum JSON-RPC methods,
  handling the client lifecycle, request formatting, and response parsing.

  ## Features

    * Automatic client caching and reuse
    * Standard Ethereum JSON-RPC method implementations
    * Type-safe function signatures
    * Consistent error handling
    * Automatic request ID management
    * Connection pooling and reuse
    * Configurable transport layer

  ## Architecture

  The Provider module works as follows:

  1. When `use Exth.Provider` is called, it:
     * Validates the required configuration options
     * Generates a set of standardized RPC method functions
     * Sets up client caching mechanisms

  2. For each RPC call:
     * Reuses cached clients when possible
     * Automatically formats parameters
     * Handles request/response lifecycle
     * Provides consistent error handling

  ## Usage

      defmodule MyProvider do
        use Exth.Provider,
          transport_type: :http,
          rpc_url: "https://my-eth-node.com"
      end

      # Then use the generated functions
      {:ok, balance} = MyProvider.eth_getBalance("0x742d35Cc6634C0532925a3b844Bc454e4438f44e")
      {:ok, block} = MyProvider.eth_getBlockByNumber(12345)

  ## Configuration Options

  Required:
    * `:transport_type` - The transport type to use (currently only `:http` is supported)
    * `:rpc_url` - The URL of the Ethereum JSON-RPC endpoint

  ## Generated Functions

  All generated functions follow these conventions:

    * Return `{:ok, result}` for successful calls
    * Return `{:error, reason}` for failures
    * Accept an optional `block_tag` parameter (defaults to "latest") where applicable

  ## Error Handling

  Possible error responses:
    * `{:error, %{code: code, message: msg}}` - RPC method error
    * `{:error, reason}` - Other errors with description

  ## Examples

      # Get balance for specific block
      {:ok, balance} = MyProvider.eth_getBalance(
        "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
        "0x1b4"
      )

      # Get latest block
      {:ok, block} = MyProvider.eth_getBlockByNumber("latest", true)

      # Send raw transaction
      {:ok, tx_hash} = MyProvider.eth_sendRawTransaction("0x...")

  See `Exth.Provider.Methods` for a complete list of available RPC methods.
  """

  @doc """
  Implements the provider behavior in the using module.

  This macro is the entry point for creating an Ethereum JSON-RPC provider.
  It validates the provided options and generates all the necessary functions
  for interacting with an Ethereum node.

  ## Options

  See the moduledoc for complete configuration options.

  ## Examples

      defmodule MyProvider do
        use Exth.Provider,
          transport_type: :http,
          rpc_url: "https://mainnet.infura.io/v3/YOUR-PROJECT-ID"
      end
  """
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      alias Exth.Provider

      require Provider.Generator

      Provider.Generator.generate_provider(opts)
    end
  end
end
