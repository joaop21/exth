defmodule Exiris.Rpc.Request do
  alias Exiris.Rpc

  @type t :: %__MODULE__{
          id: Rpc.id(),
          jsonrpc: Rpc.jsonrpc(),
          method: Rpc.method(),
          params: Rpc.params()
        }

  defstruct [
    :id,
    :method,
    params: [],
    jsonrpc: Rpc.jsonrpc_version()
  ]

  def new(method, params, id) do
    %__MODULE__{
      method: method,
      params: params,
      id: id
    }
  end
end
