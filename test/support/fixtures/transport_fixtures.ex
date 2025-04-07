defmodule Exth.TransportFixtures do
  @moduledoc false

  def valid_transport_opts do
    [rpc_url: "https://example.com"]
  end

  def valid_custom_transport_opts do
    valid_transport_opts() ++ [module: Exth.TestTransport]
  end
end
