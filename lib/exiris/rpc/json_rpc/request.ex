defmodule Exiris.Rpc.JsonRpc.Request do
  alias Exiris.Rpc.JsonRpc

  @type t :: %__MODULE__{
          id: JsonRpc.id(),
          jsonrpc: JsonRpc.jsonrpc(),
          method: JsonRpc.method(),
          params: JsonRpc.params()
        }

  defstruct [
    :id,
    :method,
    params: [],
    jsonrpc: JsonRpc.jsonrpc_version()
  ]

  def new(method, params, id) do
    %__MODULE__{
      method: method,
      params: params,
      id: id
    }
  end
end
