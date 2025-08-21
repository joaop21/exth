defmodule Exth.Transport.Websocket do
  @moduledoc """
  WebSocket transport implementation for JSON-RPC requests using Fresh.

  Implements the `Exth.Transport.Transportable` protocol for making WebSocket
  connections to JSON-RPC endpoints. Uses Fresh as the WebSocket client library.

  ## Features

    * Full-duplex communication
    * Automatic connection management
    * Asynchronous message handling
    * Support for both ws:// and wss:// protocols
    * Configurable dispatch callbacks
    * Connection state management

  ## Usage

      transport = Transportable.new(
        %Exth.Transport.Websocket{},
        rpc_url: "wss://mainnet.infura.io/ws/v3/YOUR-PROJECT-ID",
        dispatch_callback: fn response -> handle_response(response) end
      )

      {:ok, response} = Transportable.call(transport, request)

  ## Configuration

  Required options:
    * `:rpc_url` - The WebSocket endpoint URL (must start with ws:// or wss://)
    * `:dispatch_callback` - Function to handle incoming messages (arity 1)

  ## Message Flow

  1. Transport is initialized with a dispatch callback
  2. WebSocket connection is established
  3. Outgoing messages are sent through `call/2`
  4. Incoming messages are handled by the dispatch callback
  5. Connection is maintained for subsequent requests

  ## Error Handling

  The transport handles several error cases:
    * Invalid URL format
    * Missing required options
    * Connection failures
    * Message dispatch errors

  ## Best Practices

    * Use wss:// for production environments
    * Implement proper error handling in dispatch callbacks
    * Monitor connection health
    * Handle reconnection scenarios
    * Clean up resources when done

  See `Exth.Transport.Transportable` for protocol details.
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
  def init_transport(transport_opts, _opts) do
    with {:ok, rpc_url} <- validate_required_url(transport_opts[:rpc_url]),
         :ok <- validate_url_format(rpc_url),
         {:ok, dispatch_callback} <-
           validate_required_dispatch_callback(transport_opts[:dispatch_callback]) do
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
