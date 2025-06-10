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
    * Dynamic configuration through both inline options and application config

  ## Architecture

  The Provider module works as follows:

  1. When `use Exth.Provider` is called, it:
     * Validates the required configuration options
     * Merges inline options with application config (inline takes precedence)
     * Generates a set of standardized RPC method functions
     * Sets up client caching mechanisms

  2. For each RPC call:
     * Reuses cached clients when possible
     * Automatically formats parameters
     * Handles request/response lifecycle
     * Provides consistent error handling

  ## Usage

  ### Basic Usage

  ```elixir
  defmodule MyProvider do
    use Exth.Provider,
      transport_type: :http,
      rpc_url: "https://my-eth-node.com"
  end

  # Then use the generated functions
  {:ok, balance} = MyProvider.eth_getBalance("0x742d35Cc6634C0532925a3b844Bc454e4438f44e")
  {:ok, block} = MyProvider.eth_getBlockByNumber(12345)
  ```

  ### Dynamic Configuration

  You can configure providers through both inline options and application config.
  Inline options take precedence over application config.

  ```elixir
  # In your config/config.exs or similar:
  config :my_app, MyProvider,
    rpc_url: "https://config-rpc-url",
    timeout: 30_000

  # In your provider module:
  defmodule MyProvider do
    use Exth.Provider,
      otp_app: :my_app,
      transport_type: :http,
      rpc_url: "https://override-rpc-url" # This will override the config value
  end
  ```

  ## Configuration Options

  ### Required Options

    * `:transport_type` - The transport type to use (`:http` or `:custom`)
    * `:rpc_url` - The URL of the Ethereum JSON-RPC endpoint
    * `:otp_app` - The application name for config lookup (required when using application config)

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

  ```elixir
  # Get balance for specific block
  {:ok, balance} = MyProvider.eth_getBalance(
    "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
    "0x1b4"
  )

  # Get latest block
  {:ok, block} = MyProvider.eth_getBlockByNumber("latest", true)

  # Send raw transaction
  {:ok, tx_hash} = MyProvider.eth_sendRawTransaction("0x...")
  ```

  See `Exth.Provider.Methods` for a complete list of available RPC methods.
  """

  alias Exth.Provider
  alias Exth.Provider.ClientCache
  alias Exth.Provider.Methods
  alias Exth.Rpc
  alias Exth.Rpc.Response

  @doc """
  Implements the provider behavior in the using module.

  This macro is the entry point for creating an Ethereum JSON-RPC provider.
  It validates the provided options and generates all the necessary functions
  for interacting with an Ethereum node.

  ## Options

  See the moduledoc for complete configuration options.

  ## Examples

  ```elixir
  defmodule MyProvider do
    use Exth.Provider,
      transport_type: :http,
      rpc_url: "https://mainnet.infura.io/v3/YOUR-PROJECT-ID"
  end
  ```
  """
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      alias Exth.Provider

      require Provider

      Provider.generate_provider(opts)
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

  For each RPC method defined in `Exth.Provider.Methods`, this macro generates:
    * A public function with proper type specs
    * Documentation with parameters and return values
    * Automatic parameter validation
    * Response handling and formatting
  """
  defmacro generate_provider(opts) do
    quote bind_quoted: [opts: opts] do
      @type rpc_response :: {:ok, term()} | {:error, term()}

      @default_block_tag "latest"
      @provider_app Keyword.get(opts, :otp_app)
      @provider_key __MODULE__
      @provider_inline_opts opts

      for {method_name, {rpc_method, param_types, accepts_block}} <- Methods.methods() do
        Provider.generate_rpc_method(
          method_name,
          rpc_method,
          param_types,
          accepts_block
        )
      end

      for {method_name, {rpc_method, param_types}} <- Methods.subscription_methods() do
        Provider.generate_subscription_rpc_method(
          method_name,
          rpc_method,
          param_types
        )
      end

      Provider.generate_get_client()
      Provider.generate_handle_response()
    end
  end

  defmacro generate_rpc_method(method_name, rpc_method, param_types, accepts_block) do
    quote bind_quoted: [
            method_name: method_name,
            rpc_method: rpc_method,
            param_types: param_types,
            accepts_block: accepts_block
          ] do
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
        get_client()
        |> Rpc.request(unquote(rpc_method), [unquote_splicing(request_params)])
        |> Rpc.send()
        |> handle_response()
      end
    end
  end

  defmacro generate_subscription_rpc_method(method_name, rpc_method, param_types) do
    quote bind_quoted: [
            method_name: method_name,
            rpc_method: rpc_method,
            param_types: param_types
          ] do
      param_vars = Enum.map(param_types, &Macro.var(&1, nil))
      param_docs = Enum.map_join(param_types, "\n* ", &"#{&1}")

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
      def unquote(method_name)(unquote_splicing(param_vars)) do
        get_client()
        |> Rpc.request(unquote(rpc_method), [unquote_splicing(param_vars)])
        |> Rpc.send()
        |> handle_response()
      end
    end
  end

  defmacro generate_get_client do
    quote do
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
      @spec get_client() :: Rpc.Client.t()
      def get_client do
        app_config = Application.get_env(@provider_app, @provider_key, [])
        config = Keyword.merge(app_config, @provider_inline_opts)

        transport_type = Keyword.fetch!(config, :transport_type)
        rpc_url = Keyword.fetch!(config, :rpc_url)

        case ClientCache.get_client(transport_type, rpc_url) do
          {:ok, client} ->
            client

          {:error, :not_found} ->
            client = Rpc.new_client(transport_type, config)
            ClientCache.create_client(transport_type, rpc_url, client)
        end
      end
    end
  end

  defmacro generate_handle_response do
    quote do
      @spec handle_response(Rpc.Client.send_response_type()) ::
              {:ok, term()} | {:error, term()}
      defp handle_response({:ok, %Response.Success{} = response}), do: {:ok, response.result}
      defp handle_response({:ok, %Response.Error{} = response}), do: {:error, response.error}
      defp handle_response({:error, reason}), do: {:error, inspect(reason)}
    end
  end
end
