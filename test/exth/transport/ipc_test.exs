defmodule Exth.Transport.IpcTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Exth.Transport.Ipc

  describe "init_transport/2 - transport initialization" do
    setup do
      %{
        transport_opts: [path: "/tmp/test.sock"],
        opts: []
      }
    end

    test "creates a new IPC transport with valid path", %{
      transport_opts: transport_opts,
      opts: opts
    } do
      pool = %Ipc.ConnectionPool{name: "pool_name"}
      expect(Ipc.ConnectionPool, :start, fn _opts -> {:ok, pool} end)

      {:ok, transport} = Ipc.init_transport(transport_opts, opts)

      assert %Ipc{
               path: "/tmp/test.sock",
               pool: ^pool,
               socket_opts: [:binary, active: false, reuseaddr: true],
               timeout: 30_000
             } = transport
    end

    test "creates a new IPC transport with custom options", %{opts: opts} do
      pool = %Ipc.ConnectionPool{name: "pool_name"}
      expect(Ipc.ConnectionPool, :start, fn _opts -> {:ok, pool} end)

      transport_opts = [
        path: "/tmp/custom.sock",
        timeout: 15_000,
        socket_opts: [:binary, active: false]
      ]

      {:ok, transport} = Ipc.init_transport(transport_opts, opts)

      assert %Ipc{
               path: "/tmp/custom.sock",
               pool: ^pool,
               socket_opts: [:binary, active: false],
               timeout: 15_000
             } = transport
    end

    test "raises error when path is not provided", %{transport_opts: transport_opts, opts: opts} do
      transport_opts = Keyword.delete(transport_opts, :path)

      assert {:error, "IPC socket path is required but was not provided"} =
               Ipc.init_transport(transport_opts, opts)
    end

    test "raises error when path is not a string", %{transport_opts: transport_opts, opts: opts} do
      transport_opts = Keyword.put(transport_opts, :path, 123)

      assert {:error, "Invalid IPC socket path: expected string, got: 123"} =
               Ipc.init_transport(transport_opts, opts)
    end
  end

  describe "handle_request/2" do
    setup do
      path = "/tmp/test.sock"
      pool = %Ipc.ConnectionPool{name: "pool_name"}
      expect(Ipc.ConnectionPool, :start, fn _opts -> {:ok, pool} end)

      {:ok, transport} = Ipc.init_transport([path: path], [])

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
