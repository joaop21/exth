defmodule Exiris.Rpc.JsonRpc.SerializedRequest do
  alias Exiris.Rpc.JsonRpc

  @type t :: %__MODULE__{
          id: JsonRpc.id(),
          method: JsonRpc.method(),
          request: JsonRpc.request()
        }

  defstruct [:id, :method, :request]
end
