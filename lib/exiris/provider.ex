defmodule Exiris.Provider do
  @moduledoc """
  Provider for executing JSON-RPC method calls to EVM nodes through different transport types.

  A provider encapsulates:
    * The transport type (`:http`, `:ipc`, etc.)
    * The RPC endpoint URL
    * Transport-specific options

  ## Examples

      # Create an HTTP provider for Infura
      provider = Provider.new(
        :http,
        "https://mainnet.infura.io/v3/YOUR-PROJECT-ID"
      )

      # Create a local IPC provider
      provider = Provider.new(
        :ipc,
        "/path/to/geth.ipc"
      )

      # Execute method calls
      {:ok, block_number} = provider
                           |> Provider.call(Rpc.eth_block_number())

      {:ok, balance} = provider
                      |> Provider.call(Rpc.eth_get_balance("0x...", "latest"))

  ## Transport Types

  The provider supports different transport types through the `Exiris.Transport` module:

    * `:http` - HTTP/HTTPS connections (default)
    * `:ipc` - Unix domain socket connections (coming soon)
    * `:ws` - WebSocket connections (coming soon)

  Each transport type may accept specific options that can be passed when creating
  the provider. See `Exiris.Transport` for details on available options.
  """

  # alias Exiris.Rpc
  # alias Exiris.Rpc.Request
  # alias Exiris.Rpc.Response
  # alias Exiris.Transport
  # alias Exiris.Transport.Transportable
  #
  # defstruct [:transport, :opts]
  #
  # @type t :: %__MODULE__{
  #         transport: Transportable.t(),
  #         opts: keyword()
  #       }
  #
  # @default_block_tag "latest"
  #
  # @spec new(Transport.type(), String.t(), keyword()) :: t()
  # def new(transport_type, rpc_url, opts \\ []) do
  #   transport_opts =
  #     Keyword.merge(opts,
  #       rpc_url: rpc_url,
  #       encoder: &Rpc.Encoding.encode_request/1,
  #       decoder: &Rpc.Encoding.decode_response/1
  #     )
  #
  #   %__MODULE__{
  #     transport: Transport.new(transport_type, transport_opts),
  #     opts: opts
  #   }
  # end
  #
  # for {method_name, {rpc_method, param_types, accepts_block}} <- Rpc.methods() do
  #   param_vars = Enum.map(param_types, &Macro.var(&1, __MODULE__))
  #   method_params = Enum.map_join(param_types, ", ", &":#{&1}")
  #
  #   {function_params, request_params} =
  #     if accepts_block do
  #       block_param = Macro.var(:block_tag, __MODULE__)
  #       function_params = param_vars ++ [{:\\, [], [block_param, @default_block_tag]}]
  #       request_params = param_vars ++ [block_param]
  #       {function_params, request_params}
  #     else
  #       {param_vars, param_vars}
  #     end
  #
  #   @doc """
  #   Generates a JSON-RPC request for the #{rpc_method} method.
  #
  #   #{if length(param_vars) > 0, do: "Parameters: #{method_params}#{if accepts_block, do: ~S(, :block_tag \\\\ ) <> @default_block_tag}", else: ""}
  #   """
  #   @spec unquote(method_name)(
  #           unquote_splicing(List.duplicate({:term, [], []}, length(function_params)))
  #         ) ::
  #           Request.t()
  #   def unquote(method_name)(unquote_splicing(function_params)) do
  #     Rpc.build_request(to_string(unquote(rpc_method)), [unquote_splicing(request_params)])
  #   end
  # end
  #
  # @doc """
  # Executes a JSON-RPC method request through the provider's transport.
  # """
  # def request(%__MODULE__{} = provider, %Request{} = request) do
  #   case Transport.call(provider.transport, request) do
  #     {:ok, %Response.Success{} = response} ->
  #       {:ok, response.result}
  #
  #     {:ok, %Response.Error{} = response} ->
  #       {:error, response.error}
  #
  #     {:error, reason} ->
  #       {:error, reason}
  #   end
  # end
end
