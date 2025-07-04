defmodule Exth.Rpc do
  @moduledoc """
  Core module for making JSON-RPC requests to EVM-compatible blockchain nodes.

  This module provides a comprehensive interface for interacting with JSON-RPC endpoints,
  offering flexible request building, multiple transport options, and robust error handling.

  ## Key Features

    * Client-based and standalone request building
    * Batch request support for better performance
    * Configurable transport layers (HTTP, WebSocket, custom implementations)
    * Automatic request ID generation and version management
    * Comprehensive error handling
    * Support for WebSocket subscriptions

  ## Quick Start

      # Create a client
      client = Rpc.new_client(:http, rpc_url: "https://eth-mainnet.example.com")

      # Make a simple request
      request = Rpc.raw_request("eth_blockNumber", [])
      {:ok, response} = Rpc.send(client, request)

      # Create a WebSocket client for subscriptions
      ws_client = Rpc.new_client(:websocket, rpc_url: "wss://eth-mainnet.example.com")
      request = Rpc.raw_request("eth_subscribe", ["newHeads"])
      {:ok, response} = Rpc.send(ws_client, request)

  ## Request Patterns

  ### Client-based Requests
      # Create client once and reuse
      client = Rpc.new_client(:http, rpc_url: "https://eth-mainnet.example.com")

      client
      |> Rpc.request("eth_blockNumber", [])
      |> Rpc.request("eth_getBalance", ["0x742d...", "latest"])
      |> Rpc.send()

  ### Standalone Requests
      # Build requests without client
      request = Rpc.raw_request("eth_blockNumber", [])
      {:ok, response} = Rpc.send(client, request)

  ### Batch Requests
      # Send multiple requests in one call
      requests = [
        Rpc.raw_request("eth_blockNumber", []),
        Rpc.raw_request("eth_gasPrice", [])
      ]
      {:ok, [block_response, gas_response]} = Rpc.send(client, requests)

  ### WebSocket Subscriptions
      # Create a WebSocket client
      ws_client = Rpc.new_client(:websocket, rpc_url: "wss://eth-mainnet.example.com")

      # Subscribe to new blocks
      request = Rpc.raw_request("eth_subscribe", ["newHeads"])
      {:ok, response} = Rpc.send(ws_client, request)

      # Unsubscribe when done
      unsubscribe_request = Rpc.raw_request("eth_unsubscribe", [response.result])
      {:ok, _} = Rpc.send(ws_client, unsubscribe_request)

  ## Transport Configuration

  The module supports different transport layers:

    * `:http` - Standard HTTP/HTTPS transport with configurable headers and timeouts
    * `:websocket` - WebSocket transport for real-time updates and subscriptions
    * `:custom` - Custom transport implementations for special needs

  ## Error Handling

  The module provides consistent error handling across all request types:

      case Rpc.send(client, request) do
        {:ok, response} ->
          # Handle successful response
          handle_success(response.result)

        {:error, %{code: code, message: msg}} ->
          # Handle RPC-level errors
          handle_rpc_error(code, msg)

        {:error, %Exception{} = e} ->
          # Handle transport-level errors
          handle_transport_error(e)
      end

  ## Best Practices

    * Reuse client instances when possible
    * Use batch requests for multiple calls
    * Implement appropriate timeouts
    * Handle errors gracefully
    * Monitor client health
    * Clean up resources when done
    * Use WebSocket transport for subscriptions and real-time updates

  See the individual function documentation for more detailed usage examples
  and options.
  """

  alias __MODULE__.Call
  alias __MODULE__.Client
  alias __MODULE__.Request
  alias __MODULE__.Types
  alias Exth.Transport

  @doc """
  Creates a new JSON-RPC client with the specified transport type and options.

  ## Transport Types
    * `:http` - HTTP/HTTPS transport
    * `:websocket` - WebSocket transport
    * `:custom` - Custom transport implementation

  ## Options
    * `:rpc_url` - (Required) The endpoint URL
    * `:headers` - Additional HTTP headers (HTTP transport only)
    * `:timeout` - Request timeout in ms (HTTP transport only)

  ## Examples

      # Create an HTTP client
      client = Rpc.new_client(:http, rpc_url: "https://eth-mainnet.example.com")

      # Create a WebSocket client
      ws_client = Rpc.new_client(:websocket, rpc_url: "wss://eth-mainnet.example.com")

      # Create a custom transport client
      client = Rpc.new_client(:custom, module: MyTransport, rpc_url: "https://example.com")
  """
  @spec new_client(Transport.type(), keyword()) :: Client.t()
  defdelegate new_client(type, opts), to: Client, as: :new

  @doc """
  Builds a new JSON-RPC request using a client for the given method and parameters.

  When using a client, the request will automatically:
    * Set the protocol version to "2.0"
    * Generate a unique request ID based on the client's ID sequence
    * Format parameters according to the JSON-RPC spec

  The client-based request ensures that each request gets a unique ID within
  the client's context, which is important for correlating responses in batch
  requests or concurrent operations.

  ## Examples

      # Simple request with no parameters
      client
      |> Rpc.request("eth_blockNumber", [])
      |> Rpc.send()

      # Chain multiple requests
      client
      |> Rpc.request("eth_blockNumber", [])
      |> Rpc.request("eth_getBalance", ["0x742d...", "latest"])
      |> Rpc.send()
  """
  @spec request(Client.t() | Call.t(), Types.method(), Types.params()) :: Call.t()
  defdelegate request(client, method, params), to: Client

  @doc """
  Builds a new JSON-RPC raw request without requiring a client instance.

  This is a convenience function for creating requests that can be later used
  with a client. Useful when building multiple requests before sending them.

  When creating a standalone request, it will:
    * Set the protocol version to "2.0"
    * Leave the request ID as nil (it will be set when used with a client)
    * Format parameters according to the JSON-RPC spec

  The ID-less request allows for flexibility, as the actual ID will be assigned
  by the client when the request is sent, ensuring proper ID sequencing within
  the client's context.

  ## Examples

      # Create standalone requests
      request1 = Rpc.raw_request("eth_blockNumber", [])
      request2 = Rpc.raw_request("eth_getBalance", ["0x742d...", "latest"])

      # Send single request
      {:ok, response} = Rpc.send(client, request1)

      # Send batch requests
      {:ok, responses} = Rpc.send(client, [request1, request2])
  """
  @spec raw_request(Types.method(), Types.params(), Types.id() | nil) :: Request.t()
  defdelegate raw_request(method, params, id \\ nil), to: Request, as: :new

  @doc """
  Sends a JSON-RPC call chain using the client's configured transport.

  This function is used with the Rpc.Call to send a chain of requests that
  were built using `request/3`.

  ## Returns
    * `{:ok, response}` - Successful single request with decoded response
    * `{:ok, responses}` - Successful batch request with list of decoded responses
    * `{:error, reason}` - Request failed with error details

  ## Examples

      # Send a single request
      client
      |> Rpc.request("eth_blockNumber", [])
      |> Rpc.send()

      # Send multiple requests
      client
      |> Rpc.request("eth_blockNumber", [])
      |> Rpc.request("eth_getBalance", ["0x742d...", "latest"])
      |> Rpc.send()
  """
  @spec send(Call.t()) :: Client.send_response_type()
  defdelegate send(rpc_call), to: Client

  @doc """
  Sends one or more JSON-RPC requests using the client's configured transport.

  This function is the main interface for executing requests. It handles both
  single and batch requests automatically, with proper error handling and response
  decoding.

  ## Request Types
    * Single request: Pass a single Request.t()
    * Batch request: Pass a list of Request.t()

  ## Returns
    * `{:ok, response}` - Successful single request with decoded response
    * `{:ok, responses}` - Successful batch request with list of decoded responses
    * `{:error, reason}` - Request failed with error details (Exception.t() or map())

  ## Examples

      # Single request
      request = Rpc.raw_request("eth_blockNumber", [])
      {:ok, response} = Rpc.send(client, request)

      # Batch request
      requests = [
        Rpc.raw_request("eth_blockNumber", []),
        Rpc.raw_request("eth_gasPrice", [])
      ]
      {:ok, responses} = Rpc.send(client, requests)

      # Error handling
      case Rpc.send(client, request) do
        {:ok, response} -> handle_success(response)
        {:error, %{code: code, message: msg}} -> handle_rpc_error(code, msg)
        {:error, %Exception{} = e} -> handle_transport_error(e)
      end
  """
  @spec send(Client.send_argument_type(), Client.send_argument_type()) ::
          Client.send_response_type()
  defdelegate send(arg1, arg2), to: Client
end
