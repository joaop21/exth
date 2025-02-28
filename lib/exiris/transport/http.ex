defmodule Exiris.Transport.Http do
  @moduledoc """
  HTTP transport implementation for Exiris using Tesla.

  This module implements the `Exiris.Transport` behaviour, providing HTTP communication
  capabilities for JSON-RPC requests over HTTP/HTTPS.

  ## Configuration Options

  The following options can be provided when making requests:

    * `:rpc_url` - (Required) The HTTP/HTTPS URL of the JSON-RPC endpoint
    * `:encoder` - (Required) A function to encode JSON requests
    * `:decoder` - (Required) A function to decode JSON responses
    * `:http_opts` - (Optional) A keyword list of HTTP-specific options:
      * `:adapter` - The Tesla adapter to use. Defaults to `Tesla.Adapter.Mint`
      * `:headers` - Additional HTTP headers to send with each request. These will
        override the default headers if there are conflicts
      * `:timeout` - Request timeout in milliseconds. Defaults to 30000 (30 seconds)

  ## Default Headers

  The following headers are included by default in all requests:
    * `user-agent` - Set to "exiris/VERSION"
    * `content-type` - Set to "application/json"

  Custom headers can override these defaults.

  ## Examples

      # Basic usage
      Http.request(payload, rpc_url: "https://eth-mainnet.example.com")

      # With custom timeout and headers
      Http.request(payload,
        rpc_url: "https://eth-mainnet.example.com",
        http_opts: [
          timeout: 5000,
          headers: [
            {"authorization", "Bearer token"},
            {"user-agent", "my-app/1.0"}
          ]
        ]
      )

      # With custom JSON encoder/decoder
      Http.request(payload,
        rpc_url: "https://eth-mainnet.example.com",
        encoder: &MyJSON.encode/1,
        decoder: &MyJSON.decode/1
      )

  ## Error Handling

  The function will raise an `ArgumentError` if:
    * The RPC URL is missing
    * The RPC URL is not a string
    * The RPC URL doesn't start with http:// or https://
    * The RPC URL doesn't contain a valid host

  For runtime errors, it returns:
    * `{:ok, response}` - Request succeeded
    * `{:error, {:http_error, status}}` - HTTP status error
    * `{:error, reason}` - Other runtime errors (network, timeout, etc)
  """

  @behaviour Exiris.Transport

  @adapter Tesla.Adapter.Mint
  @default_timeout 30_000
  @user_agent "#{Application.spec(:exiris, :description)}/#{Application.spec(:exiris, :vsn)}"

  @impl true
  def request(body, opts) do
    rpc_url = validate_rpc_url(opts[:rpc_url])
    client = build_client(rpc_url, opts)

    case Tesla.post(client, "", body) do
      {:ok, %Tesla.Env{status: 200, body: response}} -> {:ok, response}
      {:ok, %Tesla.Env{status: status}} -> {:error, {:http_error, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_rpc_url(nil) do
    raise ArgumentError, "RPC URL is required but was not provided"
  end

  defp validate_rpc_url(rpc_url) when not is_binary(rpc_url) do
    raise ArgumentError, "Invalid RPC URL: expected string, got: #{inspect(rpc_url)}"
  end

  defp validate_rpc_url(rpc_url) do
    uri = URI.parse(rpc_url)

    if not valid_uri?(uri) do
      raise ArgumentError, """
      Invalid RPC URL format: #{inspect(rpc_url)}
      The URL must:
        - Start with http:// or https://
        - Contain a valid host
      """
    end

    rpc_url
  end

  defp valid_uri?(%URI{scheme: scheme, host: host}) do
    scheme in ["http", "https"] and not is_nil(host)
  end

  defp build_client(rpc_url, opts) do
    http_opts = opts[:http_opts] || []
    adapter = http_opts[:adapter] || @adapter

    middleware = [
      {Tesla.Middleware.BaseUrl, rpc_url},
      {Tesla.Middleware.Headers, build_headers(http_opts[:headers])},
      {Tesla.Middleware.JSON, encode: opts[:encoder], decode: opts[:decoder]},
      {Tesla.Middleware.Timeout, timeout: http_opts[:timeout] || @default_timeout}
    ]

    Tesla.client(middleware, adapter)
  end

  defp build_headers(nil), do: build_headers([])

  defp build_headers(custom_headers) do
    default_headers =
      normalize_headers([
        {"user-agent", @user_agent},
        {"content-type", "application/json"}
      ])

    custom_headers
    |> normalize_headers()
    |> Map.merge(default_headers, fn _k, custom, _default -> custom end)
    |> Enum.to_list()
  end

  defp normalize_headers(headers) do
    headers
    |> Enum.map(fn {k, v} -> {String.downcase(to_string(k)), v} end)
    |> Map.new()
  end
end
