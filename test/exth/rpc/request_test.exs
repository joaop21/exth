defmodule Exth.Rpc.RequestTest do
  use ExUnit.Case, async: true

  alias Exth.Rpc.Request

  describe "new/2" do
    test "creates a request without an id" do
      method = "eth_getBalance"
      params = ["0x123", "latest"]

      request = Request.new(method, params)

      assert %Request{} = request
      assert request.method == method
      assert request.params == params
      assert is_nil(request.id)
      assert request.jsonrpc == "2.0"
    end
  end

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

    test "accepts atom as method but transforms to string" do
      request = Request.new(:eth_getBalance, [], 1)
      assert request.method == "eth_getBalance"
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

  describe "serialize/1" do
    test "encodes requests with various parameter types" do
      test_cases = [
        {build_request("eth_blockNumber"), []},
        {build_request("eth_getBalance", ["0x123", "latest"]), ["0x123", "latest"]},
        {build_request("eth_call", [%{"to" => "0x123"}]), [%{"to" => "0x123"}]},
        {build_request("eth_getLogs", [[1, 2, 3]]), [[1, 2, 3]]},
        {build_request("test_method", [true, 42, "string"]), [true, 42, "string"]}
      ]

      for {request, expected_params} <- test_cases do
        assert {:ok, json} = Request.serialize(request)
        assert {:ok, decoded} = JSON.decode(json)
        assert_valid_jsonrpc(decoded)
        assert decoded["method"] == request.method
        assert decoded["params"] == expected_params
        assert decoded["id"] == request.id
      end
    end

    test "encodes batch requests with different sizes" do
      test_cases = [
        [build_request("method1")],
        [build_request("method1"), build_request("method2", [], 2)],
        [
          build_request("method1"),
          build_request("method2", ["param"], 2),
          build_request("method3", [%{"key" => "value"}], 3)
        ]
      ]

      for requests <- test_cases do
        assert {:ok, json} = Request.serialize(requests)
        assert {:ok, decoded} = JSON.decode(json)
        assert length(decoded) == length(requests)
        assert_valid_jsonrpc(decoded)

        Enum.zip(requests, decoded)
        |> Enum.each(fn {req, dec} ->
          assert dec["method"] == req.method
          assert dec["params"] == req.params
          assert dec["id"] == req.id
        end)
      end
    end

    test "encodes a single request" do
      request = %Request{
        method: "eth_blockNumber",
        params: [],
        id: 1
      }

      assert {:ok, json} = Request.serialize(request)
      assert {:ok, decoded} = JSON.decode(json)

      assert decoded == %{
               "jsonrpc" => "2.0",
               "method" => "eth_blockNumber",
               "params" => [],
               "id" => 1
             }
    end

    test "encodes a request with params" do
      request = %Request{
        method: "eth_getBalance",
        params: ["0x123", "latest"],
        id: 2
      }

      assert {:ok, json} = Request.serialize(request)
      assert {:ok, decoded} = JSON.decode(json)

      assert decoded == %{
               "jsonrpc" => "2.0",
               "method" => "eth_getBalance",
               "params" => ["0x123", "latest"],
               "id" => 2
             }
    end

    test "encodes a batch of requests" do
      requests = [
        %Request{method: "eth_blockNumber", params: [], id: 1},
        %Request{method: "eth_gasPrice", params: [], id: 2}
      ]

      assert {:ok, json} = Request.serialize(requests)
      assert {:ok, decoded} = JSON.decode(json)

      assert decoded == [
               %{
                 "jsonrpc" => "2.0",
                 "method" => "eth_blockNumber",
                 "params" => [],
                 "id" => 1
               },
               %{
                 "jsonrpc" => "2.0",
                 "method" => "eth_gasPrice",
                 "params" => [],
                 "id" => 2
               }
             ]
    end
  end

  defp build_request(method, params \\ [], id \\ 1) do
    Request.new(method, params, id)
  end

  defp assert_valid_jsonrpc(decoded) when is_map(decoded) do
    assert decoded["jsonrpc"] == "2.0"
  end

  defp assert_valid_jsonrpc(decoded) when is_list(decoded) do
    Enum.each(decoded, &assert_valid_jsonrpc/1)
  end
end
