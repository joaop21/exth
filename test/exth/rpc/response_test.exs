defmodule Exth.Rpc.ResponseTest do
  use ExUnit.Case, async: true

  alias Exth.Rpc.Response

  describe "success/2" do
    test "creates a success response with default jsonrpc version" do
      id = 1
      result = "0x1234"
      response = Response.success(id, result)

      assert %Response.Success{} = response
      assert response.id == id
      assert response.result == result
      assert response.jsonrpc == "2.0"
    end

    test "handles different valid id types" do
      test_cases = [
        {1, "0x1"},
        {"1", "0x1"},
        {"abc", "0x1"}
      ]

      for {id, result} <- test_cases do
        response = Response.success(id, result)
        assert %Response.Success{id: ^id, result: ^result} = response
      end
    end

    test "raises when id is nil" do
      assert_raise FunctionClauseError, fn ->
        Response.success(nil, "0x1")
      end
    end
  end

  describe "error/3,4" do
    test "creates an error response with required fields" do
      id = 1
      code = -32_600
      message = "Invalid Request"
      response = Response.error(id, code, message)

      assert %Response.Error{} = response
      assert response.id == id
      assert response.error.code == code
      assert response.error.message == message
      assert response.error.data == nil
      assert response.jsonrpc == "2.0"
    end

    test "creates an error response with optional data" do
      id = 1
      code = -32_600
      message = "Invalid Request"
      data = %{details: "Missing required field"}
      response = Response.error(id, code, message, data)

      assert %Response.Error{} = response
      assert response.id == id
      assert response.error.code == code
      assert response.error.message == message
      assert response.error.data == data
    end

    test "handles different id and data types" do
      test_cases = [
        {1, -32_600, "error", nil},
        {"1", -32_601, "error", "details"},
        {"abc", -32_603, "error", ["detail1", "detail2"]}
      ]

      for {id, code, message, data} <- test_cases do
        response = Response.error(id, code, message, data)

        assert %Response.Error{
                 id: ^id,
                 error: %{code: ^code, message: ^message, data: ^data}
               } = response
      end
    end

    test "raises when id is nil" do
      assert_raise FunctionClauseError, fn ->
        Response.error(nil, -32_602, "error", %{reason: "invalid"})
      end
    end
  end

  describe "type definitions" do
    test "Success struct has correct fields" do
      success = %Response.Success{}
      expected_fields = MapSet.new([:__struct__, :id, :jsonrpc, :result])
      actual_fields = MapSet.new(Map.keys(success))
      assert expected_fields == actual_fields
    end

    test "Error struct has correct fields" do
      error = %Response.Error{}
      expected_fields = MapSet.new([:__struct__, :id, :jsonrpc, :error])
      actual_fields = MapSet.new(Map.keys(error))
      assert expected_fields == actual_fields
    end
  end

  describe "deserialize/1" do
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

        assert {:ok, response} = Response.deserialize(json)
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

        assert {:ok, response} = Response.deserialize(json)
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
        assert {:error, _reason} = Response.deserialize(invalid_json)
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
        assert {:ok, decoded} = Response.deserialize(json)
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

      assert {:ok, response} = Response.deserialize(json)
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

      assert {:ok, response} = Response.deserialize(json)
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

      assert {:ok, [response1, response2]} = Response.deserialize(json)

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
      assert {:ok, []} = Response.deserialize(json)
    end

    test "handles invalid JSON" do
      json = "invalid json"
      assert {:error, {:invalid_byte, _, _}} = Response.deserialize(json)
    end
  end
end
