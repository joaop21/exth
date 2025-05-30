defmodule Exth.Rpc.MessageHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Exth.AsyncTestTransport
  alias Exth.Rpc.MessageHandler
  alias Exth.Rpc.Request
  alias Exth.Rpc.Response
  alias Exth.Transport

  @rpc_url "wss://eth-mainnet.example.com"
  @call_timeout 5_000

  setup :verify_on_exit!

  describe "new/1" do
    test "creates a new handler with a unique name" do
      assert {:ok, handler} = MessageHandler.new(@rpc_url)
      assert is_atom(handler)
    end

    test "creates different handlers for different URLs" do
      {:ok, handler1} = MessageHandler.new(@rpc_url)
      {:ok, handler2} = MessageHandler.new("wss://eth-goerli.example.com")
      assert handler1 != handler2
    end

    test "returns error when creating handler with duplicate URL" do
      {:ok, _handler1} = MessageHandler.new(@rpc_url)
      assert {:error, {:already_started, _pid}} = MessageHandler.new(@rpc_url)
    end
  end

  describe "call/4" do
    setup do
      {:ok, handler} = MessageHandler.new(@rpc_url)

      transport =
        Transport.new(:websocket, rpc_url: @rpc_url, module: AsyncTestTransport)

      {:ok, handler: handler, transport: transport}
    end

    test "sends a single request and receives response", %{handler: handler, transport: transport} do
      request = Request.new("eth_blockNumber", [], 1)

      # Start a process to send the response
      spawn(fn ->
        Process.sleep(10)
        MessageHandler.handle_response(handler, JSON.encode!(%{id: 1, result: "0x1234"}))
      end)

      assert {:ok, %Response.Success{} = response} =
               MessageHandler.call(handler, request, transport, @call_timeout)

      assert response.id == 1
      assert response.result == "0x1234"
    end

    test "sends batch requests and receives responses", %{handler: handler, transport: transport} do
      requests = [
        Request.new("eth_blockNumber", [], 1),
        Request.new("eth_chainId", [], 2)
      ]

      spawn(fn ->
        Process.sleep(10)

        MessageHandler.handle_response(
          handler,
          JSON.encode!([
            %{id: 1, result: "0x1234"},
            %{id: 2, result: "0x5678"}
          ])
        )
      end)

      assert {:ok, [%Response.Success{} = response1, %Response.Success{} = response2]} =
               MessageHandler.call(handler, requests, transport, @call_timeout)

      assert response1.id == 1
      assert response1.result == "0x1234"
      assert response2.id == 2
      assert response2.result == "0x5678"
    end

    test "handles timeout", %{handler: handler, transport: transport} do
      request = Request.new("eth_blockNumber", [], 1)
      assert {:error, :timeout} = MessageHandler.call(handler, [request], transport, 10)
    end

    test "handles transport errors", %{handler: handler, transport: transport} do
      request = Request.new("eth_blockNumber", [], 1)

      expect(Transport, :call, fn _transport, _request ->
        {:error, :connection_refused}
      end)

      assert {:error, :connection_refused} =
               MessageHandler.call(handler, [request], transport, @call_timeout)
    end
  end

  describe "handle_response/2" do
    setup do
      {:ok, handler} = MessageHandler.new(@rpc_url)
      {:ok, handler: handler}
    end

    test "routes response to registered caller", %{handler: handler} do
      {:ok, _} = Registry.register(handler, 1, self())

      assert :ok =
               MessageHandler.handle_response(handler, JSON.encode!(%{id: 1, result: "0x1234"}))

      assert_receive {_ref, %Response.Success{id: 1, result: "0x1234"}}
    end

    test "handles orphaned responses", %{handler: handler} do
      assert :error =
               MessageHandler.handle_response(handler, JSON.encode!(%{id: 1, result: "0x1234"}))
    end

    test "handles invalid JSON", %{handler: handler} do
      assert :error = MessageHandler.handle_response(handler, "invalid json")
    end

    test "handles error responses", %{handler: handler} do
      response = %{
        id: 1,
        error: %{code: -32_601, message: "Method not found"}
      }

      {:ok, _} = Registry.register(handler, 1, self())

      assert :ok = MessageHandler.handle_response(handler, JSON.encode!(response))

      assert_receive {_ref,
                      %Response.Error{id: 1, error: %{code: -32_601, message: "Method not found"}}}
    end
  end
end
