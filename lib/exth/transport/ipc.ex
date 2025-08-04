defmodule Exth.Transport.Ipc do
  @moduledoc false

  alias __MODULE__.ConnectionPool
  # alias __MODULE__.Socket

  defstruct [:path, :pool, :socket_opts, :timeout]

  @default_timeout 30_000
  @default_socket_opts [:binary, active: false, reuseaddr: true]

  def new(opts) do
    with {:ok, path} <- validate_required_path(opts[:path]) do
      timeout = opts[:timeout] || @default_timeout
      socket_opts = opts[:socket_opts] || @default_socket_opts

      {:ok, %ConnectionPool{} = pool} = ConnectionPool.start(opts ++ [socket_opts: socket_opts])

      %__MODULE__{
        path: path,
        pool: pool,
        socket_opts: socket_opts,
        timeout: timeout
      }
    end
  end

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
