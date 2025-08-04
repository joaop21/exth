defmodule Exth.Transport.Ipc.ConnectionPool do
  @moduledoc false

  alias Exth.Transport
  alias Exth.Transport.Ipc

  defstruct [:lazy, :max_idle_pings, :name, :pool_size, :worker, :worker_idle_timeout]

  @pool_timeout 30_000

  ###
  ### Public API
  ###

  def start(opts) do
    path = Keyword.fetch!(opts, :path)
    socket_opts = Keyword.fetch!(opts, :socket_opts)

    # pool opts
    {pool_size, opts} = Keyword.pop(opts, :pool_size, 10)
    {pool_lazy_workers, opts} = Keyword.pop(opts, :pool_lazy_workers, true)
    {pool_worker_idle_timeout, opts} = Keyword.pop(opts, :pool_worker_idle_timeout, nil)
    {pool_max_idle_pings, _opts} = Keyword.pop(opts, :pool_max_idle_pings, -1)
    pool_name = via_tuple(path)

    pool_opts = [
      lazy: pool_lazy_workers,
      max_idle_pings: pool_max_idle_pings,
      name: pool_name,
      pool_size: pool_size,
      worker: {__MODULE__, {path, socket_opts}},
      worker_idle_timeout: pool_worker_idle_timeout
    ]

    {:ok, _pid} = Ipc.DynamicSupervisor.start_pool({NimblePool, pool_opts})

    {:ok, struct(__MODULE__, pool_opts)}
  end

  def call(%__MODULE__{} = pool, request, timeout) do
    NimblePool.checkout!(
      pool.name,
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
