defmodule Exth.RpcTest do
  @moduledoc false

  # Most of the tests are in `Exth.Rpc.ClientTest`
  # This test is to ensure that the public API is working

  use ExUnit.Case, async: true

  alias Exth.Rpc
  alias Exth.Rpc.Call
  alias Exth.Rpc.Request
  alias Exth.TestTransport

  setup do
    client = Rpc.new_client(:custom, module: TestTransport, rpc_url: "http://localhost:8545")
    {:ok, client: client}
  end

  describe "public API" do
    test "new_client/2 creates a working client", %{client: client} do
      assert %Exth.Rpc.Client{} = client
    end

    test "request/3 creates valid RPC call", %{client: client} do
      rpc_call = Rpc.request(client, "eth_blockNumber", [])

      assert %Exth.Rpc.Call{} = rpc_call
      request = rpc_call |> Call.get_requests() |> hd()
      assert request.method == "eth_blockNumber"
      assert request.params == []
      assert request.jsonrpc == "2.0"
      assert is_integer(request.id)
    end

    test "request/3 creates a batch RPC call", %{client: client} do
      rpc_call =
        client
        |> Rpc.request("eth_blockNumber", [])
        |> Rpc.request("eth_chainId", [])

      assert %Exth.Rpc.Call{} = rpc_call
      [request1, request2] = rpc_call |> Call.get_requests()

      assert request1.method == "eth_blockNumber"
      assert request1.params == []
      assert request1.jsonrpc == "2.0"
      assert is_integer(request1.id)

      assert request2.method == "eth_chainId"
      assert request2.params == []
      assert request2.jsonrpc == "2.0"
      assert is_integer(request2.id)
    end

    test "raw_request/3 creates a standalone raw request" do
      %Request{} = request = Rpc.raw_request("eth_blockNumber", [], 1)
      assert request.id == 1
      assert request.jsonrpc == "2.0"
      assert request.method == "eth_blockNumber"
      assert request.params == []
    end

    test "send/2 works with single request", %{client: client} do
      request = Rpc.raw_request("eth_blockNumber", [], 1_000)

      assert {:ok, response} = Rpc.send(client, request)
      assert %Exth.Rpc.Response.Success{} = response
      assert response.id == request.id
    end

    test "send/2 works with batch request", %{client: client} do
      requests = [
        Rpc.raw_request("eth_blockNumber", []),
        Rpc.raw_request("eth_chainId", [])
      ]

      assert {:ok, responses} = Rpc.send(client, requests)
      assert length(responses) == 2
      assert [%Exth.Rpc.Response.Success{}, %Exth.Rpc.Response.Success{}] = responses
    end
  end

  test "send/1 successfully works with an RPC call with a single request", %{client: client} do
    call = Rpc.request(client, "eth_blockNumber", [])
    assert {:ok, response} = Rpc.send(call)
    assert %Exth.Rpc.Response.Success{} = response
  end

  test "send/1 successfully works with a batch RPC call", %{client: client} do
    rpc_call =
      client
      |> Rpc.request("eth_blockNumber", [])
      |> Rpc.request("eth_chainId", [])

    assert {:ok, response} = Rpc.send(rpc_call)
    assert [%Exth.Rpc.Response.Success{}, %Exth.Rpc.Response.Success{}] = response
  end
end
