defmodule Exth.Rpc.Response do
  alias Exth.Rpc

  defmodule Success do
    @type t :: %__MODULE__{
            id: Rpc.id(),
            jsonrpc: Rpc.jsonrpc(),
            result: String.t()
          }
    defstruct [
      :id,
      :result,
      jsonrpc: Rpc.jsonrpc_version()
    ]
  end

  defmodule Error do
    @type t :: %__MODULE__{
            id: Rpc.id(),
            jsonrpc: Rpc.jsonrpc(),
            error: %{
              code: integer(),
              message: String.t(),
              data: any() | nil
            }
          }
    defstruct [
      :id,
      :error,
      jsonrpc: Rpc.jsonrpc_version()
    ]
  end

  @type t :: Success.t() | Error.t()

  @spec success(Rpc.id(), String.t()) :: Success.t()
  def success(id, result), do: %Success{id: id, result: result}

  @spec error(Rpc.id(), integer(), String.t(), any() | nil) :: Error.t()
  def error(id, code, message, data \\ nil) do
    %Error{id: id, error: %{code: code, message: message, data: data}}
  end
end
