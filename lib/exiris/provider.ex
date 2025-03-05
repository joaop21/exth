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

  alias Exiris.Rpc
  alias Exiris.Rpc.Request
  alias Exiris.Rpc.Response
  alias Exiris.Transport

  defstruct [:transport, :opts]

  @type t :: %__MODULE__{
          transport: Transport.t(),
          opts: keyword()
        }

  @spec new(Transport.type(), String.t(), keyword()) :: t()
  def new(transport_type, rpc_url, opts \\ []) do
    transport_opts =
      Keyword.merge(opts,
        rpc_url: rpc_url,
        encoder: &Rpc.Encoding.encode_request/1,
        decoder: &Rpc.Encoding.decode_response/1
      )

    %__MODULE__{
      transport: Transport.new(transport_type, transport_opts),
      opts: opts
    }
  end

  @doc """
  Executes a JSON-RPC method call through the provider's transport.

  Only requests for methods defined in `Rpc.Methods.public_methods/0` are allowed.
  Attempting to call undefined methods will return an error.
  """
  @spec call(t(), Request.t()) :: {:ok, binary()} | {:error, any()}
  def call(%__MODULE__{} = provider, %Request{} = request) do
    if request.method in public_methods_names() do
      do_call(provider, request)
    else
      {:error, :method_not_found}
    end
  end

  defp do_call(%__MODULE__{} = provider, request) do
    case Transport.request(provider.transport, request) do
      {:ok, %Response{} = response} when not is_nil(response.result) ->
        {:ok, response.result}

      {:ok, %Response{} = response} ->
        {:error, response.error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  ###
  ### Private Functions
  ###

  @spec public_methods_names() :: [String.t()]
  defp public_methods_names() do
    Rpc.Methods.public_methods()
    |> Map.merge(Rpc.Methods.public_methods_for_block_number())
    |> Enum.map(fn {method, _params} -> to_string(method) end)
  end
end
