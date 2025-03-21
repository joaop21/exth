defmodule Exiris.Provider do
  @moduledoc """
  Provides a macro for generating Ethereum JSON-RPC client methods with built-in client caching.

  This module automatically generates functions for common Ethereum JSON-RPC methods,
  handling the client lifecycle, request formatting, and response parsing.

  ## Features

    * Automatic client caching and reuse
    * Standard Ethereum JSON-RPC method implementations
    * Consistent error handling

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

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts, required_opts: @required_opts] do
      Exiris.Provider.validate_options!(opts, required_opts)
      Exiris.Provider.generate_provider(opts)
    end
  end

  @doc false
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

      defp get_client() do
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
