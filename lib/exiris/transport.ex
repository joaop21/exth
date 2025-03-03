defmodule Exiris.Transport do
  @moduledoc """
  Manages transport configurations and implementations for JSON-RPC communication.

  The Transport module serves as a factory and coordinator for different transport
  implementations (HTTP, WebSocket, IPC). It provides:

  * A consistent interface for building transport configurations
  * Type definitions for transport implementations
  * Factory functions for creating transport instances
  * Delegation of requests to specific transport implementations

  ## Transport Types

  Currently supported transport types:

  * `:http` - HTTP/HTTPS transport using `Exiris.Transport.Http`
  * `:custom` - Custom transport implementation provided via `:module` option

  ## Configuration

  Transport configuration includes:

  * `:rpc_url` - (Required) The endpoint URL for the transport
  * `:encoder` - Function to encode Request structs to JSON string
  * `:decoder` - Function to decode JSON string to Response structs
  * `:type` - Type of transport (`:http` or `:custom`)
  * `:module` - (Required for `:custom`) The module implementing the transport
  * `:opts` - Transport-specific options passed to the implementation

  ## Examples

      # Create an HTTP transport
      transport = Transport.new(:http,
        rpc_url: "https://eth-mainnet.example.com",
        encoder: &JSON.encode/1,
        decoder: &JSON.decode/1
      )

      # Create a custom transport
      transport = Transport.new(:custom,
        module: MyCustomTransport,
        rpc_url: "custom://endpoint",
        opts: [custom_option: "value"]
      )

      # Make a request using the transport
      Transport.request(transport, request_body)

  ## Custom Transports

  To implement a custom transport:

  1. Create a module that implements the `Exiris.Transport.Behaviour`
  2. Implement the required callbacks:
     * `build_opts/1` - Build transport-specific options
     * `request/2` - Handle the actual request/response cycle

  Example:

      defmodule MyCustomTransport do
        @behaviour Exiris.Transport.Behaviour

        def build_opts(opts) do
          # Transform raw options into transport config
          %{custom_config: opts}
        end

        def request(transport, body) do
          # Implement request handling
          {:ok, response}
        end
      end

  ## Error Handling

  The module will raise `ArgumentError` when:
  * Required `:rpc_url` option is missing
  * Invalid transport type is specified
  * `:module` option is missing for custom transports

  Runtime errors are handled by specific transport implementations.
  """

  alias Exiris.Rpc.Request
  alias Exiris.Rpc.Response
  alias __MODULE__.Http

  @type type :: :custom | :http
  @type encoder :: (Request.t() -> String.t())
  @type decoder :: (String.t() -> Response.t())

  @type t :: %__MODULE__{
          decoder: encoder(),
          encoder: decoder(),
          module: __MODULE__.Behaviour.t() | nil,
          opts: Http.opts() | map(),
          rpc_url: String.t(),
          type: type()
        }

  defstruct [
    :rpc_url,
    :encoder,
    :decoder,
    :module,
    :opts,
    :type
  ]

  ### 
  ### Public Functions
  ###

  @behaviour __MODULE__.Behaviour

  @impl true
  def build_opts(opts) do
    rpc_url = opts[:rpc_url] || raise ArgumentError, "missing required option :rpc_url"
    encoder = opts[:encoder]
    decoder = opts[:decoder]
    type = opts[:type]

    module =
      case type do
        :http -> Exiris.Transport.Http
        :custom -> opts[:module] || raise ArgumentError, "missing required option :module"
        _ -> raise(ArgumentError, "invalid transport type: #{inspect(type)}")
      end

    # transport specific options
    transport_opts = module.build_opts(opts[:opts] || [])

    %__MODULE__{
      rpc_url: rpc_url,
      encoder: encoder,
      decoder: decoder,
      opts: transport_opts,
      type: type,
      module: module
    }
  end

  @impl true
  def request(%__MODULE__{} = transport, body) do
    transport.module.request(transport, body)
  end

  @spec new(type(), keyword()) :: __MODULE__.t()
  def new(type, opts \\ []) do
    opts = Keyword.merge(opts, type: type)
    build_opts(opts)
  end
end
