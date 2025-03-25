defmodule Exth.Transport.TransportableTest do
  use ExUnit.Case, async: true

  alias Exth.Transport.Transportable
  alias Exth.Rpc.Request

  @error_message ~r/protocol Exth.Transport.Transportable not implemented/

  defmodule(InvalidTransport) do
    defstruct []
  end

  describe "protocol requirements" do
    test "raises Protocol.UndefinedError when protocol is not implemented" do
      transport = %InvalidTransport{}
      request = Request.new("eth_blockNumber", [], 1)

      assert_raise Protocol.UndefinedError, @error_message, fn ->
        Transportable.new(transport, [])
      end

      assert_raise Protocol.UndefinedError, @error_message, fn ->
        Transportable.call(transport, request)
      end
    end
  end
end
