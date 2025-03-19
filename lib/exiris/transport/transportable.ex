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

  alias Exiris.Rpc.Request
  alias Exiris.Rpc.Response

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

  Supports both single requests and batch requests (arrays of requests).

  ## Parameters
    * `transport` - The configured transport struct
    * `request` - Single request or list of requests (Request.t() | [Request.t()])

  ## Returns
    * `{:ok, response}` - Successful request with decoded response (Response.t())
    * `{:ok, responses}` - Successful batch request with decoded responses ([Response.t()])
    * `{:error, reason}` - Request failed with error reason (Exception.t() or map())

  ## Examples

      # Single request
      {:ok, response} = Transportable.call(transport, %Request{
        jsonrpc: "2.0",
        method: "eth_blockNumber",
        params: [],
        id: 1
      })

      # Batch request
      {:ok, responses} = Transportable.call(transport, [
        %Request{method: "eth_blockNumber", params: [], id: 1},
        %Request{method: "eth_getBalance", params: ["0x123...", "latest"], id: 2}
      ])
  """
  @spec call(t, Request.t() | [Request.t()]) ::
          {:ok, Response.t() | [Response.t()]} | {:error, Exception.t()}
  def call(transport, request)
end
