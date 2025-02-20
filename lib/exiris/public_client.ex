defmodule Exiris.PublicClient do
  @moduledoc """
  A public JSON-RPC client for interacting with an EVM-compatible node.

  This module provides a convenient way to create a client with all standard
  Ethereum JSON-RPC methods automatically available as module functions.

  ## Usage

      defmodule MyClient do
        use Exiris.PublicClient,
          transport_type: :http,
          rpc_url: "https://mainnet.infura.io/v3/YOUR-PROJECT-ID",
          opts: [timeout: 10_000] # Optional transport-specific options

      end

      # All standard RPC methods are available as functions
      {:ok, block_number} = MyClient.eth_block_number()
      {:ok, balance} = MyClient.eth_get_balance("0x123...", "latest")
      {:ok, nonce} = MyClient.eth_get_transaction_count("0x123...", "latest")

  ## Configuration Options

    * `:transport_type` - The transport to use (`:http`, `:ipc` or `:ws`)
    * `:rpc_url` - The URL of the RPC endpoint
    * `:opts` - Optional transport-specific options (see `Exiris.Transport` for details)

  ## Available Methods

  All methods defined in `Exiris.Rpc.Methods.public_methods/0` are automatically
  available as functions in your client module. Each method returns
  `{:ok, result}` on success or `{:error, reason}` on failure.

  The generated functions handle the creation of the request and its execution
  through the configured provider, making it simple to interact with the
  blockchain.
  """

  alias Exiris.Rpc

  defmacro __using__(opts) do
    methods =
      for {method, params} <- Rpc.Methods.public_methods() do
        args = Enum.map(params, &Macro.var(&1, nil))

        quote do
          @doc """
          Executes the #{unquote(method)} JSON-RPC method call.
          """
          def unquote(method)(unquote_splicing(args)) do
            request = apply(Rpc, unquote(method), [unquote_splicing(args)])
            Provider.call(@provider, request)
          end
        end
      end

    quote do
      alias Exiris.{Provider, Rpc}

      @provider Provider.new(
                  Keyword.fetch!(unquote(opts), :transport_type),
                  Keyword.fetch!(unquote(opts), :rpc_url),
                  Keyword.get(unquote(opts), :opts, [])
                )

      unquote(methods)
    end
  end
end
