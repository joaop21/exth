defmodule Exth.Rpc.InnerClient do
  @moduledoc false

  use GenServer

  alias Exth.Rpc.Request
  alias Exth.Rpc.Response
  alias Exth.Transport
  alias Exth.Transport.Transportable

  @type request_id :: pos_integer() | String.t()

  @call_timeout 5_000

  # Public API

  @spec new() :: {:ok, pid()} | {:error, term()}
  def new, do: GenServer.start_link(__MODULE__, %{})

  @spec set_transport(pid(), Transportable.t()) :: :ok | {:error, term()}
  def set_transport(client, transport) do
    GenServer.call(client, {:set_transport, transport}, @call_timeout)
  end

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

  defp get_request_id(%{id: id}), do: id
  defp get_request_id(requests), do: Enum.map_join(requests, "_", &get_request_id/1)

  defp get_response_id(%{id: id}), do: id
  defp get_response_id(responses), do: Enum.map_join(responses, "_", &get_response_id/1)

  defp send_request(transport, requests) do
    {:ok, encoded_request} = Request.serialize(requests)
    Transport.call(transport, encoded_request)
  end
end
