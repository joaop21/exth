defmodule Exth.Transport do
  @moduledoc """
  Core transport abstraction for JSON-RPC communication with EVM-compatible blockchain nodes.

  This module provides a unified interface for different transport mechanisms (HTTP, WebSocket, IPC)
  and custom implementations, allowing seamless switching between transport layers while maintaining
  consistent behavior.

  ## Features

    * Multiple transport types: HTTP, WebSocket, IPC, and custom implementations
    * Unified transport interface with adapter pattern
    * Automatic transport initialization and lifecycle management
    * Consistent request/response handling across all transport types
    * Behaviour-based implementation for custom transports

  ## Transport Types

  The module supports the following built-in transport types:

    * `:http` - Standard HTTP/HTTPS transport for RESTful JSON-RPC calls
    * `:websocket` - WebSocket transport for real-time communication and subscriptions
    * `:ipc` - Inter-Process Communication transport for local node connections
    * `:custom` - Custom transport implementations for specialized use cases

  ## Quick Start

      # Create an HTTP transport
      {:ok, transport} = Transport.new(:http, rpc_url: "https://eth-mainnet.example.com")

      # Make a request
      {:ok, response} = Transport.request(transport, ~s({"jsonrpc": "2.0", "method": "eth_blockNumber", "params": [], "id": 1}))

      # Create a WebSocket transport
      {:ok, ws_transport} = Transport.new(:websocket, rpc_url: "wss://eth-mainnet.example.com")

      # Create a custom transport
      {:ok, custom_transport} = Transport.new(:custom, module: MyCustomTransport)

  ## Custom Transport Implementation

  To implement a custom transport, use the `__using__` macro:

      defmodule MyCustomTransport do
        use Exth.Transport

        @impl Exth.Transport
        def init(opts) do
          # Initialize your transport
          {:ok, transport_state}
        end

        @impl Exth.Transport
        def handle_request(transport, request) do
          # Handle the JSON-RPC request
          {:ok, response}
        end
      end

  ## Architecture

  The Transport module uses an adapter pattern where:

    1. `Transport.new/2` creates a transport struct with the appropriate adapter
    2. The adapter handles transport-specific initialization and configuration
    3. `Transport.request/2` delegates requests to the adapter's `handle_request/2` callback
    4. Each transport type implements the `Exth.Transport` behaviour
  """

  ###
  ### Types
  ###

  @type adapter_config :: term()

  @transport_types [:custom, :http, :ipc, :websocket]

  @transport_type @transport_types
                  |> Enum.reverse()
                  |> then(fn [first | rest] -> Enum.reduce(rest, first, &{:|, [], [&1, &2]}) end)

  @type type :: unquote(@transport_type)

  @type transport_options() :: keyword()
  @type request_response :: :ok | {:ok, String.t()} | {:error, term()}

  ###
  ### Struct
  ###

  @type t :: %__MODULE__{
          adapter: module(),
          adapter_config: adapter_config()
        }

  defstruct [:adapter, :adapter_config]

  ###
  ### Behaviour callbacks
  ###

  @callback init(transport_options()) :: {:ok, adapter_config()} | {:error, term()}

  @callback handle_request(transport_state :: adapter_config(), request :: String.t()) ::
              request_response()

  ###
  ### Macros
  ###

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour Exth.Transport

      @before_compile Exth.Transport
    end
  end

  defmacro __before_compile__(env) do
    not_implemented =
      __MODULE__.behaviour_info(:callbacks)
      |> Enum.filter(&(not Module.defines?(env.module, &1)))
      |> Enum.map(fn {function, arity} -> "#{function}/#{arity}" end)

    if not_implemented != [] do
      raise CompileError,
        description: """
        The behaviour Exth.Transport is not implemented (in module #{inspect(env.module)}).
        You must implement the following functions: #{Enum.join(not_implemented, ", ")}
        """
    end
  end

  ###
  ### Public API
  ###

  @spec new(type(), transport_options()) :: {:ok, t()} | {:error, term()}
  def new(type, opts) when type in @transport_types do
    with {:ok, adapter} <- fetch_transport_module(type, opts),
         {:ok, adapter_config} <- adapter.init(opts) do
      {:ok, %__MODULE__{adapter: adapter, adapter_config: adapter_config}}
    end
  end

  def new(type, _opts) do
    {:error, "Invalid transport type: #{inspect(type)}"}
  end

  defp fetch_transport_module(type, opts) do
    case {type, Keyword.get(opts, :module)} do
      {:http, nil} -> {:ok, __MODULE__.Http}
      {:ipc, nil} -> {:ok, __MODULE__.Ipc}
      {:websocket, nil} -> {:ok, __MODULE__.Websocket}
      {_, module} when not is_nil(module) -> {:ok, module}
      _ -> {:error, "Invalid transport type: #{inspect(type)}"}
    end
  end

  @spec request(t(), String.t()) :: request_response()
  def request(%__MODULE__{} = transport, request) do
    transport.adapter.handle_request(transport.adapter_config, request)
  end
end
