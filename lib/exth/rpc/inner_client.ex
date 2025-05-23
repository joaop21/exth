defmodule Exth.Rpc.InnerClient do
  @moduledoc """
  A GenServer that manages asynchronous transport for JSON-RPC requests.

  This module provides a persistent connection manager for asynchronous transports
  (like WebSocket), handling request/response correlation and connection state.
  It uses ETS tables to track pending requests and their corresponding callers.

  ## Features

    * Request/response correlation using ETS tables
    * Automatic request ID generation and tracking
    * Batch request support
    * Connection state management
    * Error handling and timeout management
    * Support for any asynchronous transport implementation

  ## Usage

      # Create a new inner client
      {:ok, client} = InnerClient.new()

      # Set the transport
      :ok = InnerClient.set_transport(client, transport)

      # Send a request
      {:ok, response} = InnerClient.call(client, request)

  ## Request/Response Flow

  1. Client sends a request through `call/2`
  2. Request ID is stored in ETS table with caller's PID
  3. Request is sent through transport
  4. Response is received and matched with request
  5. Response is sent back to caller
  6. Request entry is removed from ETS table

  ## Error Handling

  The client handles several error cases:
    * Deserialization errors
    * Orphaned responses
    * Timeouts
    * Transport errors

  ## Timeouts

  The default timeout for operations is 5000ms. This can be overridden
  by passing a timeout value to `call/3`.

  ## Transport Implementation

  Any transport implementation can be used with the InnerClient as long as it:
    * Implements the `Exth.Transport.Transportable` protocol
    * Handles asynchronous communication
    * Sends responses back to the InnerClient process using `{:response, encoded_response}` messages
  """

  use GenServer

  alias Exth.Rpc.Request
  alias Exth.Rpc.Response
  alias Exth.Transport
  alias Exth.Transport.Transportable

  @type request_id :: pos_integer() | String.t()
  @type state :: %{
          transport: Transportable.t() | nil,
          request_table: :ets.table()
        }

  @call_timeout 5_000

  # Public API

  @doc """
  Creates a new InnerClient process.

  ## Returns
    * `{:ok, pid()}` - Successfully started client
    * `{:error, term()}` - Failed to start client

  ## Example
      {:ok, client} = InnerClient.new()
  """
  @spec new() :: {:ok, pid()} | {:error, term()}
  def new, do: GenServer.start_link(__MODULE__, %{})

  @doc """
  Sets the transport for the client.

  ## Parameters
    * `client` - The client PID
    * `transport` - The transport to use (must implement Transportable protocol)

  ## Returns
    * `:ok` - Successfully set transport
    * `{:error, term()}` - Failed to set transport

  ## Example
      :ok = InnerClient.set_transport(client, transport)
  """
  @spec set_transport(pid(), Transportable.t()) :: :ok | {:error, term()}
  def set_transport(client, transport) do
    GenServer.call(client, {:set_transport, transport}, @call_timeout)
  end

  @doc """
  Sends a request through the client and waits for a response.

  ## Parameters
    * `client` - The client PID
    * `requests` - The request(s) to send
    * `timeout` - Optional timeout in milliseconds (default: 5000)

  ## Returns
    * `{:ok, response}` - Successful response
    * `{:error, term()}` - Request failed

  ## Example
      {:ok, response} = InnerClient.call(client, request)
  """
  @spec call(pid(), [Request.t()]) :: {:ok, [Response.t()]} | {:error, term()}
  def call(client, requests, timeout \\ @call_timeout) do
    GenServer.call(client, {:send, requests}, timeout)
  end

  # Server Callbacks

  @impl true
  def init(_state) do
    table_name = :crypto.strong_rand_bytes(20) |> Base.encode64() |> String.to_atom()
    table = :ets.new(table_name, [:named_table, :set, :protected])

    state = %{
      transport: nil,
      request_table: table
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:send, requests}, from, state) do
    request_id = get_request_id(requests)
    :ets.insert(state.request_table, {request_id, from})
    send_request(state.transport, requests)
    {:noreply, state}
  end

  def handle_call({:set_transport, transport}, _from, state) do
    {:reply, :ok, %{state | transport: transport}}
  end

  @impl true
  def handle_info({:response, encoded_response}, state) do
    case Response.deserialize(encoded_response) do
      {:ok, response} ->
        response_id = get_response_id(response)

        case :ets.lookup(state.request_table, response_id) do
          [{id, from}] ->
            :ets.delete(state.request_table, id)
            GenServer.reply(from, {:ok, response})
            {:noreply, state}

          [] ->
            # when there are no requests for the response, weird but possible?
            {:noreply, state}
        end

      {:error, _reason} ->
        # when deserialization fails, otherwise the process will crash
        {:noreply, state}
    end
  end

  # Private functions

  @doc false
  defp get_request_id(%{id: id}), do: id
  defp get_request_id(requests), do: Enum.map_join(requests, "_", &get_request_id/1)

  @doc false
  defp get_response_id(%{id: id}), do: id
  defp get_response_id(responses), do: Enum.map_join(responses, "_", &get_response_id/1)

  @doc false
  defp send_request(transport, requests) do
    {:ok, encoded_request} = Request.serialize(requests)
    Transport.call(transport, encoded_request)
  end
end
