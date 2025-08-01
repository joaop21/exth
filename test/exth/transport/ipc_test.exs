defmodule Exth.Transport.IpcTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Exth.Transport.Ipc

  describe "new/1" do
    test "creates a new IPC transport with valid path" do
      transport = Ipc.new(path: "/tmp/test.sock")

      assert %Ipc{
               path: "/tmp/test.sock",
               socket_opts: [:binary, active: false, reuseaddr: true],
               timeout: 30_000
             } = transport
    end

    test "creates a new IPC transport with custom options" do
      transport =
        Ipc.new(
          path: "/tmp/custom.sock",
          timeout: 15_000,
          socket_opts: [:binary, active: false]
        )

      assert %Ipc{
               path: "/tmp/custom.sock",
               socket_opts: [:binary, active: false],
               timeout: 15_000
             } = transport
    end

    test "raises error when path is not provided" do
      assert_raise ArgumentError, "IPC socket path is required but was not provided", fn ->
        Ipc.new([])
      end
    end

    test "raises error when path is not a string" do
      assert_raise ArgumentError, "Invalid IPC socket path: expected string, got: 123", fn ->
        Ipc.new(path: 123)
      end
    end
  end

  describe "call/2" do
    test "returns error when socket is not available" do
      transport = Ipc.new(path: "/tmp/nonexistent.sock")
      request = Jason.encode!(%{jsonrpc: "2.0", id: 1, method: "eth_blockNumber", params: []})

      result = Ipc.call(transport, request)

      assert {:error, {:connection_error, :enoent}} = result
    end

    test "sends request through socket" do
      path = "/tmp/test.sock"
      transport = Ipc.new(path: path)

      request = Jason.encode!(%{jsonrpc: "2.0", id: 1, method: "eth_blockNumber", params: []})
      response = Jason.encode!(%{jsonrpc: "2.0", id: 1, result: "0x1"})

      socket = %{}
      expect(Ipc.Socket, :connect, fn ^path, _socket_opts -> {:ok, socket} end)
      expect(Ipc.Socket, :send_request, fn ^socket, ^request, 30_000 -> {:ok, response} end)
      expect(Ipc.Socket, :close, fn ^socket -> :ok end)

      result = Ipc.call(transport, request)

      assert {:ok, ^response} = result
    end

    test "returns error when something is wrong with the socket" do
      path = "/tmp/test.sock"
      transport = Ipc.new(path: path)

      request = Jason.encode!(%{jsonrpc: "2.0", id: 1, method: "eth_blockNumber", params: []})

      socket = %{}
      expect(Ipc.Socket, :connect, fn ^path, _socket_opts -> {:ok, socket} end)
      expect(Ipc.Socket, :send_request, fn ^socket, ^request, 30_000 -> {:error, :bad_data} end)
      expect(Ipc.Socket, :close, fn ^socket -> :ok end)

      result = Ipc.call(transport, request)

      assert {:error, {:socket_error, :bad_data}} = result
    end
  end
end
