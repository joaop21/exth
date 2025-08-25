defmodule Exth.Transport.Http do
  @moduledoc """
  HTTP transport for JSON-RPC endpoints.

  Uses Tesla with Mint adapter by default. Supports custom headers, timeouts, and adapters.

  ## Options

    * `:rpc_url` - HTTP/HTTPS endpoint URL (required)
    * `:timeout` - Request timeout in ms (default: 30,000)
    * `:headers` - Custom HTTP headers
    * `:adapter` - Tesla adapter (default: Tesla.Adapter.Mint)

  ## Example

      {:ok, transport} = Transport.new(:http, rpc_url: "https://api.example.com")
      {:ok, response} = Transport.request(transport, json_request)
  """

  use Exth.Transport

  @typedoc "HTTP transport configuration"
  @type t :: %__MODULE__{
          client: Tesla.Client.t()
        }

  defstruct [:client]

  @adapter Tesla.Adapter.Mint
  @default_timeout 30_000

  @impl true
  def handle_request(%__MODULE__{client: client}, request) do
    case Tesla.post(client, "", request) do
      {:ok, %Tesla.Env{status: 200, body: response}} -> {:ok, response}
      {:ok, %Tesla.Env{status: status}} -> {:error, {:http_error, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def init(opts) do
    with {:ok, rpc_url} <- validate_required_url(opts[:rpc_url]),
         :ok <- validate_url_format(rpc_url),
         client <- build_client(opts, rpc_url) do
      {:ok, %__MODULE__{client: client}}
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

    Tesla.client(middleware, adapter)
  end

  defp build_middleware(config) do
    [
      {Tesla.Middleware.BaseUrl, config[:rpc_url]},
      {Tesla.Middleware.Headers, build_headers(config[:headers])},
      {Tesla.Middleware.Timeout, timeout: config[:timeout]}
    ]
  end

  defp validate_required_url(nil) do
    {:error, "RPC URL is required but was not provided"}
  end

  defp validate_required_url(url), do: {:ok, url}

  defp validate_url_format(url) when not is_binary(url) do
    {:error, "Invalid RPC URL format: expected string, got: #{inspect(url)}"}
  end

  defp validate_url_format(url) do
    case URI.parse(url) do
      %URI{scheme: scheme} when scheme not in ["http", "https"] ->
        {:error,
         "Invalid RPC URL format: #{inspect(url)}. The URL must start with http:// or https://"}

      %URI{host: ""} ->
        {:error, "Invalid RPC URL format: #{inspect(url)}. The URL must contain a valid host"}

      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and not is_nil(host) ->
        :ok

      _ ->
        {:error, "Invalid RPC URL format: #{inspect(url)}"}
    end
  end

  defp build_headers(nil), do: build_headers([])

  defp build_headers(custom_headers) do
    [
      {"user-agent", user_agent()},
      {"content-type", "application/json"}
      | normalize_headers(custom_headers)
    ]
    |> Enum.uniq_by(fn {k, _} -> String.downcase(to_string(k)) end)
  end

  defp normalize_headers(headers) do
    Enum.map(headers, fn {k, v} -> {String.downcase(to_string(k)), v} end)
  end

  defp user_agent do
    app = Application.get_application(__MODULE__)
    "#{app}/#{Application.spec(app, :vsn)}"
  end
end
