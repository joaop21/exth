defmodule Exth.Rpc.MessageHandler do
  @moduledoc """
  Handles JSON-RPC message correlation between requests and responses.

  This module provides a mechanism for tracking JSON-RPC messages and their
  corresponding callers. Each client/transport gets its own handler instance
  to ensure proper isolation of message handling.

  ## Features

    * Per-client message handling
    * Automatic request/response correlation
    * Batch request support
    * Process crash resilience
    * Efficient message routing
    * Support for any transport implementation

  ## Usage

      # Create a new handler for a client
      {:ok, handler} = MessageHandler.new("wss://eth-mainnet.example.com")

      # Send a request and wait for response
      {:ok, response} = MessageHandler.call(handler, request, transport)

      # Handle incoming responses
      :ok = MessageHandler.handle_response(handler, encoded_response)

  ## Message Flow

  1. Client creates its own handler instance with a unique name
  2. Client sends a request through `call/4`:
     * Registers request ID with caller's PID
     * Sends request through transport
     * Waits for response
     * Cleans up registration
  3. Transport receives response and calls `handle_response/2`:
     * Deserializes response
     * Looks up registered caller
     * Sends response to caller
  4. Caller receives response and continues execution

  ## Error Handling

  The handler handles several error cases:
    * Process crashes (automatic cleanup via Registry)
    * Orphaned responses (no registered caller)
    * Timeouts (configurable per call)
    * Transport errors (propagated to caller)

  ## Transport Implementation

  Any transport implementation can be used with the handler as long as it:
    * Implements the `Exth.Transport.Transportable` protocol
    * Handles asynchronous communication
    * Calls `handle_response/2` with encoded responses

  ## Performance Considerations

    * Uses Registry for efficient process lookup
    * Automatic cleanup of registrations
    * No shared state between calls
    * Configurable timeouts per call
  """

  alias Exth.Rpc.Request
  alias Exth.Rpc.Response
  alias Exth.Transport

  @type request_id :: pos_integer() | String.t()
  @type handler :: Registry.registry()
  @call_timeout 5_000

  @doc """
  Creates a new handler instance for a client.

  Each client should have its own handler instance to ensure proper isolation
  of message handling. The handler is identified by a unique name derived from
  the RPC URL.

  ## Parameters
    * `rpc_url` - The RPC URL to use as the base for the handler name

  ## Returns
    * `{:ok, handler()}` - Successfully created handler
    * `{:error, term()}` - Failed to create handler

  ## Example
      {:ok, handler} = MessageHandler.new("wss://eth-mainnet.example.com")
  """
  @spec new(rpc_url :: String.t()) :: {:ok, handler()} | {:error, term()}
  def new(rpc_url) do
    name = String.to_atom(rpc_url)

    with {:ok, _pid} <- Registry.start_link(keys: :unique, name: name) do
      {:ok, name}
    end
  end

  @doc """
  Sends a request through the handler and waits for a response.

  This function handles the full request/response cycle:
  1. Registers the request ID with the caller's PID
  2. Sends the request through the transport
  3. Waits for the response
  4. Cleans up the registration

  ## Parameters
    * `handler` - The handler instance to use
    * `requests` - The request(s) to send
    * `transport` - The transport to use
    * `timeout` - Optional timeout in milliseconds (default: 5000)

  ## Returns
    * `{:ok, response}` - Successful response
    * `{:error, term()}` - Request failed

  ## Example
      {:ok, response} = MessageHandler.call(handler, request, transport)
  """
  @spec call(handler(), [Request.t()], Transport.Transportable.t(), timeout()) ::
          {:ok, [Response.t()]} | {:error, term()}
  def call(handler, requests, transport, timeout \\ @call_timeout) do
    correlation_id = get_correlation_id(requests)
    ref = make_ref()

    with {:ok, _owner} <- Registry.register(handler, correlation_id, ref),
         :ok <- send_request(requests, transport),
         {:ok, response} <- wait_for_response(ref, timeout),
         :ok <- Registry.unregister(handler, correlation_id) do
      {:ok, response}
    end
  end

  @doc """
  Handles an incoming response by routing it to the appropriate caller.

  This function is called by the transport when a response is received. It:
  1. Deserializes the response
  2. Looks up the registered caller
  3. Sends the response to the caller

  ## Parameters
    * `handler` - The handler instance to use
    * `encoded_response` - The encoded JSON-RPC response

  ## Returns
    * `:ok` - Response was handled
    * `:error` - Response could not be handled

  ## Example
      :ok = MessageHandler.handle_response(handler, encoded_response)
  """
  @spec handle_response(handler(), String.t()) :: :ok | :error
  def handle_response(handler, encoded_response) do
    with {:ok, response} <- Response.deserialize(encoded_response),
         correlation_id = get_correlation_id(response),
         [{pid, ref}] <- Registry.lookup(handler, correlation_id) do
      send(pid, {ref, response})
      :ok
    else
      _ -> :error
    end
  end

  # Private functions

  @doc false
  defp get_correlation_id(%{id: id}), do: id
  defp get_correlation_id(requests), do: Enum.map_join(requests, "_", &get_correlation_id/1)

  @doc false
  defp send_request(requests, transport) do
    {:ok, encoded_request} = Request.serialize(requests)
    Transport.call(transport, encoded_request)
  end

  @doc false
  defp wait_for_response(ref, timeout) do
    receive do
      {^ref, response} -> {:ok, response}
    after
      timeout -> {:error, :timeout}
    end
  end
end
