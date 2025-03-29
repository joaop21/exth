defmodule Exth.TransportTest do
  use ExUnit.Case, async: true

  doctest Exth.Transport

  alias Exth.Rpc.{Request, Response}
  alias Exth.Transport
  alias Exth.Transport.Http
  alias Exth.TestTransport
  alias Exth.TransportFixtures

  import TransportFixtures

  describe "new/2" do
    test "creates an HTTP transport with valid options" do
      assert %Http{} = Transport.new(:http, valid_transport_opts())
    end

    test "creates a custom transport with valid options" do
      assert %TestTransport{} = Transport.new(:custom, valid_custom_transport_opts())
    end

    test "validates base transport requirements" do
      required_opts = [:rpc_url, :encoder, :decoder]

      for opt <- required_opts do
        opts = valid_transport_opts() |> Keyword.delete(opt)

        assert_raise ArgumentError, ~r/missing required option :#{opt}/, fn ->
          Transport.new(:http, opts)
        end
      end
    end

    test "validates custom transport requirements" do
      assert_raise ArgumentError, ~r/missing required option :module/, fn ->
        Transport.new(:custom, valid_transport_opts())
      end
    end

    test "validates transport type" do
      assert_raise ArgumentError, ~r/invalid transport type/, fn ->
        Transport.new(:invalid, valid_transport_opts())
      end
    end

    test "validates transport module implements protocol" do
      defmodule InvalidTransport do
        defstruct []
      end

      opts = valid_transport_opts() ++ [module: InvalidTransport]

      assert_raise Protocol.UndefinedError, fn ->
        Transport.new(:custom, opts)
      end
    end
  end

  describe "call/2" do
    setup do
      {:ok, transport: Transport.new(:custom, valid_custom_transport_opts())}
    end

    test "handles successful RPC calls", %{transport: transport} do
      for {method, expected} <- %{
            "eth_blockNumber" => "0x10",
            "eth_chainId" => "0x1",
            "net_version" => "1"
          } do
        request = Request.new(method, [], System.unique_integer([:positive]))
        assert {:ok, %Response.Success{result: ^expected}} = Transport.call(transport, request)
      end
    end

    test "handles unknown methods", %{transport: transport} do
      request = Request.new("unknown_method", [], 1)

      assert {:ok, %Response.Error{error: %{code: -32_601}}} = Transport.call(transport, request)
    end

    test "preserves request ID in response", %{transport: transport} do
      id = System.unique_integer([:positive])
      request = Request.new("eth_blockNumber", [], id)

      assert {:ok, %Response.Success{id: ^id}} = Transport.call(transport, request)
    end
  end
end
