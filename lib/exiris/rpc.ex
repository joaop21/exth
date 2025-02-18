defmodule Exiris.Rpc do
  alias Exiris.RequestCounter
  alias __MODULE__.Request
  alias __MODULE__.Response

  @type id :: pos_integer()
  @type jsonrpc :: String.t()
  @type method :: String.t()
  @type params :: list(String.t())

  @spec request(method(), params(), id()) :: Request.t()
  defdelegate request(method, params \\ [], id \\ RequestCounter.next()), to: Request, as: :new

  @spec parse_response(id(), jsonrpc(), map() | term()) :: Response.t()
  defdelegate parse_response(id, jsonrpc, result), to: Response, as: :new
end
