defmodule Exth.Rpc do
  @moduledoc """
  Core module for making JSON-RPC requests to EVM-compatible blockchain nodes.

  This module provides a comprehensive interface for interacting with JSON-RPC endpoints,
  offering flexible request building, multiple transport options, and robust error handling.

  ## Key Features

    * Client-based and standalone request building
    * Batch request support for better performance
    * Configurable transport layers (HTTP, custom implementations)
    * Automatic request ID generation and version management
    * Flexible JSON encoding/decoding options
    * Comprehensive error handling

  ## Quick Start

      # Create a client
      client = Rpc.new_client(:http, rpc_url: "https://eth-mainnet.example.com")

      # Make a simple request
      request = Rpc.request("eth_blockNumber", [])
      {:ok, response} = Rpc.send(client, request)

  ## Request Patterns

  ### Client-based Requests
      # Create client once and reuse
      client = Rpc.new_client(:http, rpc_url: "https://eth-mainnet.example.com")
      
      # Make requests with client
      request = Rpc.request(client, "eth_getBalance", ["0x742d...", "latest"])
      {:ok, response} = Rpc.send(client, request)

  ### Standalone Requests
      # Build requests without client
      request = Rpc.request("eth_blockNumber", [])
      {:ok, response} = Rpc.send(client, request)

  ### Batch Requests
      # Send multiple requests in one call
      requests = [
        Rpc.request("eth_blockNumber", []),
        Rpc.request("eth_gasPrice", [])
      ]
      {:ok, [block_response, gas_response]} = Rpc.send(client, requests)

  ## Transport Configuration

  The module supports different transport layers:

    * `:http` - Standard HTTP/HTTPS transport with configurable headers and timeouts
    * `:custom` - Custom transport implementations for special needs

  ## Error Handling

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

  See the individual function documentation for more detailed usage examples
  and options.
  """

  alias __MODULE__.Client
  alias __MODULE__.Request
  alias Exth.Transport

  @type id :: pos_integer()
  @type jsonrpc :: String.t()
  @type method :: atom() | String.t()
  @type params :: list(binary())

  @jsonrpc_version "2.0"

  @doc """
  Returns the JSON-RPC protocol version used by the client.
  """
  @spec jsonrpc_version() :: jsonrpc()
  def jsonrpc_version, do: @jsonrpc_version

  @doc """
  Creates a new JSON-RPC client with the specified transport type and options.

  ## Transport Types
    * `:http` - HTTP/HTTPS transport
    * `:custom` - Custom transport implementation

  ## Options
    * `:rpc_url` - (Required) The endpoint URL
    * `:encoder` - Function to encode requests to JSON
    * `:decoder` - Function to decode JSON responses
    * `:headers` - Additional HTTP headers (HTTP transport only)
    * `:timeout` - Request timeout in ms (HTTP transport only)

  ## Examples

      client = Rpc.new_client(:http, rpc_url: "https://eth-mainnet.example.com")
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

      # Simple request with no parameters - includes client-generated ID
      request = Rpc.request(client, "eth_blockNumber", [])
      # => %Request{id: 1, method: "eth_blockNumber", params: []}

      # Request with multiple parameters - next ID in sequence
      request = Rpc.request(client, "eth_getBalance", ["0x742d...", "latest"])
      # => %Request{id: 2, method: "eth_getBalance", params: ["0x742d...", "latest"]}

      # The request can be later used with Rpc.send/2
      {:ok, response} = Rpc.send(client, request)
  """
  @spec request(Client.t(), method(), params()) :: Request.t()
  defdelegate request(client, method, params), to: Client

  @doc """
  Builds a new JSON-RPC request without requiring a client instance.

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

      # Create standalone requests - no IDs yet
      request1 = Rpc.request("eth_blockNumber", [])
      # => %Request{id: nil, method: "eth_blockNumber", params: []}

      request2 = Rpc.request("eth_getBalance", ["0x742d...", "latest"])
      # => %Request{id: nil, method: "eth_getBalance", params: ["0x742d...", "latest"]}

      # When sent with a client, IDs will be assigned
      {:ok, response} = Rpc.send(client, request1)
      # request1 now has id: 1

      # In batch requests, each request gets a sequential ID
      {:ok, responses} = Rpc.send(client, [request1, request2])
      # request1 has id: 2, request2 has id: 3
  """
  @spec request(method(), params()) :: Request.t()
  defdelegate request(method, params), to: Client

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
      {:ok, response} = Rpc.send(client, request)
      block_number = response.result

      # Batch request for better performance
      requests = [
        Rpc.request("eth_blockNumber", []),
        Rpc.request("eth_gasPrice", [])
      ]
      {:ok, [block_response, gas_response]} = Rpc.send(client, requests)

      # You can also invert the arguments
      Rpc.request("eth_blockNumber", [])
      |> Rpc.send(client)

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
