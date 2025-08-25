defmodule Exth.Transport.Websocket do
  @moduledoc """
  WebSocket transport for real-time JSON-RPC communication.

  Messages are sent via `Transport.request/2` and responses arrive via the dispatch callback.

  > #### Performance consideration {: .warning}
  >
  > The dispatch callback runs in the WebSocket process. Be aware that intensive 
  > processing in the callback will block message handling and may affect connection performance.

  ## Options

    * `:rpc_url` - WebSocket endpoint (ws:// or wss://, required)
    * `:dispatch_callback` - Function to handle incoming messages (required)

  ## Example

      {:ok, transport} = Transport.new(:websocket,
        rpc_url: "wss://api.example.com",
        dispatch_callback: fn response -> handle_response(response) end
      )
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
  def init(opts) do
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
