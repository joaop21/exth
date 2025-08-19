defmodule Exth.Transport.Http do
  @moduledoc """
  HTTP transport implementation for JSON-RPC communication with EVM nodes.

  This module provides HTTP/HTTPS transport capabilities using Tesla HTTP client with
  configurable middleware, timeouts, and custom headers.

  ## Features

    * HTTP/HTTPS transport support
    * Configurable timeouts and custom headers
    * Automatic URL validation and formatting
    * Built-in middleware for base URL, headers, and timeout
    * Customizable HTTP adapter (defaults to Mint)

  ## Configuration Options

    * `:rpc_url` - Required HTTP/HTTPS endpoint URL
    * `:timeout` - Request timeout in milliseconds (default: 30,000ms)
    * `:headers` - Custom HTTP headers to include with requests
    * `:adapter` - Custom Tesla adapter (defaults to `Tesla.Adapter.Mint`)

  ## Example Usage

      # Create HTTP transport
      {:ok, transport} = Transport.new(:http,
        rpc_url: "https://eth-mainnet.example.com",
        timeout: 15_000,
        headers: [{"authorization", "Bearer token"}]
      )

      # Make HTTP request
      {:ok, response} = Transport.call(transport, json_request)
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
  def init_transport(custom_opts, _opts) do
    with {:ok, rpc_url} <- validate_required_url(custom_opts[:rpc_url]),
         :ok <- validate_url_format(rpc_url),
         client <- build_client(custom_opts, rpc_url) do
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
      %URI{scheme: scheme, host: _host} when scheme not in ["http", "https"] ->
        {:error,
         "Invalid RPC URL format: #{inspect(url)}. The URL must start with http:// or https://"}

      %URI{scheme: _scheme, host: ""} ->
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
