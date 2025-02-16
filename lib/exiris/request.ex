defmodule Exiris.Request do
  alias Exiris.RequestCounter

  @jsonrpc_version "2.0"

  @type t :: %__MODULE__{
          id: pos_integer(),
          jsonrpc: String.t(),
          method: String.t(),
          params: list(String.t())
        }

  @derive Jason.Encoder
  defstruct [
    :id,
    :method,
    params: [],
    jsonrpc: @jsonrpc_version
  ]

  def new(method, params \\ [], id \\ RequestCounter.increment_and_get()) do
    %__MODULE__{
      method: method,
      params: params,
      id: id
    }
  end
end
