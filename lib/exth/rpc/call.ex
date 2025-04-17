defmodule Exth.Rpc.Call do
  @moduledoc """
  Represents a chain of RPC calls that can be executed in sequence or as a batch.

  This module provides a fluent API for making RPC calls, allowing you to chain multiple
  requests together before executing them. The calls can be executed either as individual
  requests or as a batch request.

  ## Fields

    * `client` - The RPC client used to make the requests
    * `requests` - List of requests to be executed

  ## Examples

      # Create a new call chain
      call = Call.new(client)

      # Add requests to the chain
      call
      |> Call.add_request("eth_blockNumber", [])
      |> Call.add_request("eth_getBalance", ["0x742d35Cc6634C0532925a3b844Bc454e4438f44e", "latest"])

      # Get the list of requests
      requests = Call.get_requests(call)
      # => [
      #   %Request{method: "eth_blockNumber", params: [], id: 1},
      #   %Request{method: "eth_getBalance", params: ["0x742d...", "latest"], id: 2}
      # ]

      # Get the associated client
      client = Call.get_client(call)
      # => %Client{...}
  """

  alias Exth.Rpc.Client
  alias Exth.Rpc.Request
  alias Exth.Rpc.Types

  @type t :: %__MODULE__{
          client: Client.t(),
          requests: [Request.t()]
        }

  defstruct [
    :client,
    requests: []
  ]

  @doc """
  Creates a new RpcCall with the given client.

  ## Parameters
    * `client` - The RPC client to use for making requests

  ## Returns
    * A new `Call` struct with the given client and an empty list of requests

  ## Examples
      client = %Client{...}
      call = Call.new(client)
      # => %Call{client: client, requests: []}
  """
  @spec new(Client.t()) :: t()
  def new(client) do
    %__MODULE__{client: client}
  end

  @doc """
  Adds a new request to the call chain.

  ## Parameters
    * `call` - The call chain to add the request to
    * `method` - The RPC method name (string or atom)
    * `params` - List of parameters for the method

  ## Returns
    * A new `Call` struct with the request added to the chain

  ## Examples
      call
      |> Call.add_request("eth_blockNumber", [])
      |> Call.add_request("eth_getBalance", ["0x742d...", "latest"])
  """
  @spec add_request(t(), Types.method(), Types.params()) :: t()
  def add_request(%__MODULE__{} = call, method, params) do
    id = Client.generate_id(call.client)
    request = Request.new(method, params, id)
    %{call | requests: call.requests ++ [request]}
  end

  @doc """
  Returns the list of requests in the call chain.

  ## Parameters
    * `call` - The call chain to get requests from

  ## Returns
    * A list of `Request` structs

  ## Examples
      requests = Call.get_requests(call)
      # => [
      #   %Request{method: "eth_blockNumber", params: [], id: 1},
      #   %Request{method: "eth_getBalance", params: ["0x742d...", "latest"], id: 2}
      # ]
  """
  @spec get_requests(t()) :: [Request.t()]
  def get_requests(%__MODULE__{} = call), do: call.requests

  @doc """
  Returns the client associated with this call chain.

  ## Parameters
    * `call` - The call chain to get the client from

  ## Returns
    * The `Client` struct associated with the call chain

  ## Examples
      client = Call.get_client(call)
      # => %Client{...}
  """
  @spec get_client(t()) :: Client.t()
  def get_client(%__MODULE__{} = call), do: call.client
end
