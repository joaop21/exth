defmodule Exiris.Provider do
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

  1. When `use Exiris.Provider` is called, it:
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
        use Exiris.Provider,
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

  See `Exiris.Provider.Methods` for a complete list of available RPC methods.
  """

  @required_opts [:transport_type, :rpc_url]

  @doc """
  Implements the provider behavior in the using module.

  This macro is the entry point for creating an Ethereum JSON-RPC provider.
  It validates the provided options and generates all the necessary functions
  for interacting with an Ethereum node.

  ## Options

  See the moduledoc for complete configuration options.

  ## Examples

      defmodule MyProvider do
        use Exiris.Provider,
          transport_type: :http,
          rpc_url: "https://mainnet.infura.io/v3/YOUR-PROJECT-ID"
      end
  """
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts, required_opts: @required_opts] do
      Exiris.Provider.validate_options!(opts, required_opts)
      Exiris.Provider.generate_provider(opts)
    end
  end

  @doc """
  Validates the configuration options provided to the provider.

  This macro ensures that all required options are present and have valid values.
  It raises an `ArgumentError` if any required options are missing.

  ## Parameters

    * `opts` - Keyword list of provider options
    * `required_opts` - List of required option keys

  ## Raises

    * `ArgumentError` - When required options are missing
  """
  defmacro validate_options!(opts, required_opts) do
    quote bind_quoted: [opts: opts, required_opts: required_opts] do
      missing_opts = Enum.reject(required_opts, &Keyword.has_key?(opts, &1))

      unless Enum.empty?(missing_opts) do
        raise ArgumentError, """
        Missing required options: #{inspect(missing_opts)}
        Required options: #{inspect(required_opts)}
        """
      end
    end
  end

  @doc """
  Generates the provider module with all RPC method implementations.

  This macro creates the actual provider implementation by:
    * Setting up the client cache
    * Generating functions for each RPC method
    * Implementing response handling
    * Creating helper functions

  ## Parameters

    * `opts` - Keyword list of provider options

  ## Generated Functions

  For each RPC method defined in `Exiris.Provider.Methods`, this macro generates:
    * A public function with proper type specs
    * Documentation with parameters and return values
    * Automatic parameter validation
    * Response handling and formatting
  """
  defmacro generate_provider(opts) do
    quote bind_quoted: [opts: opts] do
      alias Exiris.Rpc
      alias Exiris.Rpc.Response
      alias Exiris.Provider.ClientCache
      alias Exiris.Provider.Methods

      @type rpc_response :: {:ok, term()} | {:error, term()}

      @default_block_tag "latest"
      @provider_opts opts

      for {method_name, {rpc_method, param_types, accepts_block}} <- Methods.methods() do
        param_vars = Enum.map(param_types, &Macro.var(&1, nil))

        {function_params, request_params} =
          if accepts_block do
            block_param = Macro.var(:block_tag, nil)
            function_params = param_vars ++ [{:\\, [], [block_param, @default_block_tag]}]
            request_params = param_vars ++ [block_param]
            {function_params, request_params}
          else
            {param_vars, param_vars}
          end

        param_docs = Enum.map_join(param_types, "\n* ", &"#{&1}")

        param_docs =
          if accepts_block,
            do:
              param_docs <>
                "\n* block_tag - Block number or tag (default: \"#{@default_block_tag}\")",
            else: param_docs

        @doc """
        Executes the #{rpc_method} JSON-RPC method.

        ## Parameters
        * #{param_docs}

        ## Returns
          * `{:ok, response}` - Successful request with decoded response
          * `{:error, reason}` - Request failed with error details
        """
        @spec unquote(method_name)(
                unquote_splicing(param_types |> Enum.map(fn _ -> quote do: term() end))
              ) :: rpc_response()
        def unquote(method_name)(unquote_splicing(function_params)) do
          client = get_client()
          request = Rpc.request(client, unquote(rpc_method), [unquote_splicing(request_params)])

          client
          |> Rpc.send(request)
          |> handle_response()
        end
      end

      @doc """
      Retrieves or creates a new RPC client instance.

      This function manages the lifecycle of RPC clients by:
        * First attempting to fetch an existing client from the cache
        * Creating and caching a new client if none exists

      The client is uniquely identified by the combination of:
        * transport_type (e.g., :http)
        * rpc_url (the endpoint URL)

      ## Returns

        * `client` - A configured RPC client instance

      ## Examples

          # Automatically called by RPC methods
          client = MyProvider.get_client()

      ## Cache Behavior

      The function implements a "get or create" pattern:
        1. Attempts to fetch a cached client
        2. If no cached client exists, creates a new one
        3. New clients are automatically cached for future use

      This caching mechanism helps reduce connection overhead and
      maintain connection pooling efficiency.
      """
      def get_client() do
        transport_type = Keyword.fetch!(@provider_opts, :transport_type)
        rpc_url = Keyword.fetch!(@provider_opts, :rpc_url)

        case ClientCache.get_client(transport_type, rpc_url) do
          {:ok, client} ->
            client

          {:error, :not_found} ->
            client = Rpc.new_client(transport_type, @provider_opts)
            ClientCache.create_client(transport_type, rpc_url, client)
        end
      end

      defp handle_response({:ok, %Response.Success{} = response}), do: {:ok, response.result}
      defp handle_response({:ok, %Response.Error{} = response}), do: {:error, response.error}
      defp handle_response({:error, reason} = response) when is_binary(reason), do: response
      defp handle_response({:error, reason}), do: {:error, inspect(reason)}
    end
  end
end
