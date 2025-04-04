defmodule Exth.Rpc.Request do
  @moduledoc """
  Represents a JSON-RPC request with validation.

  A request consists of:
    * `method` - The RPC method name (string or atom)
    * `params` - List of parameters for the method
    * `id` - Optional positive integer for request identification
    * `jsonrpc` - JSON-RPC version (defaults to "2.0")

  ## Example

      iex> Request.new("eth_getBalance", ["0x742d35Cc6634C0532925a3b844Bc454e4438f44e", "latest"])
      %Request{
        method: "eth_getBalance",
        params: ["0x742d35Cc6634C0532925a3b844Bc454e4438f44e", "latest"],
        id: nil,
        jsonrpc: "2.0"
      }
  """

  alias Exth.Rpc

  @type t :: %__MODULE__{
          id: Rpc.id(),
          jsonrpc: Rpc.jsonrpc(),
          method: Rpc.method(),
          params: Rpc.params()
        }

  defstruct [
    :method,
    id: nil,
    params: [],
    jsonrpc: Rpc.jsonrpc_version()
  ]

  @spec new(Rpc.method(), Rpc.params(), Rpc.id() | nil) :: t()
  def new(method, params, id \\ nil) do
    validate_method(method)
    validate_params(params)

    if not is_nil(id) do
      validate_id(id)
    end

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
