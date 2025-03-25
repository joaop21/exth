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

    test "accepts different id types" do
      test_cases = [
        {1, "eth_getBalance", ["0x123"]},
        {"1", "eth_blockNumber", []},
        {"abc-123", "eth_chainId", []}
      ]

      for {id, method, params} <- test_cases do
        request = Request.new(method, params, id)
        assert %Request{id: ^id} = request
      end
    end

    test "accepts different param types" do
      test_cases = [
        {["0x123", "latest"], "eth_getBalance"},
        {[1, 2, 3], "test_method"},
        {[%{key: "value"}], "test_complex"},
        {[], "eth_blockNumber"}
      ]

      for {params, method} <- test_cases do
        request = Request.new(method, params, 1)
        assert %Request{params: ^params} = request
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
