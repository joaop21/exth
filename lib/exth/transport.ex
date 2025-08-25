defmodule Exth.Transport do
  @moduledoc """
  Unified transport interface for JSON-RPC communication.

  Supports HTTP, WebSocket, IPC, and custom transport implementations through a common API.

  ## Transport Types

    * `:http` - HTTP/HTTPS transport
    * `:websocket` - WebSocket transport (requires dispatch_callback)
    * `:ipc` - Unix domain socket transport
    * `:custom` - Custom transport implementations

  ## Quick Start

      # HTTP transport
      {:ok, transport} = Transport.new(:http, rpc_url: "https://api.example.com")
      {:ok, response} = Transport.request(transport, encoded_request)

      # WebSocket transport
      {:ok, ws_transport} = Transport.new(:websocket,
        rpc_url: "wss://api.example.com",
        dispatch_callback: fn response -> handle_response(response) end
      )

      # Custom transport
      {:ok, custom_transport} = Transport.new(:custom, module: MyCustomTransport)

  ## Request Format

  > #### Important {: .warning}
  >
  > The `request` parameter in `Transport.request/2` must already be encoded as a string.
  > Do not pass raw data structures - encode them first using the required encoding method.

  ## Custom Transport Implementation

      defmodule MyCustomTransport do
        use Exth.Transport

        @impl Exth.Transport
        def init(opts) do
          # Initialize your transport
          {:ok, transport_state}
        end

        @impl Exth.Transport
        def handle_request(transport_state, request) do
          # Handle the encoded request
          {:ok, response}
        end
      end

  ## Return Types

    * `{:ok, response}` - Successful request with response
    * `{:error, reason}` - Request failed
    * `:ok` - For transports that don't return responses (e.g., WebSocket)
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

  @doc """
  Creates a new transport with the specified type and options.

  ## Parameters

    * `type` - Transport type (`:http`, `:websocket`, `:ipc`, or `:custom`)
    * `opts` - Transport-specific configuration options

  ## Returns

    * `{:ok, transport}` - Successfully created transport
    * `{:error, reason}` - Failed to create transport

  ## Examples

      # HTTP transport
      {:ok, transport} = Transport.new(:http, rpc_url: "https://api.example.com")

      # WebSocket transport
      {:ok, ws_transport} = Transport.new(:websocket,
        rpc_url: "wss://api.example.com",
        dispatch_callback: fn response -> handle_response(response) end
      )

      # IPC transport
      {:ok, ipc_transport} = Transport.new(:ipc, path: "/tmp/ethereum.ipc")

      # Custom transport
      {:ok, custom_transport} = Transport.new(:custom, module: MyCustomTransport)

  ## Transport-Specific Options

    * **HTTP**: `rpc_url`, `timeout`, `headers`, `adapter`
    * **WebSocket**: `rpc_url`, `dispatch_callback`
    * **IPC**: `path`, `timeout`, `pool_size`, `socket_opts`
    * **Custom**: `module` (required)
  """
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

  @doc """
  Makes a request using the configured transport.

  ## Parameters

    * `transport` - The configured transport instance
    * `request` - **Pre-encoded string** (encode your data structures first)

  ## Returns

    * `{:ok, response}` - Successful request with encoded response string
    * `{:error, reason}` - Request failed
    * `:ok` - For transports that don't return responses (e.g., WebSocket)

  ## Example

      # Encode your request data first
      request_data = %{
        "jsonrpc" => "2.0",
        "method" => "eth_blockNumber", 
        "params" => [],
        "id" => 1
      }
      
      encoded_request = encode_request(request_data)
      {:ok, encoded_response} = Transport.request(transport, encoded_request)
      
      # Decode the response
      response_data = decode_response(encoded_response)
  """
  @spec request(t(), String.t()) :: request_response()
  def request(%__MODULE__{} = transport, request) do
    transport.adapter.handle_request(transport.adapter_config, request)
  end
end
