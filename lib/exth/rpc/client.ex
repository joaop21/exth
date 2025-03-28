defmodule Exth.Rpc.Client do
  @moduledoc """
  Core client module for making JSON-RPC requests to EVM nodes.

  This module provides the main client interface for interacting with EVM nodes,
  handling request creation, response parsing, and client lifecycle management.

  ## Features

    * Atomic request ID generation
    * Transport abstraction
    * Request/response lifecycle management
    * Batch request support
    * Automatic encoding/decoding
    * Error handling

  ## Usage

      # Create a new client
      client = Client.new(:http,
        rpc_url: "https://eth-mainnet.example.com",
        timeout: 30_000
      )

      # Create a request
      request = Client.request(client, "eth_blockNumber", [])

      # Send the request
      {:ok, response} = Client.send(client, request)

      # Send batch requests
      {:ok, responses} = Client.send(client, [request1, request2])

  ## Client Configuration

  The client accepts the following options:

    * `:rpc_url` - (Required) The endpoint URL
    * `:transport_type` - Transport to use (`:http` or `:custom`)
    * `:timeout` - Request timeout in milliseconds
    * `:headers` - Additional HTTP headers (HTTP only)
    * `:encoder` - Custom request encoder (defaults to JSON)
    * `:decoder` - Custom response decoder (defaults to JSON)

  ## Request ID Generation

  The client uses Erlang's `:atomics` for thread-safe, monotonic request ID
  generation. This ensures:

    * Unique IDs across concurrent requests
    * No ID collisions in batch requests
    * Efficient ID allocation
    * Process-independent ID tracking

  ## Transport Layer

  The client supports different transport mechanisms through the
  `Exth.Transport.Transportable` protocol:

    * Built-in HTTP transport using Tesla/Mint
    * Custom transport implementations
    * Future support for WebSocket and IPC

  ## Error Handling

  The client provides consistent error handling:

    * `{:ok, response}` - Successful request
    * `{:error, reason}` - Request failed

  ## Best Practices

    * Reuse client instances when possible
    * Use batch requests for multiple calls
    * Implement appropriate timeouts
    * Handle errors gracefully
    * Monitor client health
    * Clean up resources when done

  ## Examples

      # Basic request
      client = Client.new(:http, rpc_url: "https://eth-mainnet.example.com")
      request = Client.request(client, "eth_blockNumber", [])
      {:ok, block_number} = Client.send(client, request)

      # Batch request
      requests = [
        Client.request(client, "eth_blockNumber", []),
        Client.request(client, "eth_gasPrice", [])
      ]
      {:ok, [block_number, gas_price]} = Client.send(client, requests)

  See `Exth.Transport` for transport details and `Exth.Rpc.Request`
  for request formatting.
  """
  alias Exth.Transport
  alias Exth.Rpc
  alias Exth.Rpc.Encoding
  alias Exth.Rpc.Request
  alias Exth.Rpc.Response
  alias Exth.Transport.Transportable

  @transport_types [:http, :custom]

  @type t :: %__MODULE__{
          counter: :atomics.atomics_ref(),
          transport: Transportable.t()
        }

  defstruct [:counter, :transport]

  @spec new(Transport.type(), keyword()) :: t()
  def new(type, opts) when type in @transport_types do
    opts = build_opts(opts)
    transport = Transport.new(type, opts)

    %__MODULE__{
      counter: :atomics.new(1, signed: false),
      transport: transport
    }
  end

  defp build_opts(opts) do
    encoder = &Encoding.encode_request/1
    decoder = &Encoding.decode_response/1

    base_opts = Keyword.new(encoder: encoder, decoder: decoder)

    Keyword.merge(base_opts, opts)
  end

  @spec request(t(), Rpc.method(), Rpc.params()) :: Request.t()
  def request(%__MODULE__{} = client, method, params)
      when is_binary(method) or is_atom(method) do
    id = :atomics.add_get(client.counter, 1, 1)
    Request.new(method, params, id)
  end

  @spec send(t(), Request.t() | [Request.t()]) :: {:ok, Response.t()} | {:error, Exception.t()}
  def send(%__MODULE__{} = client, request) do
    Transport.call(client.transport, request)
  end
end
