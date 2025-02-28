defmodule Exiris.Rpc.Response do
  @type t :: %__MODULE__{
          id: pos_integer(),
          jsonrpc: String.t(),
          result: String.t() | nil,
          error: map() | nil
        }

  defstruct [
    :id,
    :jsonrpc,
    result: nil,
    error: nil
  ]

  def new(id, jsonrpc, %{"message" => msg, "code" => code}) do
    %__MODULE__{id: id, jsonrpc: jsonrpc, error: %{code: code, message: msg}}
  end

  def new(id, jsonrpc, result) do
    %__MODULE__{id: id, jsonrpc: jsonrpc, result: result}
  end
end
