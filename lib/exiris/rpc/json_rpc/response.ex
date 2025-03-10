defmodule Exiris.Rpc.JsonRpc.Response do
  alias Exiris.Rpc.JsonRpc

  defmodule Success do
    @type t :: %__MODULE__{
            id: JsonRpc.id(),
            jsonrpc: JsonRpc.jsonrpc(),
            result: String.t()
          }
    defstruct [
      :id,
      :result,
      jsonrpc: JsonRpc.jsonrpc_version()
    ]
  end

  defmodule Error do
    @type t :: %__MODULE__{
            id: JsonRpc.id(),
            jsonrpc: JsonRpc.jsonrpc(),
            error: %{
              code: integer(),
              message: String.t(),
              data: any() | nil
            }
          }
    defstruct [
      :id,
      :error,
      jsonrpc: JsonRpc.jsonrpc_version()
    ]
  end

  @type t :: Success.t() | Error.t()

  @spec success(JsonRpc.id(), String.t()) :: Success.t()
  def success(id, result), do: %Success{id: id, result: result}

  @spec error(JsonRpc.id(), integer(), String.t(), any() | nil) :: Error.t()
  def error(id, code, message, data \\ nil) do
    %Error{id: id, error: %{code: code, message: message, data: data}}
  end
end
