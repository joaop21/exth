defmodule Exiris.Transport.Http do
  @moduledoc """
  HTTP transport implementation for Exiris using Tesla.
  """
  alias Exiris.Rpc

  @behaviour Exiris.Transport

  @adapter Tesla.Adapter.Mint

  @impl true
  def request(body, opts) do
    with {:ok, response} <- do_post(client(opts), body) do
      {:ok, Rpc.parse_response(response["id"], response["jsonrpc"], response["result"])}
    else
      {:error, reason} -> {:error, {:request_failed, reason}}
    end
  end

  defp do_post(client, body) do
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

    Tesla.client(
      [
        {Tesla.Middleware.BaseUrl, rpc_url},
        Tesla.Middleware.JSON
      ],
      adapter
    )
  end
end
