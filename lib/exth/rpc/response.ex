defmodule Exth.Rpc.Response do
  @moduledoc """
  Represents JSON-RPC 2.0 response structures.

  A response can be either a `Success` or an `Error`:

  * `Success` - Contains the result of a successful RPC call
    * `id` - Request identifier (matches the request)
    * `result` - The actual response data
    * `jsonrpc` - JSON-RPC version (defaults to "2.0")

  * `Error` - Contains error information when the RPC call fails
    * `id` - Request identifier (matches the request)
    * `error.code` - Integer error code
    * `error.message` - Error description
    * `error.data` - Optional additional error details
    * `jsonrpc` - JSON-RPC version (defaults to "2.0")

  ## Examples

      # Creating a success response
      Response.success(1, "0x1234")
      #=> %Response.Success{id: 1, result: "0x1234", jsonrpc: "2.0"}

      # Creating an error response
      Response.error(1, -32600, "Invalid Request")
      #=> %Response.Error{
        id: 1,
        error: %{code: -32600, message: "Invalid Request", data: nil},
        jsonrpc: "2.0"
      }
  """

  alias Exth.Rpc.Types

  defmodule Success do
    @moduledoc """
    Represents a successful JSON-RPC 2.0 response.

    ## Fields

      * `id` - Request identifier that matches the request ID
      * `result` - The actual response data from the RPC method call
      * `jsonrpc` - JSON-RPC version (defaults to "2.0")

    ## Example

        %Success{
          id: 1,
          result: "0x4b7",
          jsonrpc: "2.0"
        }
    """

    @type t :: %__MODULE__{
            id: Types.id(),
            jsonrpc: Types.jsonrpc(),
            result: String.t()
          }
    defstruct [
      :id,
      :result,
      jsonrpc: Types.jsonrpc_version()
    ]
  end

  defmodule Error do
    @moduledoc """
    Represents an error JSON-RPC 2.0 response.

    ## Fields

      * `id` - Request identifier that matches the request ID
      * `error` - A map containing error details:
        * `code` - Integer error code (e.g., -32600 for "Invalid Request")
        * `message` - Human-readable error description
        * `data` - Optional additional error information
      * `jsonrpc` - JSON-RPC version (defaults to "2.0")

    ## Example

        %Error{
          id: 1,
          error: %{
            code: -32600,
            message: "Invalid Request",
            data: nil
          },
          jsonrpc: "2.0"
        }

    Common error codes:
      * -32700: Parse error
      * -32600: Invalid Request
      * -32601: Method not found
      * -32602: Invalid params
      * -32603: Internal error
    """

    @type t :: %__MODULE__{
            id: Types.id(),
            jsonrpc: Types.jsonrpc(),
            error: %{
              code: integer(),
              message: String.t(),
              data: any() | nil
            }
          }
    defstruct [
      :id,
      :error,
      jsonrpc: Types.jsonrpc_version()
    ]
  end

  @type t :: Success.t() | Error.t()

  @spec success(Types.id(), String.t()) :: Success.t()
  def success(id, result) when not is_nil(id), do: %Success{id: id, result: result}

  @spec error(Types.id(), integer(), String.t(), any() | nil) :: Error.t()
  def error(id, code, message, data \\ nil) when not is_nil(id) do
    %Error{id: id, error: %{code: code, message: message, data: data}}
  end

  @doc """
  Deserializes a JSON-RPC response.

  ## Examples

      iex> Exth.Rpc.Response.deserialize(~s({"jsonrpc": "2.0", "result": "0x1234", "id": 1}))
      {:ok, %Exth.Rpc.Response.Success{id: 1, result: "0x1234"}}

      iex> Exth.Rpc.Response.deserialize(~s({"jsonrpc": "2.0", "error": {"code": -32_601, "message": "Method not found"}, "id": 1}))
      {:ok, %Exth.Rpc.Response.Error{id: 1, error: %{code: -32_601, message: "Method not found"}}}
  """
  @spec deserialize(String.t()) :: {:ok, t() | [t()]} | {:error, term()}
  def deserialize(json) when is_binary(json) do
    with {:ok, response} <- JSON.decode(json) do
      do_decode_response(response)
    end
  end

  defp do_decode_response(%{"id" => id, "result" => result}),
    do: {:ok, __MODULE__.success(id, result)}

  defp do_decode_response(%{"id" => id, "error" => error}) do
    case error do
      %{"code" => code, "message" => message, "data" => data} ->
        {:ok, __MODULE__.error(id, code, message, data)}

      %{"code" => code, "message" => message} ->
        {:ok, __MODULE__.error(id, code, message)}
    end
  end

  defp do_decode_response(responses) when is_list(responses) do
    results = Enum.map(responses, &do_decode_response/1)

    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {successful, []} ->
        {:ok, Enum.map(successful, fn {:ok, resp} -> resp end)}

      {_, errors} ->
        {:error, "invalid responses in batch: #{inspect(errors)}"}
    end
  end

  defp do_decode_response(response) do
    {:error, "invalid response: #{inspect(response)}"}
  end
end
