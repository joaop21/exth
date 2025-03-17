defmodule Exiris.Rpc.JsonRpc.Request do
  alias Exiris.Rpc.Encoding
  alias Exiris.Rpc.JsonRpc
  alias Exiris.Rpc.JsonRpc.SerializedRequest

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

  def serialize(%__MODULE__{} = request) do
    with {:ok, request} <- Encoding.encode_request(request) do
      %SerializedRequest{
        id: request.id,
        method: request.method,
        request: request
      }
    end
  end
end
