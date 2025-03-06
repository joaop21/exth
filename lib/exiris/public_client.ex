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

      # Using predefined method functions
      {:ok, block_number} = MyClient.eth_block_number()
      {:ok, balance} = MyClient.eth_get_balance("0x123...", "latest")
      {:ok, nonce} = MyClient.eth_get_transaction_count("0x123...", "latest")

      # Using call/1 directly with a request
      request = Rpc.eth_block_number()
      {:ok, block_number} = MyClient.call(request)

  ## Configuration Options

    * `:transport_type` - The transport to use (`:http`, `:ipc` or `:ws`)
    * `:rpc_url` - The URL of the RPC endpoint
    * `:opts` - Optional transport-specific options (see `Exiris.Transport` for details)

  ## Available Methods

  This module provides two ways to make RPC calls:

  1. Predefined method functions:
     All methods defined in `Exiris.Rpc.Methods.public_methods/0` are automatically
     available as functions in your client module. These functions handle both the
     request creation and execution.

  2. Direct call:
     The `call/1` function allows you to execute pre-built requests. This is useful
     when you want to prepare requests in advance or reuse them.

  Both approaches only allow calls to methods defined in `public_methods/0` and will
  return `{:ok, result}` on success or `{:error, reason}` on failure.

  ## Security

  The client enforces that only officially supported RPC methods can be called,
  preventing potential security issues with undefined or unsafe methods. Any attempt
  to call undefined methods will result in `{:error, :method_not_found}`.
  """

  # alias Exiris.Rpc
  #
  # defmacro __using__(opts) do
  #   public_methods =
  #     for {method, params} <- Rpc.Methods.public_methods() do
  #       args = Enum.map(params, &Macro.var(&1, nil))
  #
  #       quote do
  #         @doc """
  #         Executes the #{unquote(method)} JSON-RPC method call.
  #         """
  #         def unquote(method)(unquote_splicing(args)) do
  #           request = apply(Rpc, unquote(method), [unquote_splicing(args)])
  #           Provider.call(@provider, request)
  #         end
  #       end
  #     end
  #
  #   default_block_number_public_methods =
  #     for {method, params} <- Rpc.Methods.public_methods_for_block_number() do
  #       args = Enum.map(params, &Macro.var(&1, nil))
  #
  #       quote do
  #         @doc """
  #         Executes the #{unquote(method)} JSON-RPC method call.
  #         """
  #         def unquote(method)(unquote_splicing(args), tag \\ "latest") do
  #           request = apply(Rpc, unquote(method), [unquote_splicing(args), tag])
  #           Provider.call(@provider, request)
  #         end
  #       end
  #     end
  #
  #   quote do
  #     alias Exiris.{Provider, Rpc}
  #
  #     @provider Provider.new(
  #                 Keyword.fetch!(unquote(opts), :transport_type),
  #                 Keyword.fetch!(unquote(opts), :rpc_url),
  #                 Keyword.get(unquote(opts), :opts, [])
  #               )
  #
  #     @doc """
  #     Executes a JSON-RPC method call through the provider's transport.
  #
  #     Only requests for methods defined in `Rpc.Methods.public_methods/0` are allowed.
  #     Attempting to call undefined methods will return an error.
  #     """
  #     def call(request), do: Provider.call(@provider, request)
  #
  #     unquote(public_methods)
  #     unquote(default_block_number_public_methods)
  #   end
  # end
end
