defmodule Exth.Transport.Ipc do
  @moduledoc false

  alias __MODULE__.Socket

  defstruct [:path, :socket_opts, :timeout]

  @default_timeout 30_000
  @default_socket_opts [:binary, active: false, reuseaddr: true]

  def new(opts) do
    with {:ok, path} <- validate_required_path(opts[:path]) do
      timeout = opts[:timeout] || @default_timeout
      socket_opts = opts[:socket_opts] || @default_socket_opts

      %__MODULE__{
        path: path,
        socket_opts: socket_opts,
        timeout: timeout
      }
    end
  end

  def call(%__MODULE__{path: path, socket_opts: socket_opts, timeout: timeout}, request) do
    case Socket.connect(path, socket_opts) do
      {:ok, socket} ->
        try do
          case Socket.send_request(socket, request, timeout) do
            {:ok, response} -> {:ok, response}
            {:error, reason} -> {:error, {:socket_error, reason}}
          end
        after
          Socket.close(socket)
        end

      {:error, reason} ->
        {:error, {:connection_error, reason}}
    end
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
