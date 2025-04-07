defmodule Exth.Transport.Http do
  @moduledoc """
  HTTP transport implementation for JSON-RPC requests using Tesla.

  Implements the `Exth.Transport.Transportable` protocol for making HTTP/HTTPS 
  requests to JSON-RPC endpoints. Uses Tesla as the HTTP client with Mint as the 
  default adapter.

  ## Usage

      transport = Transportable.new(
        %Exth.Transport.Http{},
        rpc_url: "https://mainnet.infura.io/v3/YOUR-PROJECT-ID",
      )

      {:ok, response} = Transportable.call(transport, request)
  """

  alias Exth.Rpc.Request
  alias Exth.Rpc.Response

  @typedoc "HTTP transport configuration"
  @type t :: %__MODULE__{
          client: Tesla.Client.t()
        }

  defstruct [:client]

  @adapter Tesla.Adapter.Mint
  @default_timeout 30_000
  @user_agent "#{Application.spec(:exth, :description)}/#{Application.spec(:exth, :vsn)}"

  @doc """
  Makes an HTTP request to the JSON-RPC endpoint.

  Returns:
    * `{:ok, responses}` - Successful request with decoded response or responses
    * `{:error, {:http_error, status}}` - HTTP error response
    * `{:error, reason}` - Other errors (network, timeout, etc)
  """
  @spec call(t(), Request.t() | [Request.t()]) ::
          {:ok, Response.t() | [Response.t()]} | {:error, term()}
  def call(%__MODULE__{client: client}, request) do
    case Tesla.post(client, "", request) do
      {:ok, %Tesla.Env{status: 200, body: response}} -> {:ok, response}
      {:ok, %Tesla.Env{status: status}} -> {:error, {:http_error, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a new HTTP transport with the given options.

  ## Options
    * `:rpc_url` - (required) The HTTP/HTTPS endpoint URL
    * `:adapter` - Tesla adapter to use (defaults to `Tesla.Adapter.Mint`)
    * `:headers` - Additional HTTP headers for requests
    * `:timeout` - Request timeout in milliseconds (defaults to 30000)
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    with {:ok, rpc_url} <- validate_required_url(opts[:rpc_url]),
         :ok <- validate_url_format(rpc_url) do
      build_client(opts, rpc_url)
    end
  end

  defp build_client(opts, rpc_url) do
    middleware =
      build_middleware(
        rpc_url: rpc_url,
        headers: opts[:headers],
        timeout: opts[:timeout] || @default_timeout
      )

    adapter = opts[:adapter] || @adapter

    client = Tesla.client(middleware, adapter)

    %__MODULE__{client: client}
  end

  defp build_middleware(config) do
    [
      {Tesla.Middleware.BaseUrl, config[:rpc_url]},
      {Tesla.Middleware.Headers, build_headers(config[:headers])},
      {Tesla.Middleware.JSON, encode: &Request.serialize/1, decode: &Response.deserialize/1},
      {Tesla.Middleware.Timeout, timeout: config[:timeout]}
    ]
  end

  defp validate_required_url(nil) do
    raise ArgumentError, "RPC URL is required but was not provided"
  end

  defp validate_required_url(url) when not is_binary(url) do
    raise ArgumentError, "Invalid RPC URL: expected string, got: #{inspect(url)}"
  end

  defp validate_required_url(url), do: {:ok, url}

  defp validate_url_format(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and not is_nil(host) ->
        :ok

      _ ->
        raise ArgumentError, """
        Invalid RPC URL format: #{inspect(url)}
        The URL must:
          - Start with http:// or https://
          - Contain a valid host
        """
    end
  end

  defp build_headers(nil), do: build_headers([])

  defp build_headers(custom_headers) do
    [
      {"user-agent", @user_agent},
      {"content-type", "application/json"}
      | normalize_headers(custom_headers)
    ]
    |> Enum.uniq_by(fn {k, _} -> String.downcase(to_string(k)) end)
  end

  defp normalize_headers(headers) do
    Enum.map(headers, fn {k, v} -> {String.downcase(to_string(k)), v} end)
  end
end

defimpl Exth.Transport.Transportable, for: Exth.Transport.Http do
  def new(_transport, opts), do: Exth.Transport.Http.new(opts)
  def call(transport, request), do: Exth.Transport.Http.call(transport, request)
end
