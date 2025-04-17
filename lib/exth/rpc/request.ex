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

  alias Exth.Rpc.Types

  @type t :: %__MODULE__{
          id: Types.id(),
          jsonrpc: Types.jsonrpc(),
          method: Types.method(),
          params: Types.params()
        }

  defstruct [
    :method,
    id: nil,
    params: [],
    jsonrpc: Types.jsonrpc_version()
  ]

  @doc """
  Creates a new request struct with the given method, parameters, and ID.

  ## Parameters
    * `method` - The RPC method name (string or atom)
    * `params` - List of parameters for the method
    * `id` - Optional positive integer for request identification

  ## Returns
    * A new request struct with the given method, parameters, and ID

  ## Examples
      # Simple request with no ID
      request = Request.new("eth_blockNumber", [])
      # => %Request{id: nil, method: "eth_blockNumber", params: []}

      # Request with ID
      request = Request.new("eth_getBalance", ["0x742d...", "latest"], 1)
      # => %Request{id: 1, method: "eth_getBalance", params: ["0x742d...", "latest"]}
  """
  @spec new(Types.method(), Types.params(), Types.id() | nil) :: t()
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

  @doc """
  Serializes a request to JSON.

  ## Parameters
    * `request` - The request to serialize

  ## Returns
    * `{:ok, json}` - Successful serialization with JSON string
    * `{:error, reason}` - Serialization failed with error reason

  ## Examples
      # Single request
      {:ok, json} = Request.serialize(%Request{
        method: "eth_blockNumber",
        params: [],
        id: 1
      })

      # Batch request
      {:ok, json} = Request.serialize([
        %Request{method: "eth_blockNumber", params: [], id: 1},
        %Request{method: "eth_getBalance", params: ["0x123...", "latest"], id: 2}
      ])
  """
  @spec serialize(t() | [t()]) :: {:ok, String.t()} | {:error, Exception.t()}
  def serialize(%__MODULE__{} = request) do
    request
    |> do_encode_request()
    |> json_encode()
  end

  def serialize(requests) when is_list(requests) do
    requests
    |> Enum.map(&do_encode_request/1)
    |> json_encode()
  end

  defp json_encode(data) do
    encoded = JSON.encode!(data)
    {:ok, encoded}
  rescue
    _ -> {:error, "encoding of #{inspect(data)} failed"}
  end

  defp do_encode_request(%__MODULE__{} = request), do: Map.from_struct(request)
end
