defmodule Exth.RpcTest do
  @moduledoc false

  # Most of the tests are in `Exth.Rpc.ClientTest`
  # This test is to ensure that the public API is working

  use ExUnit.Case, async: true

  alias Exth.Rpc
  alias Exth.TestTransport

  setup do
    client = Rpc.new_client(:custom, module: TestTransport, rpc_url: "http://localhost:8545")
    {:ok, client: client}
  end

  describe "public API" do
    test "jsonrpc_version/0 returns correct version" do
      assert Rpc.jsonrpc_version() == "2.0"
    end

    test "new_client/2 creates a working client", %{client: client} do
      assert %Exth.Rpc.Client{} = client
    end

    test "request/3 creates valid request", %{client: client} do
      request = Rpc.request(client, "eth_blockNumber", [])

      assert %Exth.Rpc.Request{} = request
      assert request.method == "eth_blockNumber"
      assert request.params == []
      assert request.jsonrpc == "2.0"
      assert is_integer(request.id)
    end

    test "send/2 works with single request", %{client: client} do
      request = Rpc.request(client, "eth_blockNumber", [])

      assert {:ok, response} = Rpc.send(client, request)
      assert %Exth.Rpc.Response.Success{} = response
      assert response.id == request.id
    end

    test "send/2 works with batch request", %{client: client} do
      requests = [
        Rpc.request(client, "eth_blockNumber", []),
        Rpc.request(client, "eth_chainId", [])
      ]

      assert {:ok, responses} = Rpc.send(client, requests)
      assert length(responses) == 2

      Enum.zip(requests, responses)
      |> Enum.each(fn {req, resp} ->
        assert %Exth.Rpc.Response.Success{} = resp
        assert resp.id == req.id
      end)
    end
  end

  test "examples from documentation work", %{client: client} do
    request = Rpc.request(client, "eth_blockNumber", [])
    assert {:ok, response} = Rpc.send(client, request)
    assert %Exth.Rpc.Response.Success{} = response
  end
end
