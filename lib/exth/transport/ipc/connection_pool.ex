defmodule Exth.Transport.Ipc.ConnectionPool do
  @moduledoc false

  alias Exth.Transport
  alias Exth.Transport.Ipc

  @pool_timeout 30_000

  ###
  ### Public API
  ###

  def start(opts) do
    path = Keyword.fetch!(opts, :path)
    socket_opts = Keyword.fetch!(opts, :socket_opts)

    pool_name = via_tuple(path)

    pool_spec =
      {NimblePool, worker: {__MODULE__, {path, socket_opts}}, name: pool_name}

    {:ok, _pid} = Ipc.DynamicSupervisor.start_pool(pool_spec)

    {:ok, pool_name}
  end

  def call(pool, request, timeout) do
    NimblePool.checkout!(
      pool,
      :checkout,
      fn _from, socket ->
        result = send_request(socket, request, timeout)
        {result, socket}
      end,
      @pool_timeout
    )
  end

  defp send_request(socket, request, timeout) do
    with :ok <- :gen_tcp.send(socket, request) do
      receive_response(socket, timeout)
    end
  end

  defp receive_response(socket, timeout) do
    case :gen_tcp.recv(socket, 0, timeout) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, {:socket_error, reason}}
    end
  end

  ###
  ### NimblePool callbacks
  ###

  @behaviour NimblePool

  @impl true
  def init_worker({path, opts} = pool_state) do
    {:ok, socket} = :gen_tcp.connect({:local, path}, 0, opts)
    {:ok, socket, pool_state}
  end

  @impl true
  def handle_checkout(:checkout, _from, socket, pool_state) do
    {:ok, socket, socket, pool_state}
  end

  @impl true
  def terminate_worker(_reason, socket, pool_state) do
    :gen_tcp.close(socket)
    {:ok, pool_state}
  end

  ###
  ### Private functions
  ###

  defp via_tuple(path) do
    Transport.Registry.via_tuple({__MODULE__, path})
  end
end
