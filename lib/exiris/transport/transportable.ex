defprotocol Exiris.Transport.Transportable do
  @moduledoc """
  Protocol defining the interface for JSON-RPC transport implementations.

  This protocol enables different transport mechanisms (HTTP, WebSocket, IPC, etc.)
  to be used interchangeably for making JSON-RPC requests.

  ## Implementing the Protocol

  To implement a new transport, you need to define both `new/2` and `call/2`:

      defimpl Transportable, for: MyTransport do
        def new(transport, opts) do
          # Initialize your transport with the given options
        end

        def call(transport, request) do
          # Make the RPC request and return the response
        end
      end

  ## Example Usage

      # Create a new transport instance
      transport = Transportable.new(
        %MyTransport{},
        rpc_url: "https://example.com/rpc",
      )

      # Make an RPC request
      {:ok, response} = Transportable.call(transport, request)
  """

  alias Exiris.Rpc.JsonRpc.Request
  alias Exiris.Rpc.JsonRpc.Response

  @doc """
  Creates a new transport instance with the given options.

  ## Parameters
    * `transport` - The transport struct to initialize
    * `opts` - Keyword list of options specific to the transport implementation

  ## Returns
    * The initialized transport struct

  ## Example
      transport = Transportable.new(
        %MyTransport{},
        rpc_url: "https://example.com/rpc",
      )
  """
  @spec new(t, keyword()) :: t
  def new(transport, opts)

  @doc """
  Makes a request using the configured transport.

  ## Parameters
    * `transport` - The configured transport struct
    * `request` - The request to send (format depends on transport implementation)

  ## Returns
    * `{:ok, response}` - Successful request with decoded response
    * `{:error, reason}` - Request failed with error reason

  ## Example
      {:ok, response} = Transportable.call(transport, %{
        jsonrpc: "2.0",
        method: "eth_blockNumber",
        params: [],
        id: 1
      })
  """
  @spec call(t, Request.t()) :: {:ok, Response.t()} | {:error, Exception.t()}
  def call(transport, request)
end
