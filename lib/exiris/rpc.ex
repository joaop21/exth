defmodule Exiris.Rpc do
  alias Exiris.RequestCounter
  alias __MODULE__.Methods
  alias __MODULE__.Request
  alias __MODULE__.Response

  @type id :: pos_integer()
  @type jsonrpc :: String.t()
  @type method :: String.t()
  @type params :: list(binary())

  @spec request(method(), params(), id()) :: Request.t()
  defdelegate request(method, params \\ [], id \\ RequestCounter.next()), to: Request, as: :new

  @spec parse_response(id(), jsonrpc(), map() | term()) :: Response.t()
  defdelegate parse_response(id, jsonrpc, result), to: Response, as: :new

  @spec public_methods() :: %{atom() => list(atom())}
  defdelegate public_methods, to: Methods

  for {method, params} <- Methods.public_methods() do
    args = Enum.map(params, &Macro.var(&1, __MODULE__))

    def unquote(method)(unquote_splicing(args)) do
      request(to_string(unquote(method)), [unquote_splicing(args)])
    end
  end
end
