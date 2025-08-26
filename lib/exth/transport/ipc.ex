defmodule Exth.Transport.Ipc do
  @moduledoc """
  IPC transport for local Unix domain socket connections.

  Uses NimblePool for connection management.

  ## Options

    * `:path` - Socket path (required)
    * `:timeout` - Request timeout in ms (default: 30,000)
    * `:pool_size` - Connection pool size (default: 10)

  ## Example

      {:ok, transport} = Transport.new(:ipc, path: "/tmp/ethereum.ipc")
      {:ok, response} = Transport.request(transport, json_request)
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
  def init(opts) do
    with {:ok, path} <- validate_required_path(opts[:path]) do
      timeout = opts[:timeout] || @default_timeout
      socket_opts = opts[:socket_opts] || @default_socket_opts

      {:ok, pool} = ConnectionPool.start(opts ++ [socket_opts: socket_opts])

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
