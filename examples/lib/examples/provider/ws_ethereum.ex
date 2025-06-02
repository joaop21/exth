defmodule Examples.Provider.WsEthereum do
  @moduledoc false
  use Exth.Provider,
    transport_type: :websocket,
    rpc_url: "wss://ethereum-rpc.publicnode.com"
end
