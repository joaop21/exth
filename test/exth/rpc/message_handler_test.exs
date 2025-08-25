defmodule Exth.Rpc.MessageHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Exth.AsyncTestTransport
  alias Exth.Rpc.MessageHandler
  alias Exth.Rpc.Request
  alias Exth.Rpc.Response
  alias Exth.Transport

  @base_url "wss://eth-mainnet.example.com"
  @call_timeout 5_000

  setup :verify_on_exit!

  describe "new/1" do
    setup %{test: test_name} do
      rpc_url = "#{@base_url}/#{test_name}"
      {:ok, handler} = MessageHandler.new(rpc_url)

      on_exit(:kill_handler, fn ->
        if pid = Process.whereis(handler) do
          Process.exit(pid, :normal)
        end
      end)

      %{handler: handler, rpc_url: rpc_url}
    end

    test "creates a new handler with a unique name", %{handler: handler} do
      assert is_atom(handler)
    end

    test "creates different handlers for different URLs", %{handler: handler} do
      {:ok, another_handler} = MessageHandler.new("wss://eth-goerli.example.com")
      assert handler != another_handler
    end

    test "returns error when creating handler with duplicate URL", %{rpc_url: rpc_url} do
      assert {:error, {:already_started, _pid}} = MessageHandler.new(rpc_url)
    end
  end

  describe "call/4" do
    setup %{test: test_name} do
      rpc_url = "#{@base_url}/#{test_name}"
      {:ok, handler} = MessageHandler.new(rpc_url)

      {:ok, transport} =
        Transport.new(:custom, rpc_url: rpc_url, module: AsyncTestTransport)

      on_exit(:kill_handler, fn ->
        if pid = Process.whereis(handler) do
          Process.exit(pid, :normal)
        end
      end)

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

      expect(Transport, :request, fn _transport, _request ->
        {:error, :connection_refused}
      end)

      assert {:error, :connection_refused} =
               MessageHandler.call(handler, [request], transport, @call_timeout)
    end
  end

  describe "handle_response/2" do
    setup %{test: test_name} do
      rpc_url = "#{@base_url}/#{test_name}"
      {:ok, handler} = MessageHandler.new(rpc_url)

      on_exit(:kill_handler, fn ->
        if pid = Process.whereis(handler) do
          Process.exit(pid, :normal)
        end
      end)

      {:ok, handler: handler}
    end

    test "routes response to registered caller", %{handler: handler} do
      {:ok, _} = Registry.register(handler, "1", self())

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

      {:ok, _} = Registry.register(handler, "1", self())

      assert :ok = MessageHandler.handle_response(handler, JSON.encode!(response))

      assert_receive {_ref,
                      %Response.Error{id: 1, error: %{code: -32_601, message: "Method not found"}}}
    end
  end

  describe "subscriptions" do
    setup %{test: test_name} do
      rpc_url = "#{@base_url}/#{test_name}"
      {:ok, handler} = MessageHandler.new(rpc_url)

      {:ok, transport} =
        Transport.new(:websocket, rpc_url: rpc_url, module: AsyncTestTransport)

      on_exit(:kill_handler, fn ->
        if pid = Process.whereis(handler) do
          Process.exit(pid, :normal)
        end
      end)

      {:ok, handler: handler, transport: transport}
    end

    test "creates a subscription", %{handler: handler, transport: transport} do
      request = Request.new("eth_subscribe", ["newHeads"], 1)

      # Start a process to send the response
      spawn(fn ->
        Process.sleep(10)
        MessageHandler.handle_response(handler, JSON.encode!(%{id: 1, result: "0x1234"}))
      end)

      assert {:ok, [%Response.Success{} = response]} =
               MessageHandler.call(handler, [request], transport, @call_timeout)

      assert response.id == 1
      assert response.result == "0x1234"
    end

    test "handles subscription events", %{handler: handler} do
      # Register a subscription
      {:ok, _} = Registry.register(handler, "0x1234", self())

      # Send a subscription event
      event = %{
        "jsonrpc" => "2.0",
        "method" => "eth_subscription",
        "params" => %{
          "subscription" => "0x1234",
          "result" => %{"number" => "0x5678"}
        }
      }

      assert :ok = MessageHandler.handle_response(handler, JSON.encode!(event))

      assert_receive %Response.SubscriptionEvent{
        method: "eth_subscription",
        params: %{
          subscription: "0x1234",
          result: %{"number" => "0x5678"}
        }
      }
    end

    test "handles invalid subscription events", %{handler: handler} do
      invalid_events = [
        # Missing method
        %{
          "jsonrpc" => "2.0",
          "params" => %{
            "subscription" => "0x1234",
            "result" => %{"number" => "0x5678"}
          }
        },
        # Missing params
        %{
          "jsonrpc" => "2.0",
          "method" => "eth_subscription"
        },
        # Missing subscription ID
        %{
          "jsonrpc" => "2.0",
          "method" => "eth_subscription",
          "params" => %{
            "result" => %{"number" => "0x5678"}
          }
        },
        # Wrong method
        %{
          "jsonrpc" => "2.0",
          "method" => "wrong_method",
          "params" => %{
            "subscription" => "0x1234",
            "result" => %{"number" => "0x5678"}
          }
        }
      ]

      for event <- invalid_events do
        assert :error = MessageHandler.handle_response(handler, JSON.encode!(event))
      end
    end

    test "handles orphaned subscription events", %{handler: handler} do
      event = %{
        "jsonrpc" => "2.0",
        "method" => "eth_subscription",
        "params" => %{
          "subscription" => "0x1234",
          "result" => %{"number" => "0x5678"}
        }
      }

      assert :ok = MessageHandler.handle_response(handler, JSON.encode!(event))
    end

    test "rejects batch subscription requests", %{handler: handler, transport: transport} do
      requests = [
        Request.new("eth_subscribe", ["newHeads"], 1),
        Request.new("eth_subscribe", ["logs"], 2)
      ]

      assert {:error, :subscription_batch_not_supported} =
               MessageHandler.call(handler, requests, transport, @call_timeout)
    end

    test "unsubscribes from a subscription", %{handler: handler, transport: transport} do
      subscription_id = "0x1234"

      # First subscribe
      {:ok, _} = Registry.register(handler, subscription_id, self())

      # Then unsubscribe
      unsubscribe_request = Request.new("eth_unsubscribe", [subscription_id], 2)

      # Start a process to send the response
      spawn(fn ->
        Process.sleep(100)
        MessageHandler.handle_response(handler, JSON.encode!(%{id: 2, result: true}))
      end)

      assert {:ok, [%Response.Success{} = response]} =
               MessageHandler.call(handler, [unsubscribe_request], transport, @call_timeout)

      assert response.id == 2
      assert response.result == true

      # Verify the subscription is unregistered
      assert [] = Registry.lookup(handler, subscription_id)
    end

    test "handles failed unsubscribe", %{handler: handler, transport: transport} do
      # First subscribe
      # subscribe_request = Request.new("eth_subscribe", ["newHeads"], 1)
      {:ok, _} = Registry.register(handler, "0x1234", self())

      # Try to unsubscribe with wrong ID
      unsubscribe_request = Request.new("eth_unsubscribe", ["wrong_id"], 2)

      # Start a process to send the response
      spawn(fn ->
        Process.sleep(10)
        MessageHandler.handle_response(handler, JSON.encode!(%{id: 2, result: false}))
      end)

      assert {:ok, [%Response.Success{} = response]} =
               MessageHandler.call(handler, [unsubscribe_request], transport, @call_timeout)

      assert response.id == 2
      assert response.result == false

      # Verify the original subscription is still registered
      assert [{_pid, _value}] = Registry.lookup(handler, "0x1234")
    end

    test "handles unsubscribe for non-existent subscription", %{
      handler: handler,
      transport: transport
    } do
      unsubscribe_request = Request.new("eth_unsubscribe", ["0x1234"], 1)

      # Start a process to send the response
      spawn(fn ->
        Process.sleep(10)
        MessageHandler.handle_response(handler, JSON.encode!(%{id: 1, result: false}))
      end)

      assert {:ok, [%Response.Success{} = response]} =
               MessageHandler.call(handler, [unsubscribe_request], transport, @call_timeout)

      assert response.id == 1
      assert response.result == false
    end
  end
end
