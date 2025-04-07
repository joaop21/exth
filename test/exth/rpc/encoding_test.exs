defmodule Exth.Rpc.EncodingTest do
  use ExUnit.Case, async: true

  alias Exth.Rpc.Encoding
  alias Exth.Rpc.Request
  alias Exth.Rpc.Response

  describe "round trip encoding/decoding" do
    test "request -> response cycle" do
      # Create and encode a request
      request = %Request{
        method: "eth_blockNumber",
        params: [],
        id: 1
      }

      assert {:ok, _request_json} = Request.serialize(request)

      # Simulate a success response
      response_json = """
      {
        "jsonrpc": "2.0",
        "result": "0x1234",
        "id": 1
      }
      """

      # Decode the response
      assert {:ok, response} = Encoding.decode_response(response_json)
      assert response.id == request.id
    end

    test "batch request -> response cycle" do
      requests = [
        %Request{method: "eth_blockNumber", params: [], id: 1},
        %Request{method: "eth_gasPrice", params: [], id: 2}
      ]

      assert {:ok, _request_json} = Request.serialize(requests)

      response_json = """
      [
        {
          "jsonrpc": "2.0",
          "result": "0x1234",
          "id": 1
        },
        {
          "jsonrpc": "2.0",
          "result": "0x5678",
          "id": 2
        }
      ]
      """

      assert {:ok, responses} = Encoding.decode_response(response_json)
      assert length(responses) == length(requests)

      for {request, response} <- Enum.zip(requests, responses) do
        assert request.id == response.id
      end
    end
  end
end
