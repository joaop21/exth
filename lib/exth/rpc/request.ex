defmodule Exth.Rpc.Request do
  alias Exth.Rpc

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

  @spec new(Rpc.method(), Rpc.params(), Rpc.id()) :: t()
  def new(method, params, id) do
    %__MODULE__{
      method: method,
      params: params,
      id: id
    }
  end
end
