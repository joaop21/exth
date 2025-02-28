defmodule Exiris.Rpc.Request do
  @jsonrpc_version "2.0"

  @type t :: %__MODULE__{
          id: pos_integer(),
          jsonrpc: String.t(),
          method: String.t(),
          params: list(String.t())
        }

  defstruct [
    :id,
    :method,
    params: [],
    jsonrpc: @jsonrpc_version
  ]

  def new(method, params, id) do
    %__MODULE__{
      method: method,
      params: params,
      id: id
    }
  end
end
