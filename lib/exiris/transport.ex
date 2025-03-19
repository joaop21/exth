defmodule Exiris.Transport do
  @moduledoc """
  Factory module for creating JSON-RPC transport implementations.

  This module provides a simple interface for creating and using different transport
  implementations (HTTP, WebSocket, IPC) through the `Transportable` protocol.

  ## Quick Start

      # Create an HTTP transport
      transport = Transport.new(:http,
        rpc_url: "https://eth-mainnet.example.com",
        encoder: &encode_request!/1,
        decoder: &decode_request!/1
      )

      # Make a JSON-RPC request
      {:ok, response} = Transport.call(transport, %{
        jsonrpc: "2.0",
        method: "eth_blockNumber",
        params: [],
        id: 1
      })

  ## Transport Types

  Currently supported transport types:

  * `:http` - HTTP/HTTPS transport using `Exiris.Transport.Http`
  * `:custom` - Custom transport implementation (requires `:module` option)

  ## Configuration Options

  Common options for all transports:

  * `:rpc_url` - (Required) The endpoint URL for the transport
  * `:encoder` - (Required) Function to encode requests
  * `:decoder` - (Required) Function to decode responses

  HTTP-specific options:

  * `:headers` - Additional HTTP headers for requests
  * `:timeout` - Request timeout in milliseconds (default: 30000)
  * `:adapter` - Tesla adapter to use (default: `Tesla.Adapter.Mint`)

  Custom transport options:

  * `:module` - (Required) Module implementing the `Transportable` protocol
  * Additional options specific to the custom implementation

  ## Custom Transport Implementation

  To create a custom transport:

  1. Define a struct for your transport configuration
  2. Implement the `Transportable` protocol for your struct

  Example:

      defmodule MyTransport do
        defstruct [:config]

        defimpl Exiris.Transport.Transportable do
          def new(_transport, opts) do
            %MyTransport{config: opts}
          end

          def call(transport, request) do
            # Implement request handling
            {:ok, response}
          end
        end
      end

      # Use your custom transport
      transport = Transport.new(:custom,
        module: MyTransport,
        rpc_url: "custom://endpoint"
      )

  ## Error Handling

  The module will raise `ArgumentError` when:
  * Invalid transport type is specified
  * `:module` option is missing for custom transports

  Runtime errors are returned as tagged tuples:
  * `{:ok, response}` - Successful request with decoded response
  * `{:error, reason}` - Request failed with error reason
  """

  alias __MODULE__.Transportable
  alias Exiris.Rpc.Request
  alias Exiris.Rpc.Response

  @typedoc """
  Supported transport types:
  * `:http` - HTTP/HTTPS transport
  * `:custom` - Custom transport implementation
  """
  @type type :: :custom | :http

  @typedoc """
  Transport configuration options.
  """
  @type options :: [
          rpc_url: String.t(),
          encoder: (term -> String.t()),
          decoder: (String.t() -> term),
          module: module() | nil
        ]

  @doc """
  Creates a new transport struct with the given type and options.

  ## Parameters
    * `type` - The type of transport to create (`:http` or `:custom`)
    * `opts` - Configuration options for the transport

  ## Returns
    * A configured transport struct implementing the `Transportable` protocol

  ## Raises
    * `ArgumentError` if required options are missing or type is invalid
  """
  @spec new(type(), options()) :: Transportable.t()
  def new(type, opts) do
    validate_opts(opts)

    module = get_transport_module(type, opts)
    transport = struct(module, %{})

    Transportable.new(transport, opts)
  end

  defp validate_opts(opts) do
    opts[:rpc_url] || raise ArgumentError, "missing required option :rpc_url"
    opts[:encoder] || raise ArgumentError, "missing required option :encoder"
    opts[:decoder] || raise ArgumentError, "missing required option :decoder"
  end

  defp get_transport_module(:http, _opts), do: __MODULE__.Http

  defp get_transport_module(:custom, opts) do
    opts[:module] || raise ArgumentError, "missing required option :module"
  end

  defp get_transport_module(type, _opts) do
    raise(ArgumentError, "invalid transport type: #{inspect(type)}")
  end

  @type error_reason :: Exception.t() | String.t() | term()

  @doc """
  Makes a request using the configured transport.

  ## Parameters
    * `transportable` - The configured transport instance
    * `request` - The JSON-RPC request to send

  ## Returns
    * `{:ok, response}` - Successful request with decoded response
    * `{:error, reason}` - Request failed with error reason
  """
  @spec call(Transportable.t(), Request.t()) :: {:ok, Response.t()} | {:error, error_reason()}
  def call(transportable, request), do: Transportable.call(transportable, request)
end
