defmodule Exth.TransportTest do
  use ExUnit.Case, async: true

  doctest Exth.Transport

  alias Exth.Rpc.{Request, Response}
  alias Exth.TestTransport
  alias Exth.Transport
  alias Exth.Transport.Http
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
      required_opts = [:rpc_url]

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
        {:ok, encoded_request} =
          Request.new(method, [], System.unique_integer([:positive])) |> Request.serialize()

        assert {:ok, encoded_response} = Transport.call(transport, encoded_request)

        assert {:ok, %Response.Success{result: ^expected}} =
                 Response.deserialize(encoded_response)
      end
    end

    test "handles unknown methods", %{transport: transport} do
      {:ok, encoded_request} = Request.new("unknown_method", [], 1) |> Request.serialize()

      assert {:ok, encoded_response} = Transport.call(transport, encoded_request)

      assert {:ok, %Response.Error{error: %{code: -32_601}}} =
               Response.deserialize(encoded_response)
    end

    test "preserves request ID in response", %{transport: transport} do
      id = System.unique_integer([:positive])
      {:ok, encoded_request} = Request.new("eth_blockNumber", [], id) |> Request.serialize()

      assert {:ok, encoded_response} = Transport.call(transport, encoded_request)
      assert {:ok, %Response.Success{id: ^id}} = Response.deserialize(encoded_response)
    end
  end
end
