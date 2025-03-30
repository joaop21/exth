defmodule Exth.TransportFixtures do
  @moduledoc false

  alias Exth.Rpc.Encoding

  def valid_transport_opts do
    [
      rpc_url: "https://example.com",
      encoder: &Encoding.encode_request/1,
      decoder: &Encoding.decode_response/1
    ]
  end

  def valid_custom_transport_opts do
    valid_transport_opts() ++ [module: Exth.TestTransport]
  end
end
