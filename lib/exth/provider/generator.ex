defmodule Exth.Provider.Generator do
  @moduledoc false

  alias Exth.Provider
  alias Exth.Provider.ClientCache
  alias Exth.Provider.Methods
  alias Exth.Rpc
  alias Exth.Rpc.Response

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
      @provider_opts opts

      for {method_name, {rpc_method, param_types, accepts_block}} <- Methods.methods() do
        Provider.Generator.generate_rpc_method(
          method_name,
          rpc_method,
          param_types,
          accepts_block
        )
      end

      Provider.Generator.generate_get_client()
      Provider.Generator.generate_handle_response()
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
        client = get_client()

        unquote(rpc_method)
        |> Rpc.request([unquote_splicing(request_params)])
        |> Rpc.send(client)
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
    end
  end

  defmacro generate_handle_response do
    quote do
      defp handle_response({:ok, %Response.Success{} = response}), do: {:ok, response.result}
      defp handle_response({:ok, %Response.Error{} = response}), do: {:error, response.error}
      defp handle_response({:error, reason} = response) when is_binary(reason), do: response
      defp handle_response({:error, reason}), do: {:error, inspect(reason)}
    end
  end
end
