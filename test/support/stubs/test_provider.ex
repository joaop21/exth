defmodule Exth.TestProvider do
  @moduledoc """
  A stub module for testing Exth.Provider functionality.
  This module is used to test documentation and type specifications
  without making actual HTTP calls.
  """
  use Exth.Provider,
    otp_app: :exth,
    transport_type: :custom,
    module: Exth.TestTransport,
    rpc_url: "http://localhost:8545"
end
