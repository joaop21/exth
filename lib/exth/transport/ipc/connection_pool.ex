defmodule Exth.Transport.Ipc.ConnectionPool do
  @moduledoc false

  alias Exth.Transport
  alias Exth.Transport.Ipc

  @typedoc "Connection pool configuration"
  @type t :: %__MODULE__{
          lazy: boolean(),
          max_idle_pings: integer(),
          name: atom(),
          pool_size: non_neg_integer(),
          worker: {module(), term()},
          worker_idle_timeout: non_neg_integer() | nil
        }

  defstruct [:lazy, :max_idle_pings, :name, :pool_size, :worker, :worker_idle_timeout]

  @pool_timeout 30_000

  ###
  ### Public API
  ###

  @doc """
  Starts a new connection pool for the given socket path.

  ## Options
    * `:path` - (required) The Unix domain socket path
    * `:socket_opts` - (required) TCP socket options
    * `:pool_size` - Number of connections in the pool (defaults to 10)
    * `:pool_lazy_workers` - Whether to create workers lazily (defaults to true)
    * `:pool_worker_idle_timeout` - Worker idle timeout (defaults to nil)
    * `:pool_max_idle_pings` - Maximum idle pings before worker termination (defaults to -1)

  ## Returns
    * `{:ok, pool}` - Successfully started pool
    * `{:error, reason}` - Failed to start pool

  ## Examples

      {:ok, pool} = ConnectionPool.start(
        path: "/tmp/ethereum.ipc",
        socket_opts: [:binary, active: false],
        pool_size: 5
      )
  """
  @spec start(keyword()) :: {:ok, t()} | {:error, term()}
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

  @doc """
  Makes a request through the connection pool.

  Checks out a connection from the pool, sends the request, and returns the response.
  The connection is automatically returned to the pool after use.

  ## Arguments
    * `pool` - The connection pool instance
    * `request` - The JSON-RPC request as a string
    * `timeout` - Request timeout in milliseconds

  ## Returns
    * `{:ok, response}` - Successful request with encoded response
    * `{:error, {:socket_error, reason}}` - Socket communication error
    * `{:error, reason}` - Other errors (timeout, pool exhaustion, etc)

  ## Examples

      {:ok, response} = ConnectionPool.call(pool, request, 30_000)
  """
  @spec call(t(), String.t(), non_neg_integer()) :: {:ok, String.t()} | {:error, term()}
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
