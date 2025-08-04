defmodule Exth.Transport.IpcTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Exth.Transport.Ipc

  describe "new/1" do
    test "creates a new IPC transport with valid path" do
      pool = %Ipc.ConnectionPool{name: "pool_name"}
      expect(Ipc.ConnectionPool, :start, fn _opts -> {:ok, pool} end)

      transport = Ipc.new(path: "/tmp/test.sock")

      assert %Ipc{
               path: "/tmp/test.sock",
               pool: ^pool,
               socket_opts: [:binary, active: false, reuseaddr: true],
               timeout: 30_000
             } = transport
    end

    test "creates a new IPC transport with custom options" do
      pool = %Ipc.ConnectionPool{name: "pool_name"}
      expect(Ipc.ConnectionPool, :start, fn _opts -> {:ok, pool} end)

      transport =
        Ipc.new(
          path: "/tmp/custom.sock",
          timeout: 15_000,
          socket_opts: [:binary, active: false]
        )

      assert %Ipc{
               path: "/tmp/custom.sock",
               pool: ^pool,
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
    setup do
      path = "/tmp/test.sock"
      pool = %Ipc.ConnectionPool{name: "pool_name"}
      expect(Ipc.ConnectionPool, :start, fn _opts -> {:ok, pool} end)

      {:ok, transport: Ipc.new(path: path), pool: pool}
    end

    test "sends request through socket", %{transport: transport, pool: pool} do
      request = Jason.encode!(%{jsonrpc: "2.0", id: 1, method: "eth_blockNumber", params: []})
      response = Jason.encode!(%{jsonrpc: "2.0", id: 1, result: "0x1"})

      expect(Ipc.ConnectionPool, :call, fn ^pool, ^request, 30_000 -> {:ok, response} end)

      result = Ipc.call(transport, request)

      assert {:ok, ^response} = result
    end

    test "returns error when something is wrong with the socket", %{
      transport: transport,
      pool: pool
    } do
      request = Jason.encode!(%{jsonrpc: "2.0", id: 1, method: "eth_blockNumber", params: []})

      expect(Ipc.ConnectionPool, :call, fn ^pool, ^request, 30_000 ->
        {:error, {:socket_error, :bad_data}}
      end)

      result = Ipc.call(transport, request)

      assert {:error, {:socket_error, :bad_data}} = result
    end
  end
end
