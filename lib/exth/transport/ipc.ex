defmodule Exth.Transport.Ipc do
  @moduledoc """
  IPC (Inter-Process Communication) transport implementation for JSON-RPC requests using Unix domain sockets.

  Implements the `Exth.Transport.Transportable` protocol for making IPC connections to JSON-RPC
  endpoints via Unix domain sockets. Uses NimblePool for connection pooling and efficient
  resource management.

  ## Features

    * Unix domain socket communication
    * Connection pooling with NimblePool
    * Automatic connection management
    * Configurable pool size and timeouts
    * Efficient resource utilization
    * Process registration with via-tuples

  ## Usage

      transport = Transportable.new(
        %Exth.Transport.Ipc{},
        path: "/tmp/ethereum.ipc"
      )

      {:ok, response} = Transportable.call(transport, request)

  ## Configuration

  Required options:
    * `:path` - The Unix domain socket path (e.g., "/tmp/ethereum.ipc")

  Optional options:
    * `:timeout` - Request timeout in milliseconds (defaults to 30000)
    * `:socket_opts` - TCP socket options (defaults to [:binary, active: false, reuseaddr: true])
    * `:pool_size` - Number of connections in the pool (defaults to 10)
    * `:pool_lazy_workers` - Whether to create workers lazily (defaults to true)
    * `:pool_worker_idle_timeout` - Worker idle timeout (defaults to nil)
    * `:pool_max_idle_pings` - Maximum idle pings before worker termination (defaults to -1)

  ## Connection Pooling

  The IPC transport uses NimblePool to manage a pool of Unix domain socket connections.
  This provides several benefits:

    * Efficient resource utilization
    * Automatic connection lifecycle management
    * Configurable pool size for different workloads
    * Connection reuse for better performance

  ## Error Handling

  The transport handles several error cases:
    * Invalid socket path format
    * Missing required options
    * Connection failures
    * Socket communication errors
    * Pool exhaustion

  See `Exth.Transport.Transportable` for protocol details.
  """

  alias __MODULE__.ConnectionPool

  @typedoc "IPC transport configuration"
  @type t :: %__MODULE__{
          path: String.t(),
          pool: struct(),
          socket_opts: list(),
          timeout: non_neg_integer()
        }

  defstruct [:path, :pool, :socket_opts, :timeout]

  @default_timeout 30_000
  @default_socket_opts [:binary, active: false, reuseaddr: true]

  @spec new(keyword()) :: t()
  def new(opts) do
    with {:ok, path} <- validate_required_path(opts[:path]) do
      timeout = opts[:timeout] || @default_timeout
      socket_opts = opts[:socket_opts] || @default_socket_opts

      {:ok, pool} = ConnectionPool.start(opts ++ [socket_opts: socket_opts])

      %__MODULE__{
        path: path,
        pool: pool,
        socket_opts: socket_opts,
        timeout: timeout
      }
    end
  end

  @spec call(t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def call(%__MODULE__{} = transport, request) do
    ConnectionPool.call(transport.pool, request, transport.timeout)
  end

  # Private functions

  defp validate_required_path(nil) do
    raise ArgumentError, "IPC socket path is required but was not provided"
  end

  defp validate_required_path(path) when not is_binary(path) do
    raise ArgumentError, "Invalid IPC socket path: expected string, got: #{inspect(path)}"
  end

  defp validate_required_path(path), do: {:ok, path}
end

defimpl Exth.Transport.Transportable, for: Exth.Transport.Ipc do
  def new(_transport, opts), do: Exth.Transport.Ipc.new(opts)
  def call(transport, request), do: Exth.Transport.Ipc.call(transport, request)
end
