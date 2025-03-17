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
  * `:encoder` - Function to encode requests
  * `:decoder` - Function to decode responses

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
  alias Exiris.Rpc.JsonRpc.Request
  alias Exiris.Rpc.JsonRpc.Response

  @type type :: :custom | :http

  @spec new(type(), keyword()) :: Transportable.t()
  def new(type, opts) do
    module =
      case type do
        :http -> __MODULE__.Http
        :custom -> opts[:module] || raise ArgumentError, "missing required option :module"
        _ -> raise(ArgumentError, "invalid transport type: #{inspect(type)}")
      end

    transport = struct(module, %{})

    Transportable.new(transport, opts)
  end

  @spec call(Transportable.t(), Request.t()) :: {:ok, Response.t()} | {:error, Exception.t()}
  def call(transportable, request), do: Transportable.call(transportable, request)
end
