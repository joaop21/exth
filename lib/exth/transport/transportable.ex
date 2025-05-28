defprotocol Exth.Transport.Transportable do
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

  @type error_reason :: Exception.t() | String.t() | term()
  @type call_response :: :ok | {:ok, String.t()} | {:error, error_reason()}

  @doc """
  Makes a request using the configured transport.

  ## Parameters
    * `transport` - The configured transport struct
    * `request` - Encoded JSON-RPC request

  ## Returns
    * `{:ok, response}` - Successful request with encoded response
    * `{:error, reason}` - Request failed with error reason (Exception.t() or map())
  """
  @spec call(t, String.t()) :: call_response()
  def call(transport, request)
end
