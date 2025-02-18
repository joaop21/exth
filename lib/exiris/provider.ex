defmodule Exiris.Provider do
  @moduledoc """
  Provider for executing JSON-RPC requests to EVM nodes through different transport types.

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

      # Execute requests
      {:ok, block_number} = provider
                           |> Provider.request(Provider.eth_block_number())

      {:ok, balance} = provider
                      |> Provider.request(Provider.eth_get_balance("0x...", "latest"))

  ## Transport Types

  The provider supports different transport types through the `Exiris.Transport` module:

    * `:http` - HTTP/HTTPS connections (default)
    * `:ipc` - Unix domain socket connections
    * `:ws` - WebSocket connections (coming soon)

  Each transport type may accept specific options that can be passed when creating
  the provider. See `Exiris.Transport` for details on available options.
  """

  alias Exiris.Rpc
  alias Exiris.Rpc.Request
  alias Exiris.Rpc.Response
  alias Exiris.Transport

  defstruct [:transport, :transport_type, :rpc_url, :opts]

  @type t :: %__MODULE__{
          transport: module(),
          transport_type: Transport.type(),
          rpc_url: String.t(),
          opts: keyword()
        }

  @spec new(Transport.type(), String.t(), keyword()) :: t()
  def new(transport_type, rpc_url, opts \\ []) do
    %__MODULE__{
      transport: Transport.get_by_type!(transport_type),
      transport_type: transport_type,
      rpc_url: rpc_url,
      opts: opts
    }
  end

  @spec request(t(), Request.t()) :: {:ok, binary()} | {:error, any()}
  def request(%__MODULE__{transport: transport, rpc_url: rpc_url, opts: opts}, request) do
    with {:ok, %Response{} = response} <- transport.request(request, [rpc_url: rpc_url] ++ opts) do
      {:ok, response.result}
    end
  end

  for {method, params} <- Rpc.Methods.public_methods() do
    args = Enum.map(params, &Macro.var(&1, __MODULE__))

    defdelegate unquote(method)(unquote_splicing(args)), to: Rpc
  end
end
