defmodule Exth.Transport.Ipc.Socket do
  @moduledoc false

  def connect(path, opts \\ []), do: :gen_tcp.connect({:local, path}, 0, opts)

  def close(socket), do: :gen_tcp.close(socket)

  def send_request(socket, request, timeout) do
    with :ok <- :gen_tcp.send(socket, request) do
      receive_response(socket, timeout)
    end
  end

  defp receive_response(socket, timeout) do
    case :gen_tcp.recv(socket, 0, timeout) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, reason}
    end
  end
end
