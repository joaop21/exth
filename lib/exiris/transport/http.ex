defmodule Exiris.Transport.Http do
  @moduledoc """
  @moduledoc \"""
  HTTP transport implementation for JSON-RPC requests using Tesla.

  This module implements the `Exiris.Transport.Behaviour`, handling HTTP/HTTPS 
  communication for JSON-RPC requests. It uses Tesla as the HTTP client with 
  Mint as the default adapter.

  ## Implementation Details

  The transport:
  * Validates RPC URLs (must be valid HTTP/HTTPS URLs with a host)
  * Manages HTTP-specific configurations (headers, timeouts, adapters)
  * Handles request/response lifecycle
  * Provides consistent error handling

  ## HTTP Configuration

  The transport accepts the following HTTP-specific options:

    * `:adapter` - Tesla adapter to use (defaults to `Tesla.Adapter.Mint`)
    * `:headers` - Additional HTTP headers for requests
    * `:timeout` - Request timeout in milliseconds (defaults to 30000)

  ## Default Headers

  Every request includes these headers by default:
    * `content-type: application/json`
    * `user-agent: exiris/VERSION`

  Custom headers can be provided to override the defaults.

  ## Error Handling

  ### Validation Errors (raises ArgumentError)
  * Missing RPC URL
  * Invalid URL format (non-string)
  * Invalid URL scheme (must be http/https)
  * Missing host in URL

  ### Runtime Errors (returns tagged tuples)
  * `{:ok, response}` - Successful request
  * `{:error, {:http_error, status}}` - HTTP error response
  * `{:error, reason}` - Other errors (network, timeout, etc)

  ## Internal Modules

  * `Opts` - Struct defining HTTP-specific configuration options
  """

  alias Exiris.Transport

  @behaviour Exiris.Transport.Behaviour

  @type opts :: __MODULE__.Opts.t()

  @adapter Tesla.Adapter.Mint
  @default_timeout 30_000
  @user_agent "#{Application.spec(:exiris, :description)}/#{Application.spec(:exiris, :vsn)}"

  defmodule Opts do
    @type t :: %__MODULE__{
            adapter: Tesla.Client.adapter(),
            headers: Keyword.t(),
            timeout: non_neg_integer()
          }

    defstruct [:adapter, :timeout, headers: []]
  end

  @impl true
  def build_opts(opts) do
    adapter = opts[:adapter] || @adapter
    headers = opts[:headers] || []
    timeout = opts[:timeout] || @default_timeout

    %Opts{adapter: adapter, headers: build_headers(headers), timeout: timeout}
  end

  @impl true
  def request(%Transport{} = transport, body) do
    validate_rpc_url(transport.rpc_url)
    client = build_client(transport)

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
  end

  defp valid_uri?(%URI{scheme: scheme, host: host}) do
    scheme in ["http", "https"] and not is_nil(host)
  end

  defp build_client(%Transport{opts: %Opts{} = http_opts} = transport) do
    middleware = [
      {Tesla.Middleware.BaseUrl, transport.rpc_url},
      {Tesla.Middleware.Headers, http_opts.headers},
      {Tesla.Middleware.JSON, encode: transport.encoder, decode: transport.decoder},
      {Tesla.Middleware.Timeout, timeout: http_opts.timeout}
    ]

    Tesla.client(middleware, http_opts.adapter)
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
