defmodule Exth.Rpc.InnerClientTest do
  use ExUnit.Case, async: true

  alias Exth.AsyncTestTransport
  alias Exth.Rpc.InnerClient
  alias Exth.Rpc.Request
  alias Exth.Rpc.Response
  alias Exth.Transport

  setup do
    transport = Transport.new(:custom, rpc_url: "https://example.com", module: AsyncTestTransport)
    {:ok, client} = InnerClient.new()
    %{client: client, transport: transport}
  end

  describe "new/0" do
    test "creates a new InnerClient process" do
      assert {:ok, pid} = InnerClient.new()
      assert Process.alive?(pid)
    end
  end

  describe "set_transport/2" do
    test "sets the transport for the client", %{client: client, transport: transport} do
      assert :ok = InnerClient.set_transport(client, transport)
    end
  end

  describe "call/3" do
    test "sends a request and receives a response", %{client: client, transport: transport} do
      :ok = InnerClient.set_transport(client, transport)

      request = [%Request{id: 1, method: "eth_blockNumber", params: []}]
      response = [%{id: 1, result: "test"}]

      # Start a process to send the response
      spawn(fn ->
        Process.sleep(10)
        send(client, {:response, Jason.encode!(response)})
      end)

      assert {:ok, [%Response.Success{id: 1, result: "test"}]} = InnerClient.call(client, request)
    end

    test "handles deserialization errors", %{client: client, transport: transport} do
      :ok = InnerClient.set_transport(client, transport)

      request = [%Request{id: 1, method: "test", params: []}]

      # Start a process to send an invalid response
      spawn(fn ->
        Process.sleep(10)
        send(client, {:response, "invalid json"})
      end)

      timeout_ms = 1000

      assert catch_exit(InnerClient.call(client, request, timeout_ms)) ==
               {:timeout, {GenServer, :call, [client, {:send, request}, timeout_ms]}}
    end

    test "handles orphaned responses", %{client: client, transport: transport} do
      :ok = InnerClient.set_transport(client, transport)

      # Send a response without a matching request
      response = %{id: 999, result: "test"}
      send(client, {:response, Jason.encode!(response)})

      # The process should not crash
      assert Process.alive?(client)
    end
  end
end
