defmodule Exiris.Transport.Http do
  @moduledoc """
  HTTP transport implementation for Exiris using Tesla.
  """

  @behaviour Exiris.Transport

  @adapter Tesla.Adapter.Mint

  @impl true
  def request(body, opts) do
    client = client(opts)

    case Tesla.post(client, "", body) do
      {:ok, %Tesla.Env{status: 200, body: response}} -> {:ok, response}
      {:ok, %Tesla.Env{status: status}} -> {:error, {:http_error, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp client(opts) do
    rpc_url = opts[:rpc_url]
    http_opts = opts[:http_opts] || []
    adapter = http_opts[:adapter] || @adapter

    middleware = [{Tesla.Middleware.BaseUrl, rpc_url}] ++ build_json_middleware(opts)

    Tesla.client(middleware, adapter)
  end

  defp build_json_middleware(opts) do
    encoder = opts[:encoder]
    decoder = opts[:decoder]

    [{Tesla.Middleware.JSON, encode: encoder, decode: decoder}]
  end
end
