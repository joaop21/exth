defmodule Exth.Rpc.ClientTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Exth.AsyncTestTransport
  alias Exth.Rpc.Call
  alias Exth.Rpc.Client
  alias Exth.Rpc.MessageHandler
  alias Exth.Rpc.Request
  alias Exth.Rpc.Response
  alias Exth.TestTransport
  alias Exth.Transport.Http
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

    test "creates a new client with WebSocket transport" do
      client = Client.new(:websocket, rpc_url: @valid_url, module: AsyncTestTransport)
      assert %Client{} = client
      assert client.counter != nil
      assert client.transport != nil
      assert client.handler != nil
      assert Process.whereis(client.handler)
    end

    test "fails to create WebSocket client without URL" do
      assert_raise ArgumentError, "missing required option :rpc_url", fn ->
        Client.new(:websocket, [])
      end
    end

    test "fails to create client with invalid transport type" do
      assert_raise FunctionClauseError, fn ->
        Client.new(:invalid, rpc_url: "http://localhost:8545")
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
  end

  describe "request/3" do
    setup do
      client = Client.new(:http, rpc_url: "http://localhost:8545")
      {:ok, client: client}
    end

    test "creates an RPC call  with string method", %{client: client} do
      rpc_call = Client.request(client, "eth_blockNumber", [])
      assert %Call{} = rpc_call
      request = rpc_call |> Call.get_requests() |> hd()
      assert request.method == "eth_blockNumber"
      assert request.params == []
      assert request.id > 0
      assert request.jsonrpc == "2.0"
    end

    test "creates an RPC call with atom method", %{client: client} do
      rpc_call = Client.request(client, :eth_blockNumber, [])
      assert %Call{} = rpc_call
      request = rpc_call |> Call.get_requests() |> hd()
      assert request.method == "eth_blockNumber"
      assert request.params == []
      assert request.id > 0
      assert request.jsonrpc == "2.0"
    end

    test "generates unique IDs for multiple requests", %{client: client} do
      rpc_call =
        client
        |> Client.request("eth_blockNumber", [])
        |> Client.request("eth_blockNumber", [])
        |> Client.request("eth_blockNumber", [])

      requests = rpc_call |> Call.get_requests() |> Enum.map(& &1.id) |> Enum.uniq()

      assert length(requests) == 3
    end

    test "handles various parameter types", %{client: client} do
      params = [
        "0x123",
        123,
        true,
        %{key: "value"},
        ["0x456", false]
      ]

      rpc_call = Client.request(client, "eth_call", params)
      request = rpc_call |> Call.get_requests() |> hd()
      assert request.params == params
    end
  end

  describe "send/1" do
    setup do
      client = Client.new(:custom, module: TestTransport, rpc_url: @valid_url)
      {:ok, client: client}
    end

    test "sends a single request from a call", %{client: client} do
      call = client |> Client.request("eth_blockNumber", [])
      assert {:ok, response} = Client.send(call)
      assert %Response.Success{} = response
      assert response.result =~ ~r/^0x[0-9a-f]+$/
      assert is_integer(response.id)
    end

    test "sends multiple requests from a call as batch", %{client: client} do
      call =
        client
        |> Client.request("eth_blockNumber", [])
        |> Client.request("eth_chainId", [])
        |> Client.request("eth_gasPrice", [])

      assert {:ok, responses} = Client.send(call)
      assert length(responses) == 3
      assert Enum.all?(responses, &match?(%Response.Success{}, &1))
      assert Enum.all?(responses, &(&1.result =~ ~r/^0x[0-9a-f]+$/))
    end

    test "handles error responses in batch", %{client: client} do
      call =
        client
        |> Client.request("eth_blockNumber", [])
        |> Client.request("invalid_method", [])

      assert {:ok, [success, error]} = Client.send(call)
      assert %Response.Success{} = success
      assert %Response.Error{} = error
      assert error.error.code == -32_601
      assert error.error.message == "Method not found"
    end

    test "handles transport errors" do
      error_client = Client.new(:custom, module: TransportErrorTestTransport, rpc_url: @valid_url)
      call = error_client |> Client.request("eth_blockNumber", [])
      assert {:error, error} = Client.send(call)
      assert error.message == "connection_refused"
    end

    test "handles empty call", %{client: client} do
      call = %Call{client: client, requests: []}
      assert {:ok, []} = Client.send(call)
    end

    test "generates unique IDs for multiple requests in batch", %{client: client} do
      call =
        client
        |> Client.request("eth_blockNumber", [])
        |> Client.request("eth_chainId", [])
        |> Client.request("eth_gasPrice", [])

      assert {:ok, responses} = Client.send(call)
      ids = Enum.map(responses, & &1.id)
      assert length(Enum.uniq(ids)) == 3
    end

    test "handles batch requests with pre-assigned IDs", %{client: client} do
      request1 = Request.new("eth_blockNumber", [], 42)
      request2 = Request.new("eth_chainId", [], 43)
      call = %Call{client: client, requests: [request1, request2]}

      assert {:ok, responses} = Client.send(call)
      assert length(responses) == 2
      assert Enum.map(responses, & &1.id) == [42, 43]
    end

    test "detects duplicate IDs in batch requests", %{client: client} do
      request1 = Request.new("eth_blockNumber", [], 42)
      request2 = Request.new("eth_chainId", [], 42)
      call = %Call{client: client, requests: [request1, request2]}

      assert {:error, :duplicate_ids} = Client.send(call)
    end

    test "assigns unique IDs to nil ID requests in batch", %{client: client} do
      request1 = Request.new("eth_blockNumber", [])
      request2 = Request.new("eth_chainId", [])
      request3 = Request.new("eth_gasPrice", [], 42)
      call = %Call{client: client, requests: [request1, request2, request3]}

      assert {:ok, responses} = Client.send(call)
      ids = Enum.map(responses, & &1.id)
      assert length(Enum.uniq(ids)) == 3
      assert 42 in ids
    end

    test "preserves existing IDs while assigning new ones in batch", %{client: client} do
      request1 = Request.new("eth_blockNumber", [], 42)
      request2 = Request.new("eth_chainId", [])
      request3 = Request.new("eth_gasPrice", [])
      call = %Call{client: client, requests: [request1, request2, request3]}

      assert {:ok, responses} = Client.send(call)
      ids = Enum.map(responses, & &1.id)
      assert length(Enum.uniq(ids)) == 3
      assert 42 in ids
      assert Enum.all?(ids -- [42], &(&1 != 42))
    end
  end

  describe "send/2" do
    setup do
      client = Client.new(:custom, module: TestTransport, rpc_url: @valid_url)
      {:ok, client: client}
    end

    test "accepts request first, client second", %{client: client} do
      request = Request.new("eth_blockNumber", [])
      assert {:ok, response} = Client.send(request, client)
      assert %Response.Success{} = response
      assert response.result =~ ~r/^0x[0-9a-f]+$/
      assert is_integer(response.id)
    end

    test "accepts requests list first, client second", %{client: client} do
      requests = [
        Request.new("eth_blockNumber", []),
        Request.new("eth_chainId", [])
      ]

      assert {:ok, responses} = Client.send(requests, client)
      assert length(responses) == 2
      assert Enum.all?(responses, &match?(%Response.Success{}, &1))
    end

    test "handles batch requests with pre-assigned IDs", %{client: client} do
      requests = [
        Request.new("eth_blockNumber", [], 42),
        Request.new("eth_chainId", [], 43)
      ]

      assert {:ok, responses} = Client.send(client, requests)
      assert length(responses) == 2
      assert Enum.map(responses, & &1.id) == [42, 43]
    end

    test "detects duplicate IDs in batch requests", %{client: client} do
      requests = [
        Request.new("eth_blockNumber", [], 42),
        Request.new("eth_chainId", [], 42)
      ]

      assert {:error, :duplicate_ids} = Client.send(client, requests)
    end

    test "assigns unique IDs to nil ID requests in batch", %{client: client} do
      requests = [
        Request.new("eth_blockNumber", []),
        Request.new("eth_chainId", []),
        Request.new("eth_gasPrice", [], 42)
      ]

      assert {:ok, responses} = Client.send(client, requests)

      ids = Enum.map(responses, & &1.id)
      assert length(Enum.uniq(ids)) == 3
      assert 42 in ids
    end

    test "preserves existing IDs while assigning new ones in batch", %{client: client} do
      requests = [
        Request.new("eth_blockNumber", [], 42),
        Request.new("eth_chainId", []),
        Request.new("eth_gasPrice", [])
      ]

      assert {:ok, responses} = Client.send(client, requests)

      ids = Enum.map(responses, & &1.id)
      assert length(Enum.uniq(ids)) == 3
      assert 42 in ids
      assert Enum.all?(ids -- [42], &(&1 != 42))
    end

    test "sends single requests successfully", %{client: client} do
      for method <- @test_methods do
        params = if method == "eth_getBalance", do: [@test_address, "latest"], else: []
        request = Request.new(method, params)

        assert {:ok, response} = Client.send(client, request)
        assert %Response.Success{} = response
        assert response.result =~ ~r/^0x[0-9a-f]+$/
        assert is_integer(response.id)
      end
    end

    test "handles error responses", %{client: client} do
      request = Request.new("invalid_method", [])
      assert {:ok, response} = Client.send(client, request)
      assert %Response.Error{} = response
      assert response.error.code == -32_601
      assert response.error.message == "Method not found"
    end

    test "handles transport errors" do
      client = Client.new(:custom, module: TransportErrorTestTransport, rpc_url: @valid_url)
      request = Request.new("eth_blockNumber", [])
      assert {:error, error} = Client.send(client, request)
      assert error.message == "connection_refused"
    end

    test "sends batch requests successfully", %{client: client} do
      requests =
        Enum.map(@test_methods, fn method ->
          params = if method == "eth_getBalance", do: [@test_address, "latest"], else: []
          Request.new(method, params)
        end)

      assert {:ok, responses} = Client.send(client, requests)
      assert length(responses) == length(requests)

      Enum.each(responses, fn response ->
        assert %Response.Success{} = response
        assert is_integer(response.id)
        assert response.result =~ ~r/^0x[0-9a-f]+$/
      end)
    end

    test "handles concurrent requests", %{client: client} do
      tasks =
        Enum.map(@test_methods, fn method ->
          Task.async(fn ->
            params = if method == "eth_getBalance", do: [@test_address, "latest"], else: []
            request = Request.new(method, params)
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
        Request.new("eth_blockNumber", [], 1),
        Request.new("invalid_method", [], 2)
      ]

      assert {:ok, [success, error]} = Client.send(client, requests)

      assert %Response.Success{} = success
      assert success.result =~ ~r/^0x[0-9a-f]+$/
      assert success.id == hd(requests).id

      assert %Response.Error{} = error
      assert error.error.code == -32_601
      assert error.error.message == "Method not found"
      assert error.id == List.last(requests).id
    end

    test "handles empty batch requests", %{client: client} do
      assert {:ok, []} = Client.send(client, [])
    end

    test "validates request input", %{client: client} do
      assert_raise FunctionClauseError, fn ->
        Client.send(client, nil)
      end

      assert_raise FunctionClauseError, fn ->
        Client.send(client, "not_a_request")
      end
    end
  end

  describe "send/2 with WebSocket transport" do
    setup do
      client = Client.new(:websocket, rpc_url: @valid_url, module: AsyncTestTransport)

      on_exit(fn ->
        if pid = Process.whereis(client.handler) do
          Process.exit(pid, :normal)
        end
      end)

      {:ok, client: client}
    end

    test "sends a single request through handler", %{client: client} do
      request = Request.new("eth_blockNumber", [], 1)
      response = %Response.Success{id: 1, result: "0x1234"}

      expect(MessageHandler, :call, fn _, [^request], _ -> {:ok, [response]} end)

      assert {:ok, ^response} = Client.send(client, request)
    end

    test "sends batch requests through handler", %{client: client} do
      requests = [
        Request.new("eth_blockNumber", [], 1),
        Request.new("eth_chainId", [], 2)
      ]

      responses = [
        %Response.Success{id: 1, result: "0x1234"},
        %Response.Success{id: 2, result: "0x5678"}
      ]

      expect(MessageHandler, :call, fn _, ^requests, _ -> {:ok, responses} end)

      assert {:ok, ^responses} = Client.send(client, requests)
    end
  end
end
