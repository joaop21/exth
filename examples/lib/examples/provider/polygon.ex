defmodule Examples.Provider.Polygon do
  @moduledoc false
  use Exth.Provider,
    otp_app: :examples,
    transport_type: :http,
    rpc_url: "https://polygon-rpc.com"
end
