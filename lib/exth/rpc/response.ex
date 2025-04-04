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

  alias Exth.Rpc

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
  def success(id, result) when not is_nil(id), do: %Success{id: id, result: result}

  @spec error(Rpc.id(), integer(), String.t(), any() | nil) :: Error.t()
  def error(id, code, message, data \\ nil) when not is_nil(id) do
    %Error{id: id, error: %{code: code, message: message, data: data}}
  end
end
