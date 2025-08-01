defmodule Exth.Transport do
  @moduledoc """
  Factory module for creating JSON-RPC transport implementations.

  This module provides a unified interface for creating and managing different transport
  mechanisms (HTTP, WebSocket, IPC) for JSON-RPC communication with EVM nodes.

  ## Features

    * Pluggable transport system via the `Transportable` protocol
    * Built-in HTTP transport with Tesla/Mint
    * Built-in WebSocket transport with Fresh
    * Consistent interface across transport types
    * Configurable timeout and retry mechanisms
    * Transport-specific option handling

  ## Transport Types

  Currently supported:
    * `:http` - HTTP/HTTPS transport using Tesla with Mint adapter
    * `:websocket` - WebSocket transport using Fresh
    * `:custom` - Custom transport implementations

  Coming soon:
    * `:ws` - WebSocket transport
    * `:ipc` - Unix domain socket transport

  ## Usage

      # Create an HTTP transport
      transport = Transport.new(:http,
        rpc_url: "https://mainnet.infura.io/v3/YOUR-PROJECT-ID",
        timeout: 30_000,
        headers: [{"authorization", "Bearer token"}]
      )

      # Create a WebSocket transport
      transport = Transport.new(:websocket,
        rpc_url: "wss://mainnet.infura.io/ws/v3/YOUR-PROJECT-ID",
        dispatch_callback: fn response -> handle_response(response) end
      )

      # Make requests
      {:ok, response} = Transport.call(transport, request)

  ## Configuration

  HTTP-specific options:

    * `:rpc_url` - The endpoint URL
    * `:headers` - Additional HTTP headers
    * `:timeout` - Request timeout in milliseconds (default: 30000)
    * `:adapter` - Tesla adapter to use (default: Tesla.Adapter.Mint)

  WebSocket-specific options:

    * `:rpc_url` - The endpoint URL
    * `:dispatch_callback` - Callback function to handle incoming messages
    * `:module` - Optional custom WebSocket implementation

  ## Custom Transport Implementation

  To implement a custom transport:

  1. Define your transport struct:

         defmodule MyTransport do
           defstruct [:config]
         end

  2. Implement the `Transportable` protocol:

         defimpl Exth.Transport.Transportable, for: MyTransport do
           def new(_transport, opts) do
             %MyTransport{config: opts}
           end

           def call(transport, request) do
             # Implement request handling
             {:ok, response}
           end
         end

  3. Use your transport:

         transport = Transport.new(:custom,
           module: MyTransport,
           rpc_url: "custom://endpoint",
           # other options...
         )

  ## Error Handling

  The module uses consistent error handling:

    * `{:ok, response}` - Successful request with response
    * `{:ok, responses}` - Successful batch request with responses
    * `{:error, reason}` - Request failed with detailed reason

  HTTP-specific errors:
    * `{:error, {:http_error, status}}` - HTTP error response
    * `{:error, :timeout}` - Request timeout
    * `{:error, :network_error}` - Network connectivity issues

  WebSocket-specific errors:
    * `{:error, :connection_failed}` - Failed to establish WebSocket connection
    * `{:error, :invalid_url}` - Invalid WebSocket URL format
    * `{:error, :missing_callback}` - Missing dispatch callback

  ## Best Practices

    * Use appropriate timeouts for your use case
    * Implement retry logic for transient failures
    * Handle batch requests efficiently
    * Monitor transport health and metrics
    * Properly handle connection pooling
    * Use secure transport options in production
    * Use WebSocket transport for subscriptions and real-time updates
    * Implement proper error handling in WebSocket dispatch callbacks

  ## Supervision Tree

  The transport subdomain uses a hierarchical supervision tree to manage connections and state:

  <pre class="mermaid">
    flowchart TD
      A["Exth.Supervisor :one_for_one"] --> B["Exth.Transport.Supervisor :one_for_one"]
      B --> C["Exth.Transport.Registry"]
      B --> D["Exth.Transport.Websocket.DynamicSupervisor :one_for_one"]
      C -.registers.- E["Exth.Transport.Websocket"]
      D --> E

      E@{ shape: procs}
  </pre>

  ### Supervision Strategy

  * **Exth.Supervisor**: Application-level supervisor using `:one_for_one` strategy
  * **Exth.Transport.Supervisor**: Transport-level supervisor using `:one_for_one` strategy
  * **Exth.Transport.Websocket.DynamicSupervisor**: Dynamic supervisor for WebSocket connections using `:one_for_one` strategy

  ### Components

  * **Exth.Transport.Registry**: Manages named processes for WebSocket connections
  * **Exth.Transport.Websocket.DynamicSupervisor**: Dynamically starts and supervises individual WebSocket connections
  * **WebSocket Connections**: Individual Fresh WebSocket processes managed by the dynamic supervisor

  This supervision structure ensures:
    * Fault isolation between different transport types
    * Automatic restart of failed WebSocket connections
    * Proper cleanup of resources
    * Scalable connection management

  See `Exth.Transport.Transportable` for protocol details and
  `Exth.Transport.Http` for HTTP transport specifics.
  """

  alias __MODULE__.Transportable

  @typedoc """
  Supported transport types:
  * `:http` - HTTP/HTTPS transport
  * `:websocket` - Websocket transport
  * `:custom` - Custom transport implementation
  """
  @type type :: :custom | :http | :websocket

  @typedoc """
  Transport configuration options.
  """
  @type options :: [
          rpc_url: String.t(),
          module: module() | nil
        ]

  @doc """
  Creates a new transport struct with the given type and options.

  ## Parameters
    * `type` - The type of transport to create (`:http`, `:websocket` or `:custom`)
    * `opts` - Configuration options for the transport

  ## Returns
    * A configured transport struct implementing the `Transportable` protocol

  ## Raises
    * `ArgumentError` if required options are missing or type is invalid
  """
  @spec new(type(), options()) :: Transportable.t()
  def new(type, opts) do
    module = get_transport_module(type, opts)
    transport = struct(module, %{})

    Transportable.new(transport, opts)
  end

  defp get_transport_module(:custom, opts) do
    opts[:module] || raise ArgumentError, "missing required option :module"
  end

  defp get_transport_module(type, opts) do
    case {type, opts[:module]} do
      {:http, nil} -> __MODULE__.Http
      {:ipc, nil} -> __MODULE__.Ipc
      {:websocket, nil} -> __MODULE__.Websocket
      {_, module} when not is_nil(module) -> module
      _ -> raise ArgumentError, "invalid transport type: #{inspect(type)}"
    end
  end

  @type call_response :: Transportable.call_response()

  @doc """
  Makes a request using the configured transport.

  ## Parameters
    * `transportable` - The configured transport instance
    * `request` - The JSON-RPC encoded request to send

  ## Returns
    * `{:ok, response}` - Successful request with encoded response
    * `{:error, reason}` - Request failed with error reason
  """
  @spec call(Transportable.t(), String.t()) :: call_response()
  def call(transportable, encoded_request), do: Transportable.call(transportable, encoded_request)
end
