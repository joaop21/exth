defmodule Exiris.Transport do
  @moduledoc """
  Defines a behavior for transport modules (HTTP, WebSocket, IPC).
  """

  alias Exiris.Rpc.Request
  alias Exiris.Rpc.Response

  @type type :: :http

  @type http_opts :: [
          adapter: Tesla.Client.adapter(),
          headers: Keyword.t(),
          timeout: non_neg_integer()
        ]
  @type opts :: [
          rpc_url: String.t(),
          encoder: (Request.t() -> String.t()),
          decoder: (String.t() -> Response.t()),
          http_opts: http_opts()
        ]

  @callback request(body :: Request.t(), opts :: opts()) :: {:ok, Response.t()} | {:error, any()}

  @spec get_by_type!(type()) :: module()
  def get_by_type!(type) do
    case fetch_by_type(type) do
      {:ok, transport} -> transport
      {:error, reason} -> raise ArgumentError, message: reason
    end
  end

  defp fetch_by_type(:http), do: {:ok, Exiris.Transport.Http}
  defp fetch_by_type(_), do: {:error, :invalid_transport}
end
