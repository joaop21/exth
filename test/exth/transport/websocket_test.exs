defmodule Exth.Transport.WebsocketTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Exth.Transport.Websocket

  @valid_ws_url "ws://localhost:8545"
  @valid_wss_url "wss://localhost:8545"

  setup :verify_on_exit!

  describe "init_transport/2 - transport initialization" do
    setup do
      %{
        transport_opts: [rpc_url: @valid_ws_url, dispatch_callback: fn arg -> arg end],
        opts: []
      }
    end

    test "creates transport with valid options", %{transport_opts: transport_opts, opts: opts} do
      expect(Websocket.DynamicSupervisor, :start_websocket, fn _ws_spec -> {:ok, self()} end)
      assert {:ok, %Websocket{}} = Websocket.init_transport(transport_opts, opts)
    end

    test "validates required RPC URL", %{transport_opts: transport_opts, opts: opts} do
      transport_opts = Keyword.delete(transport_opts, :rpc_url)

      assert {:error, "RPC URL is required but was not provided"} =
               Websocket.init_transport(transport_opts, opts)
    end

    test "raises when RPC URL is not a string", %{transport_opts: transport_opts, opts: opts} do
      invalid_urls = [
        123,
        %{},
        [],
        true,
        false
      ]

      for url <- invalid_urls do
        transport_opts = Keyword.put(transport_opts, :rpc_url, url)

        assert {:error, reason} =
                 Websocket.init_transport(transport_opts, opts)

        assert reason =~ "Invalid RPC URL: expected string, got:"
      end
    end

    test "returns error when RPC URL has an invalid scheme", %{
      transport_opts: transport_opts,
      opts: opts
    } do
      transport_opts = Keyword.put(transport_opts, :rpc_url, "ftp://example.com")

      assert {:error,
              "Invalid RPC URL format: \"ftp://example.com\". The URL must start with ws:// or wss://"} =
               Websocket.init_transport(transport_opts, opts)
    end

    test "returns error when RPC URL has no host", %{
      transport_opts: transport_opts,
      opts: opts
    } do
      transport_opts = Keyword.put(transport_opts, :rpc_url, "wss://")

      assert {:error, "Invalid RPC URL format: \"wss://\". The URL must contain a valid host"} =
               Websocket.init_transport(transport_opts, opts)
    end

    test "raises when no dispatch callback is provided", %{
      transport_opts: transport_opts,
      opts: opts
    } do
      transport_opts = Keyword.delete(transport_opts, :dispatch_callback)

      assert {:error, "Dispatcher callback function is required but was not provided"} =
               Websocket.init_transport(transport_opts, opts)
    end

    test "raises when dispatch_callback is not a function", %{
      transport_opts: transport_opts,
      opts: opts
    } do
      transport_opts = Keyword.put(transport_opts, :dispatch_callback, "not a function")

      assert {:error,
              "Invalid dispatch_callback function: expected function with arity 1, got: \"not a function\""} =
               Websocket.init_transport(transport_opts, opts)
    end

    test "raises when dispatch_callback arity is not 1", %{
      transport_opts: transport_opts,
      opts: opts
    } do
      transport_opts = Keyword.put(transport_opts, :dispatch_callback, fn -> :ok end)

      assert {:error, message} = Websocket.init_transport(transport_opts, opts)
      assert message =~ "Invalid dispatch_callback function: expected function with arity 1, got:"
    end

    test "accepts both ws and wss URLs", %{
      transport_opts: transport_opts,
      opts: opts
    } do
      expect(Websocket.DynamicSupervisor, :start_websocket, 2, fn _ws_spec -> {:ok, self()} end)

      for url <- [@valid_ws_url, @valid_wss_url] do
        transport_opts = Keyword.put(transport_opts, :rpc_url, url)
        assert {:ok, %Websocket{}} = Websocket.init_transport(transport_opts, opts)
      end
    end
  end

  describe "handle_request/2 - sending messages" do
    setup do
      expect(Websocket.DynamicSupervisor, :start_websocket, fn _ws_spec -> {:ok, self()} end)

      transport_opts = [rpc_url: @valid_ws_url, dispatch_callback: fn _ -> :ok end]
      opts = []
      {:ok, transport} = Websocket.init_transport(transport_opts, opts)
      {:ok, transport: transport}
    end

    test "sends request through websocket", %{transport: transport} do
      encoded_request = ~s({"jsonrpc": "2.0", "method": "eth_blockNumber", "params": [], "id": 1})
      expect(Fresh, :send, fn _pid, {:text, ^encoded_request} -> :ok end)
      assert :ok = Websocket.handle_request(transport, encoded_request)
    end
  end

  describe "handle_in/2 - receiving messages" do
    test "calls dispatch_callback with response" do
      # Create a process to receive the callback result
      test_pid = self()

      callback = fn response ->
        send(test_pid, {:callback_called, response})
        :ok
      end

      encoded_response = ~s({id: 1, result: "0x1"})

      # Call handle_in directly with our test callback
      Websocket.handle_in({:text, encoded_response}, %Websocket.State{dispatch_callback: callback})

      # Wait for the callback to be called
      assert_receive {:callback_called, ^encoded_response}
    end
  end
end
