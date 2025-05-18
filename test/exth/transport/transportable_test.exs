defmodule Exth.Transport.TransportableTest do
  use ExUnit.Case, async: true

  alias Exth.Rpc.Request
  alias Exth.Transport.Transportable

  @error_message ~r/protocol Exth.Transport.Transportable not implemented/

  defmodule(InvalidTransport) do
    defstruct []
  end

  describe "protocol requirements" do
    test "raises Protocol.UndefinedError when protocol is not implemented" do
      transport = %InvalidTransport{}
      encoded_request = Request.new("eth_blockNumber", [], 1) |> Request.serialize()

      assert_raise Protocol.UndefinedError, @error_message, fn ->
        Transportable.new(transport, [])
      end

      assert_raise Protocol.UndefinedError, @error_message, fn ->
        Transportable.call(transport, encoded_request)
      end
    end
  end
end
