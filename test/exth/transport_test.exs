defmodule Exth.TransportTest do
  use ExUnit.Case, async: true
  alias Exth.Rpc.Encoding
  alias Exth.Rpc.Request
  alias Exth.Rpc.Response
  alias Exth.Transport

  @base_opts [
    rpc_url: "https://example.com",
    encoder: &Encoding.encode_request/1,
    decoder: &Encoding.decode_response/1
  ]

  defmodule MockTransport do
    defstruct [:config]
  end

  defimpl Exth.Transport.Transportable, for: MockTransport do
    def new(_transport, opts), do: %MockTransport{config: opts}

    def call(_transport, request) do
      case request do
        %{id: id, method: "eth_blockNumber"} ->
          {:ok, Response.success(id, "0x10")}

        %{id: id} ->
          {:ok, Response.error(id, -32601, "Method not found")}
      end
    end
  end

  describe "new/2" do
    test "creates an HTTP transport with valid options" do
      assert %Transport.Http{} = Transport.new(:http, @base_opts)
    end

    test "creates a custom transport with valid module" do
      opts = @base_opts ++ [module: MockTransport]
      assert %MockTransport{} = Transport.new(:custom, opts)
    end

    for required_opt <- [:rpc_url, :encoder, :decoder] do
      test "raises when #{required_opt} is missing" do
        opts = Keyword.delete(@base_opts, unquote(required_opt))

        assert_raise ArgumentError, ~r/missing required option :#{unquote(required_opt)}/, fn ->
          Transport.new(:http, opts)
        end
      end
    end

    test "raises when custom transport module is missing" do
      assert_raise ArgumentError, ~r/missing required option :module/, fn ->
        Transport.new(:custom, @base_opts)
      end
    end

    test "raises ArgumentError for invalid transport type" do
      assert_raise ArgumentError, ~r/invalid transport type/, fn ->
        Transport.new(:invalid, @base_opts)
      end
    end
  end

  describe "call/2" do
    setup do
      opts = @base_opts ++ [module: MockTransport]
      {:ok, transport: Transport.new(:custom, opts)}
    end

    test "returns ok response for known method", %{transport: transport} do
      request = Request.new("eth_blockNumber", [], 1)
      assert {:ok, %Response.Success{result: "0x10"}} = Transport.call(transport, request)
    end

    test "returns error for unknown method", %{transport: transport} do
      request = Request.new("unknown_method", [], 1)

      assert {:ok, %Response.Error{error: %{code: -32601, message: "Method not found"}}} =
               Transport.call(transport, request)
    end
  end
end
