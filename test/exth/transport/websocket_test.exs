defmodule Exth.Transport.WebsocketTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Exth.Transport.Websocket

  @valid_ws_url "ws://localhost:8545"
  @valid_wss_url "wss://localhost:8545"

  setup :verify_on_exit!

  describe "new/1 - transport initialization" do
    setup do
      {:ok, base_opts: [rpc_url: @valid_ws_url, dispatch_callback: fn arg -> arg end]}
    end

    test "creates transport with valid options", %{base_opts: base_opts} do
      expect(Websocket.DynamicSupervisor, :start_websocket, fn _ws_spec -> {:ok, self()} end)
      opts = Keyword.put(base_opts, :rpc_url, @valid_ws_url)
      assert %Websocket{} = Websocket.new(opts)
    end

    test "validates required RPC URL" do
      assert_raise ArgumentError, ~r/RPC URL is required/, fn ->
        Websocket.new([])
      end
    end

    test "raises when RPC URL is not a string" do
      invalid_urls = [
        123,
        %{},
        [],
        true,
        false
      ]

      for url <- invalid_urls do
        assert_raise ArgumentError, ~r/Invalid RPC URL: expected string, got:/, fn ->
          Websocket.new(rpc_url: url)
        end
      end
    end

    test "raises when RPC URL has an invalid format" do
      invalid_urls = [
        "not-a-url",
        "ftp://example.com",
        "http://invalid",
        "https://invalid"
      ]

      for url <- invalid_urls do
        assert_raise ArgumentError, ~r/Invalid RPC URL format/, fn ->
          Websocket.new(rpc_url: url)
        end
      end
    end

    test "raises when no dispatch callback is provided", %{base_opts: base_opts} do
      assert_raise ArgumentError, ~r/Dispatcher callback function is required/, fn ->
        Websocket.new(base_opts |> Keyword.delete(:dispatch_callback))
      end
    end

    test "raises when dispatch_callback is not a function" do
      opts = [
        rpc_url: @valid_ws_url,
        dispatch_callback: "not a function"
      ]

      assert_raise ArgumentError, ~r/Invalid dispatch_callback function/, fn ->
        Websocket.new(opts)
      end
    end

    test "raises when dispatch_callback arity is not 1" do
      opts = [
        rpc_url: @valid_ws_url,
        dispatch_callback: fn -> :ok end
      ]

      assert_raise ArgumentError, ~r/Invalid dispatch_callback function/, fn ->
        Websocket.new(opts)
      end
    end

    test "accepts both ws and wss URLs" do
      expect(Websocket.DynamicSupervisor, :start_websocket, 2, fn _ws_spec -> {:ok, self()} end)

      for url <- [@valid_ws_url, @valid_wss_url] do
        opts = [
          rpc_url: url,
          dispatch_callback: fn _ -> :ok end
        ]

        assert %Websocket{} = Websocket.new(opts)
      end
    end
  end

  describe "call/2 - sending messages" do
    setup do
      expect(Websocket.DynamicSupervisor, :start_websocket, fn _ws_spec -> {:ok, self()} end)

      {:ok, transport: Websocket.new(rpc_url: @valid_ws_url, dispatch_callback: fn _ -> :ok end)}
    end

    test "sends request through websocket", %{transport: transport} do
      encoded_request = JSON.encode!(%{hello: "world"})
      expect(Fresh, :send, fn _pid, {:text, ^encoded_request} -> :ok end)
      assert :ok = Websocket.call(transport, encoded_request)
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

      encoded_response = %{id: 1, result: "0x1"} |> JSON.encode!()

      # Call handle_in directly with our test callback
      Websocket.handle_in({:text, encoded_response}, %Websocket.State{dispatch_callback: callback})

      # Wait for the callback to be called
      assert_receive {:callback_called, ^encoded_response}
    end
  end
end
