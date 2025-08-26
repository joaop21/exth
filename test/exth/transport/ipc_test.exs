defmodule Exth.Transport.IpcTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Exth.Transport.Ipc

  describe "init/2 - transport initialization" do
    setup do
      %{
        opts: [path: "/tmp/test.sock"]
      }
    end

    test "creates a new IPC transport with valid path", %{opts: opts} do
      pool = %Ipc.ConnectionPool{name: "pool_name"}
      expect(Ipc.ConnectionPool, :start, fn _opts -> {:ok, pool} end)

      {:ok, transport} = Ipc.init(opts)

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

      opts = [
        path: "/tmp/custom.sock",
        timeout: 15_000,
        socket_opts: [:binary, active: false]
      ]

      {:ok, transport} = Ipc.init(opts)

      assert %Ipc{
               path: "/tmp/custom.sock",
               pool: ^pool,
               socket_opts: [:binary, active: false],
               timeout: 15_000
             } = transport
    end

    test "raises error when path is not provided", %{opts: opts} do
      opts = Keyword.delete(opts, :path)

      assert {:error, "IPC socket path is required but was not provided"} =
               Ipc.init(opts)
    end

    test "raises error when path is not a string", %{opts: opts} do
      opts = Keyword.put(opts, :path, 123)

      assert {:error, "Invalid IPC socket path: expected string, got: 123"} =
               Ipc.init(opts)
    end
  end

  describe "handle_request/2" do
    setup do
      path = "/tmp/test.sock"
      pool = %Ipc.ConnectionPool{name: "pool_name"}
      expect(Ipc.ConnectionPool, :start, fn _opts -> {:ok, pool} end)

      {:ok, transport} = Ipc.init(path: path)

      {:ok, transport: transport, pool: pool}
    end

    test "sends request through socket", %{transport: transport, pool: pool} do
      request = ~s({jsonrpc: "2.0", id: 1, method: "eth_blockNumber", params: []})
      response = ~s({jsonrpc: "2.0", id: 1, result: "0x1"})

      expect(Ipc.ConnectionPool, :call, fn ^pool, ^request, 30_000 -> {:ok, response} end)

      result = Ipc.handle_request(transport, request)

      assert {:ok, ^response} = result
    end

    test "returns error when something is wrong with the socket", %{
      transport: transport,
      pool: pool
    } do
      request = ~s({jsonrpc: "2.0", id: 1, method: "eth_blockNumber", params: []})

      expect(Ipc.ConnectionPool, :call, fn ^pool, ^request, 30_000 ->
        {:error, {:socket_error, :bad_data}}
      end)

      result = Ipc.handle_request(transport, request)

      assert {:error, {:socket_error, :bad_data}} = result
    end
  end
end
