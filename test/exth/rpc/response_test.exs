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
      code = -32600
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
      code = -32600
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
        {1, -32600, "error", nil},
        {"1", -32601, "error", "details"},
        {"abc", -32603, "error", ["detail1", "detail2"]}
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
        Response.error(nil, -32602, "error", %{reason: "invalid"})
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
end
