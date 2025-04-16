defmodule Exth.Rpc.CallTest do
  use ExUnit.Case, async: true

  alias Exth.Rpc.Call
  alias Exth.Rpc.Client
  alias Exth.Rpc.Request

  @rpc_url "http://localhost:8545"

  describe "new/1" do
    test "creates a new call with the given client" do
      client = Client.new(:http, rpc_url: @rpc_url)
      call = Call.new(client)

      assert %Call{client: ^client, requests: []} = call
    end
  end

  describe "add_request/3" do
    test "adds a request to the call chain" do
      client = Client.new(:http, rpc_url: @rpc_url)
      call = Call.new(client)

      # Add first request
      call = Call.add_request(call, "eth_blockNumber", [])
      assert length(call.requests) == 1
      [request1] = call.requests
      assert %Request{method: "eth_blockNumber", params: []} = request1
      assert is_integer(request1.id)

      # Add second request
      call = Call.add_request(call, "eth_getBalance", ["0x123", "latest"])
      assert length(call.requests) == 2
      [_, request2] = call.requests
      assert %Request{method: "eth_getBalance", params: ["0x123", "latest"]} = request2
      assert is_integer(request2.id)
      assert request2.id != request1.id
    end

    test "preserves the client when adding requests" do
      client = Client.new(:http, rpc_url: @rpc_url)
      call = Call.new(client)
      call = Call.add_request(call, "eth_blockNumber", [])
      assert call.client == client
    end
  end

  describe "get_requests/1" do
    test "returns the list of requests in the call chain" do
      client = Client.new(:http, rpc_url: @rpc_url)

      call =
        Call.new(client)
        |> Call.add_request(call, "eth_blockNumber", [])
        |> Call.add_request(call, "eth_getBalance", ["0x123", "latest"])

      requests = Call.get_requests(call)
      assert length(requests) == 2
      [request1, request2] = requests

      assert %Request{method: "eth_blockNumber", params: []} = request1
      assert %Request{method: "eth_getBalance", params: ["0x123", "latest"]} = request2
    end

    test "returns an empty list for a new call" do
      client = Client.new(:http, rpc_url: @rpc_url)
      call = Call.new(client)
      assert [] = Call.get_requests(call)
    end
  end

  describe "get_client/1" do
    test "returns the client associated with the call chain" do
      client = Client.new(:http, rpc_url: @rpc_url)
      call = Call.new(client)
      assert ^client = Call.get_client(call)

      # Verify client is still returned after adding requests
      call = Call.add_request(call, "eth_blockNumber", [])
      assert ^client = Call.get_client(call)
    end
  end
end
