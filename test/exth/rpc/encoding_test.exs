defmodule Exth.Rpc.EncodingTest do
  use ExUnit.Case, async: true

  alias Exth.Rpc.Encoding
  alias Exth.Rpc.Request
  alias Exth.Rpc.Response

  describe "decode_response/1" do
    test "decodes success responses with various result types" do
      test_cases = [
        {"0x1234", "hex string"},
        [1, 2, 3],
        "array",
        %{"key" => "value"},
        "object",
        true,
        "boolean",
        42,
        "number",
        nil,
        "null"
      ]

      for {result, type} <- test_cases do
        json =
          JSON.encode!(%{
            "jsonrpc" => "2.0",
            "result" => result,
            "id" => 1
          })

        assert {:ok, response} = Encoding.decode_response(json)
        assert %Response.Success{} = response
        assert response.result == result, "Failed to decode #{type} result"
        assert response.jsonrpc == "2.0"
      end
    end

    test "decodes error responses with different error codes" do
      test_cases = [
        {-32_700, "Parse error", nil},
        {-32_600, "Invalid Request", "additional info"},
        {-32_601, "Method not found", %{"details" => "more info"}},
        {-32_602, "Invalid params", [1, 2, 3]}
      ]

      for {code, message, data} <- test_cases do
        error =
          Map.reject(
            %{"code" => code, "message" => message, "data" => data},
            fn {_k, v} -> is_nil(v) end
          )

        json =
          JSON.encode!(%{
            "jsonrpc" => "2.0",
            "error" => error,
            "id" => 1
          })

        assert {:ok, response} = Encoding.decode_response(json)
        assert %Response.Error{} = response
        assert response.error.code == code
        assert response.error.message == message
        assert response.error.data == data
      end
    end

    test "handles malformed responses" do
      invalid_responses = [
        "invalid json",
        # missing jsonrpc
        ~s({"result": "0x1234"}),
        # both result and error
        ~s({"jsonrpc": "2.0", "result": "0x1234", "error": {}}),
        # incomplete response
        ~s([{"jsonrpc": "2.0"}])
      ]

      for invalid_json <- invalid_responses do
        assert {:error, _reason} = Encoding.decode_response(invalid_json)
      end
    end

    test "decodes batch responses with mixed success/error" do
      test_cases = [
        [
          %{"jsonrpc" => "2.0", "result" => "0x1", "id" => 1}
        ],
        [
          %{"jsonrpc" => "2.0", "result" => "0x1", "id" => 1},
          %{
            "jsonrpc" => "2.0",
            "error" => %{"code" => -32_600, "message" => "Invalid Request"},
            "id" => 2
          }
        ],
        [
          %{"jsonrpc" => "2.0", "result" => "0x1", "id" => 1},
          %{
            "jsonrpc" => "2.0",
            "error" => %{"code" => -32_600, "message" => "Invalid Request"},
            "id" => 2
          },
          %{"jsonrpc" => "2.0", "result" => %{"key" => "value"}, "id" => 3}
        ]
      ]

      for responses <- test_cases do
        json = JSON.encode!(responses)
        assert {:ok, decoded} = Encoding.decode_response(json)
        assert length(decoded) == length(responses)

        Enum.zip(responses, decoded)
        |> Enum.each(fn {resp, dec} ->
          assert resp["id"] == dec.id

          case resp do
            %{"result" => _} -> assert %Response.Success{} = dec
            %{"error" => _} -> assert %Response.Error{} = dec
          end
        end)
      end
    end

    test "decodes a success response" do
      json = """
      {
        "jsonrpc": "2.0",
        "result": "0x1234",
        "id": 1
      }
      """

      assert {:ok, response} = Encoding.decode_response(json)
      assert %Response.Success{} = response
      assert response.result == "0x1234"
      assert response.id == 1
      assert response.jsonrpc == "2.0"
    end

    test "decodes an error response" do
      json = """
      {
        "jsonrpc": "2.0",
        "error": {
          "code": -32700,
          "message": "Parse error"
        },
        "id": 1
      }
      """

      assert {:ok, response} = Encoding.decode_response(json)
      assert %Response.Error{} = response
      assert response.error.code == -32_700
      assert response.error.message == "Parse error"
      assert response.id == 1
      assert response.jsonrpc == "2.0"
    end

    test "decodes a batch response" do
      json = """
      [
        {
          "jsonrpc": "2.0",
          "result": "0x1234",
          "id": 1
        },
        {
          "jsonrpc": "2.0",
          "error": {
            "code": -32700,
            "message": "Parse error"
          },
          "id": 2
        }
      ]
      """

      assert {:ok, [response1, response2]} = Encoding.decode_response(json)

      assert %Response.Success{} = response1
      assert response1.result == "0x1234"
      assert response1.id == 1

      assert %Response.Error{} = response2
      assert response2.error.code == -32_700
      assert response2.error.message == "Parse error"
      assert response2.id == 2
    end

    test "decodes an empty batch response" do
      json = ~s([])
      assert {:ok, []} = Encoding.decode_response(json)
    end

    test "handles invalid JSON" do
      json = "invalid json"
      assert {:error, {:invalid_byte, _, _}} = Encoding.decode_response(json)
    end
  end

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
