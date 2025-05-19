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
    * Error handling
    * Fluent API for chaining requests

  ## Usage

  ### Basic Usage

      # Create a new client
      client = Client.new(:http,
        rpc_url: "https://eth-mainnet.example.com",
        timeout: 30_000
      )

      # Create a raw request
      rpc_call = Client.request(client, "eth_blockNumber", [])

      # Send the request
      {:ok, response} = Client.send(rpc_call)

      # Send batch requests
      {:ok, responses} = 
        client
        |> Client.request("eth_blockNumber", [])
        |> Client.request("eth_getBalance", [address, block])
        |> Client.send()

  ### Using Raw Requests
      # Create a raw request
      request = Request.new("eth_blockNumber", [], 1)

      # Send the request
      {:ok, response} = Client.send(request, client)
      # or
      {:ok, response} = Client.send(client, request)

      # Send batch requests
      {:ok, responses} = Client.send([request1, request2], client)
      # or
      {:ok, responses} = Client.send(client, [request1, request2])

  ## Client Configuration

  The client accepts the following options:

    * `:rpc_url` - (Required) The endpoint URL
    * other options that are specific to the transport type

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

  See `Exth.Transport` for transport details.
  """
  alias Exth.Rpc.Call
  alias Exth.Rpc.Request
  alias Exth.Rpc.Response
  alias Exth.Rpc.Types
  alias Exth.Transport
  alias Exth.Transport.Transportable

  @transport_types [:http, :custom]

  @type t :: %__MODULE__{
          counter: :atomics.atomics_ref(),
          transport: Transportable.t()
        }

  defstruct [:counter, :transport]

  @spec new(Transport.type(), keyword()) :: t()
  def new(type, opts) when type in @transport_types do
    transport = Transport.new(type, opts)

    %__MODULE__{
      counter: :atomics.new(1, signed: false),
      transport: transport
    }
  end

  @spec request(t() | Call.t(), Types.method(), Types.params()) :: Call.t()
  def request(%__MODULE__{} = client, method, params)
      when is_binary(method) or is_atom(method) do
    client
    |> Call.new()
    |> Call.add_request(method, params)
  end

  def request(%Call{} = call, method, params) do
    Call.add_request(call, method, params)
  end

  @type send_argument_type :: t() | Call.t() | Request.t() | [Request.t()] | []
  @type send_response_type :: Transport.call_response() | {:error, :duplicate_ids}

  @spec send(Call.t()) :: send_response_type()
  def send(%Call{} = call) do
    client = Call.get_client(call)
    requests = Call.get_requests(call)
    do_send(client, requests)

    case requests do
      [request] -> do_send(client, request)
      requests -> do_send(client, requests)
    end
  end

  @spec send(send_argument_type(), send_argument_type()) :: send_response_type()
  def send(%__MODULE__{} = client, request) do
    do_send(client, request)
  end

  def send(request, %__MODULE__{} = client) do
    do_send(client, request)
  end

  @spec generate_id(t()) :: non_neg_integer()
  def generate_id(%__MODULE__{counter: counter}) do
    :atomics.add_get(counter, 1, 1)
  end

  ###
  ### Private Functions
  ###

  defp do_send(%__MODULE__{} = client, %Request{} = request) do
    case do_send(client, [request]) do
      {:ok, [result]} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_send(%__MODULE__{}, []), do: {:ok, []}

  defp do_send(%__MODULE__{} = client, requests) when is_list(requests) do
    with :ok <- validate_unique_ids(requests),
         requests <- assign_missing_ids(client, requests),
         {:ok, encoded_requests} <- Request.serialize(requests),
         {:ok, encoded_response} <- Transport.call(client.transport, encoded_requests) do
      Response.deserialize(encoded_response)
    end
  end

  defp validate_unique_ids(request) when is_map(request), do: :ok

  defp validate_unique_ids(requests) when is_list(requests) do
    existing_ids = requests |> Enum.map(& &1.id) |> Enum.reject(&is_nil/1)

    if length(existing_ids) == length(Enum.uniq(existing_ids)) do
      :ok
    else
      {:error, :duplicate_ids}
    end
  end

  defp assign_missing_ids(client, %Request{id: nil} = request) do
    %Request{request | id: generate_id(client)}
  end

  defp assign_missing_ids(_client, %Request{} = request) do
    request
  end

  defp assign_missing_ids(client, requests) when is_list(requests) do
    existing_ids = MapSet.new(requests, & &1.id)

    Enum.map(requests, fn request ->
      if is_nil(request.id) do
        %Request{request | id: generate_unique_id(client, existing_ids)}
      else
        request
      end
    end)
  end

  defp generate_unique_id(client, existing_ids) do
    client
    |> generate_id()
    |> Stream.iterate(fn _ -> generate_id(client) end)
    |> Enum.find(fn id -> not MapSet.member?(existing_ids, id) end)
  end
end
