defmodule Exth.Transport.Websocket do
  @moduledoc """
  WebSocket transport implementation for JSON-RPC communication with EVM nodes.

  This module provides WebSocket transport capabilities using the Fresh WebSocket client
  library, enabling real-time communication and subscription support for JSON-RPC endpoints.

  ## Features

    * Full-duplex WebSocket communication
    * Support for both ws:// and wss:// protocols
    * Automatic connection management and lifecycle
    * Asynchronous message handling via dispatch callbacks
    * Connection state management and supervision
    * Real-time subscription support

  ## Configuration Options

    * `:rpc_url` - Required WebSocket endpoint URL (must start with ws:// or wss://)
    * `:dispatch_callback` - Required function to handle incoming messages (arity 1)
    * `:timeout` - Connection timeout in milliseconds (default: 30,000ms)

  ## Example Usage

      # Create WebSocket transport
      {:ok, transport} = Transport.new(:websocket,
        rpc_url: "wss://eth-mainnet.example.com",
        dispatch_callback: fn response -> handle_response(response) end
      )

      # Make WebSocket request
      {:ok, response} = Transport.request(transport, json_request)

  ## Message Flow

  1. Transport is initialized with a dispatch callback
  2. WebSocket connection is established via dynamic supervisor
  3. Outgoing messages are sent through `Transport.request/2`
  4. Incoming messages are handled by the dispatch callback
  5. Connection is maintained for subsequent requests

  ## Best Practices

    * Use wss:// for production environments
    * Implement proper error handling in dispatch callbacks
    * Monitor connection health and implement reconnection logic
    * Clean up resources when done
  """

  use Fresh
  use Exth.Transport

  alias Exth.Transport

  @type t :: %__MODULE__{
          dispatch_callback: function(),
          name: {:via, module(), {module(), String.t()}}
        }

  defstruct [:dispatch_callback, :name]

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            dispatch_callback: function()
          }

    defstruct [:dispatch_callback]
  end

  @impl Exth.Transport
  def init_transport(opts) do
    with {:ok, rpc_url} <- validate_required_url(opts[:rpc_url]),
         :ok <- validate_url_format(rpc_url),
         {:ok, dispatch_callback} <-
           validate_required_dispatch_callback(opts[:dispatch_callback]) do
      name = via_tuple(rpc_url)

      child_spec = {
        __MODULE__,
        uri: rpc_url, state: %State{dispatch_callback: dispatch_callback}, opts: [name: name]
      }

      {:ok, _pid} = __MODULE__.DynamicSupervisor.start_websocket(child_spec)

      # this is needed to avoid a race condition where the websocket is not yet connected
      # and the subscriptions are not yet registered
      # Fresh should be able to handle this, but it doesn't (yet)
      Process.sleep(1_000)

      {:ok, %__MODULE__{dispatch_callback: dispatch_callback, name: name}}
    end
  end

  @impl Exth.Transport
  def handle_request(%__MODULE__{name: name}, request) do
    Fresh.send(name, {:text, request})
  end

  # Fresh callbacks

  @impl Fresh
  def handle_in({:text, encoded_response}, %State{} = state) do
    state.dispatch_callback.(encoded_response)
    {:ok, state}
  end

  # Private functions

  defp validate_required_url(nil) do
    {:error, "RPC URL is required but was not provided"}
  end

  defp validate_required_url(url) when not is_binary(url) do
    {:error, "Invalid RPC URL: expected string, got: #{inspect(url)}"}
  end

  defp validate_required_url(url), do: {:ok, url}

  defp validate_url_format(url) do
    case URI.parse(url) do
      %URI{scheme: scheme} when scheme not in ["ws", "wss"] ->
        {:error,
         "Invalid RPC URL format: #{inspect(url)}. The URL must start with ws:// or wss://"}

      %URI{host: ""} ->
        {:error, "Invalid RPC URL format: #{inspect(url)}. The URL must contain a valid host"}

      %URI{scheme: scheme, host: host} when scheme in ["ws", "wss"] and not is_nil(host) ->
        :ok

      _ ->
        {:error, "Invalid RPC URL format: #{inspect(url)}"}
    end
  end

  defp validate_required_dispatch_callback(nil) do
    {:error, "Dispatcher callback function is required but was not provided"}
  end

  defp validate_required_dispatch_callback(dispatch_callback)
       when not is_function(dispatch_callback, 1) do
    {:error,
     "Invalid dispatch_callback function: expected function with arity 1, got: #{inspect(dispatch_callback)}"}
  end

  defp validate_required_dispatch_callback(dispatch_callback), do: {:ok, dispatch_callback}

  defp via_tuple(rpc_url) do
    Transport.Registry.via_tuple({__MODULE__, rpc_url})
  end
end
