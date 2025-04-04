defmodule Exth.Rpc.RequestTest do
  use ExUnit.Case, async: true

  alias Exth.Rpc.Request

  describe "new/3" do
    test "creates a request with all fields" do
      method = "eth_getBalance"
      params = ["0x123", "latest"]
      id = 1

      request = Request.new(method, params, id)

      assert %Request{} = request
      assert request.method == method
      assert request.params == params
      assert request.id == id
      assert request.jsonrpc == "2.0"
    end

    test "creates a request with empty params" do
      method = "eth_blockNumber"
      params = []
      id = 1

      request = Request.new(method, params, id)

      assert request.method == method
      assert request.params == []
      assert request.id == id
    end

    test "accepts atom as method" do
      request = Request.new(:eth_getBalance, [], 1)
      assert request.method == :eth_getBalance
    end

    test "raises when method is invalid" do
      invalid_methods = [
        nil,
        123,
        %{},
        [],
        true,
        "",
        "   "
      ]

      for method <- invalid_methods do
        assert_raise ArgumentError, ~r/invalid method/i, fn ->
          Request.new(method, [], 1)
        end
      end
    end

    test "raises when id is not a positive integer" do
      invalid_ids = [
        0,
        -1,
        "1",
        1.5,
        true,
        [],
        %{}
      ]

      for id <- invalid_ids do
        assert_raise ArgumentError, ~r/invalid id/i, fn ->
          Request.new("eth_call", [], id)
        end
      end
    end

    test "raises when params is not a list" do
      invalid_params = [
        nil,
        "string",
        123,
        true,
        %{},
        MapSet.new()
      ]

      for params <- invalid_params do
        assert_raise ArgumentError, ~r/invalid params/i, fn ->
          Request.new("eth_call", params, 1)
        end
      end
    end

    test "accepts various types within params list" do
      valid_params = [
        [],
        [1, "string", true, %{}, [1, 2, 3]],
        ["0x123", "latest"],
        [%{key: "value"}]
      ]

      for params <- valid_params do
        request = Request.new("eth_call", params, 1)
        assert request.params == params
      end
    end
  end

  describe "struct definition" do
    test "has default values" do
      request = %Request{}
      assert request.params == []
      assert request.jsonrpc == "2.0"
      assert request.id == nil
      assert request.method == nil
    end
  end
end
