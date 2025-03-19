defmodule Exiris.Rpc do
  @moduledoc """
  Core module for making JSON-RPC requests to EVM-compatible blockchain nodes.

  Provides a simple interface for creating clients, building requests, and handling
  responses using different transport options.

  ## Quick Start

      client = Rpc.new_client(:http, rpc_url: "https://eth-mainnet.example.com")

      request = Rpc.request(client, "eth_blockNumber", [])
      {:ok, response} = Rpc.send(client, request)
  """

  alias __MODULE__.Client
  alias __MODULE__.Request
  alias __MODULE__.Response
  alias Exiris.Transport

  @type id :: pos_integer()
  @type jsonrpc :: String.t()
  @type method :: String.t()
  @type params :: list(binary())

  @jsonrpc_version "2.0"

  @doc """
  Returns the JSON-RPC protocol version used by the client.
  """
  @spec jsonrpc_version() :: jsonrpc()
  def jsonrpc_version(), do: @jsonrpc_version

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
  Builds a new JSON-RPC request for the given method and parameters.

  The request will automatically:
    * Set the protocol version to "2.0"
    * Generate a unique request ID
    * Format parameters according to the JSON-RPC spec

  ## Examples

      request = Rpc.request(client, "eth_blockNumber", [])
      request = Rpc.request(client, "eth_getBalance", ["0x742d...", "latest"])
  """
  @spec request(Client.t(), method(), params()) :: Request.t()
  defdelegate request(client, method, params), to: Client

  @doc """
  Sends a JSON-RPC request using the client's configured transport.
  Supports both single requests and batch requests.

  ## Returns
    * `{:ok, response}` - Successful single request with decoded response
    * `{:ok, responses}` - Successful batch request with list of responses
    * `{:error, reason}` - Request failed with error details (Exception.t() or map())

  ## Examples

      # Single request
      {:ok, response} = Rpc.send(client, request)

      # Batch request
      {:ok, responses} = Rpc.send(client, [request1, request2])
      
      # Error handling
      {:error, reason} = Rpc.send(client, bad_request)
  """
  @spec send(Client.t(), Request.t() | [Request.t()]) ::
          {:ok, Response.t() | [Response.t()]} | {:error, Exception.t()}
  defdelegate send(client, request), to: Client
end
