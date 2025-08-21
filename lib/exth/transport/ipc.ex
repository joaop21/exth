defmodule Exth.Transport.Ipc do
  @moduledoc """
  IPC (Inter-Process Communication) transport implementation for JSON-RPC communication with EVM nodes.

  This module provides IPC transport capabilities using Unix domain sockets, enabling local
  communication with Ethereum nodes running on the same machine.

  ## Features

    * Unix domain socket communication
    * Connection pooling with NimblePool for efficient resource management
    * Automatic connection lifecycle management
    * Configurable pool size and timeouts
    * Process registration with via-tuples
    * Optimized for local node connections

  ## Configuration Options

    * `:path` - Required Unix domain socket path (e.g., "/tmp/ethereum.ipc")
    * `:timeout` - Request timeout in milliseconds (default: 30,000ms)
    * `:socket_opts` - TCP socket options (default: [:binary, active: false, reuseaddr: true])
    * `:pool_size` - Number of connections in the pool (default: 10)
    * `:pool_lazy_workers` - Whether to create workers lazily (default: true)
    * `:pool_worker_idle_timeout` - Worker idle timeout (default: nil)
    * `:pool_max_idle_pings` - Maximum idle pings before worker termination (default: -1)

  ## Example Usage

      # Create IPC transport
      {:ok, transport} = Transport.new(:ipc,
        path: "/tmp/ethereum.ipc",
        timeout: 15_000,
        pool_size: 5
      )

      # Make IPC request
      {:ok, response} = Transport.request(transport, json_request)

  ## Connection Pooling

  The IPC transport uses NimblePool to manage a pool of Unix domain socket connections,
  providing efficient resource utilization and automatic connection lifecycle management.

  ## Best Practices

    * Ensure the socket path exists and is accessible
    * Configure appropriate pool size for your workload
    * Monitor connection pool health
    * Use appropriate timeouts for your use case
  """

  use Exth.Transport

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

  @impl true
  def init_transport(transport_opts, _opts) do
    with {:ok, path} <- validate_required_path(transport_opts[:path]) do
      timeout = transport_opts[:timeout] || @default_timeout
      socket_opts = transport_opts[:socket_opts] || @default_socket_opts

      {:ok, pool} = ConnectionPool.start(transport_opts ++ [socket_opts: socket_opts])

      {:ok,
       %__MODULE__{
         path: path,
         pool: pool,
         socket_opts: socket_opts,
         timeout: timeout
       }}
    end
  end

  @impl true
  def handle_request(%__MODULE__{} = transport, request) do
    ConnectionPool.call(transport.pool, request, transport.timeout)
  end

  # Private functions

  defp validate_required_path(nil) do
    {:error, "IPC socket path is required but was not provided"}
  end

  defp validate_required_path(path) when not is_binary(path) do
    {:error, "Invalid IPC socket path: expected string, got: #{inspect(path)}"}
  end

  defp validate_required_path(path), do: {:ok, path}
end
