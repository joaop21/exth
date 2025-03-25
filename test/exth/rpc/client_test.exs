defmodule Exth.Rpc.ClientTest do
  use ExUnit.Case, async: true

  alias Exth.Rpc.Client
  alias Exth.Rpc.Request
  alias Exth.Rpc.Response
  alias Exth.Transport.Http
  alias Exth.TestTransport
  alias Exth.TransportErrorTestTransport

  @valid_url "http://localhost:8545"
  @test_address "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
  @test_methods [
    "eth_blockNumber",
    "eth_chainId",
    "eth_gasPrice",
    "eth_getBalance"
  ]

  describe "new/2" do
    test "creates a new client with HTTP transport" do
      client = Client.new(:http, rpc_url: @valid_url)
      assert %Client{} = client
      assert client.counter != nil
      assert %Http{} = client.transport
    end

    test "fails to create client with invalid URL" do
      assert_raise ArgumentError,
                   "Invalid RPC URL format: \"not-a-url\"\nThe URL must:\n  - Start with http:// or https://\n  - Contain a valid host\n",
                   fn ->
                     Client.new(:http, rpc_url: "not-a-url")
                   end
    end

    test "fails to create client without URL" do
      assert_raise ArgumentError, "missing required option :rpc_url", fn ->
        Client.new(:http, [])
      end
    end

    test "creates a new client with custom transport" do
      client = Client.new(:custom, module: TestTransport, rpc_url: @valid_url)
      assert %Client{} = client
      assert client.counter != nil
      assert client.transport != nil
    end

    test "raises error for invalid transport type" do
      assert_raise FunctionClauseError, fn ->
        Client.new(:invalid, rpc_url: "http://localhost:8545")
      end
    end
  end

  describe "request/3" do
    setup do
      client = Client.new(:http, rpc_url: "http://localhost:8545")
      {:ok, client: client}
    end

    test "creates a request with string method", %{client: client} do
      request = Client.request(client, "eth_blockNumber", [])
      assert %Request{} = request
      assert request.method == "eth_blockNumber"
      assert request.params == []
      assert request.id > 0
      assert request.jsonrpc == "2.0"
    end

    test "creates a request with atom method", %{client: client} do
      request = Client.request(client, :eth_blockNumber, [])
      assert %Request{} = request
      assert request.method == :eth_blockNumber
      assert request.params == []
      assert request.id > 0
      assert request.jsonrpc == "2.0"
    end

    test "generates unique IDs for multiple requests", %{client: client} do
      request1 = Client.request(client, "eth_blockNumber", [])
      request2 = Client.request(client, "eth_blockNumber", [])
      request3 = Client.request(client, "eth_blockNumber", [])

      assert request1.id != request2.id
      assert request2.id != request3.id
      assert request1.id != request3.id
    end

    test "handles various parameter types", %{client: client} do
      params = [
        "0x123",
        123,
        true,
        %{key: "value"},
        ["0x456", false]
      ]

      request = Client.request(client, "eth_call", params)
      assert request.params == params
    end
  end

  describe "send/2" do
    setup do
      client = Client.new(:custom, module: TestTransport, rpc_url: @valid_url)
      {:ok, client: client}
    end

    test "sends single requests successfully", %{client: client} do
      for method <- @test_methods do
        params = if method == "eth_getBalance", do: [@test_address, "latest"], else: []
        request = Client.request(client, method, params)

        assert {:ok, response} = Client.send(client, request)
        assert %Response.Success{} = response
        assert response.result =~ ~r/^0x[0-9a-f]+$/
        assert response.id == request.id
      end
    end

    test "handles error responses", %{client: client} do
      request = Client.request(client, "invalid_method", [])
      assert {:ok, response} = Client.send(client, request)
      assert %Response.Error{} = response
      assert response.error.code == -32601
      assert response.error.message == "Method not found"
    end

    test "handles transport errors" do
      client = Client.new(:custom, module: TransportErrorTestTransport, rpc_url: @valid_url)
      request = Client.request(client, "eth_blockNumber", [])
      assert {:error, error} = Client.send(client, request)
      assert error.message == "connection_refused"
    end

    test "sends batch requests successfully", %{client: client} do
      requests =
        Enum.map(@test_methods, fn method ->
          params = if method == "eth_getBalance", do: [@test_address, "latest"], else: []
          Client.request(client, method, params)
        end)

      assert {:ok, responses} = Client.send(client, requests)
      assert length(responses) == length(requests)

      Enum.zip(requests, responses)
      |> Enum.each(fn {request, response} ->
        assert %Response.Success{} = response
        assert response.id == request.id
        assert response.result =~ ~r/^0x[0-9a-f]+$/
      end)
    end

    test "handles concurrent requests", %{client: client} do
      tasks =
        Enum.map(@test_methods, fn method ->
          Task.async(fn ->
            params = if method == "eth_getBalance", do: [@test_address, "latest"], else: []
            request = Client.request(client, method, params)
            Client.send(client, request)
          end)
        end)

      results = Task.await_many(tasks, 5000)

      Enum.each(results, fn {:ok, response} ->
        assert %Response.Success{} = response
        assert response.result =~ ~r/^0x[0-9a-f]+$/
      end)
    end

    test "handles mixed success/error batch responses", %{client: client} do
      requests = [
        Client.request(client, "eth_blockNumber", []),
        Client.request(client, "invalid_method", [])
      ]

      assert {:ok, [success, error]} = Client.send(client, requests)

      assert %Response.Success{} = success
      assert success.result =~ ~r/^0x[0-9a-f]+$/
      assert success.id == hd(requests).id

      assert %Response.Error{} = error
      assert error.error.code == -32601
      assert error.error.message == "Method not found"
      assert error.id == List.last(requests).id
    end

    test "handles empty batch requests", %{client: client} do
      assert {:ok, []} = Client.send(client, [])
    end

    test "validates request input", %{client: client} do
      assert_raise Protocol.UndefinedError, fn ->
        Client.send(client, nil)
      end

      assert_raise Protocol.UndefinedError, fn ->
        Client.send(client, "not_a_request")
      end
    end
  end
end
