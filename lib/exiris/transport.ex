defmodule Exiris.Transport do
  @moduledoc """
  Defines a behavior for transport modules (HTTP, WebSocket, IPC).
  """

  alias Exiris.Request
  alias Exiris.Response

  @type http_opts :: [adapter: Tesla.Client.adapter()]
  @type opts :: [rpc_url: String.t(), http_opts: http_opts()]

  @callback request(body :: Request.t(), opts :: opts()) :: {:ok, Response.t()} | {:error, any()}
end
