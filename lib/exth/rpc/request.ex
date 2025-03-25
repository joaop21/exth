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
    validate_method(method)
    validate_params(params)
    validate_id(id)

    %__MODULE__{
      method: method,
      params: params,
      id: id
    }
  end

  defp validate_method(method) when is_binary(method) do
    if String.trim(method) == "", do: raise(ArgumentError, "invalid method: cannot be empty")
  end

  defp validate_method(method) when is_atom(method) do
    cond do
      is_nil(method) -> raise(ArgumentError, "invalid method: cannot be nil")
      is_boolean(method) -> raise(ArgumentError, "invalid method: cannot be boolean")
      true -> :ok
    end
  end

  defp validate_method(_), do: raise(ArgumentError, "invalid method: must be a string or atom")

  defp validate_id(id) when is_integer(id) and id > 0, do: :ok
  defp validate_id(_), do: raise(ArgumentError, "invalid id: must be a positive integer")

  defp validate_params(params) when is_list(params), do: :ok
  defp validate_params(_), do: raise(ArgumentError, "invalid params: must be a list")
end
