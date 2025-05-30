defmodule Exth.Rpc.MessageHandler do
  @moduledoc """
  Handles JSON-RPC messages (requests, responses, and subscriptions).

  This module provides a mechanism for tracking JSON-RPC messages and their
  corresponding callers. Each client/transport gets its own handler instance
  to ensure proper isolation of message handling.

  ## Features

    * Per-client message handling
    * Automatic request ID generation and tracking
    * Batch request support
    * Process crash resilience
    * Efficient message routing
    * Support for any transport implementation

  ## Usage

      # Create a new handler for a client
      {:ok, handler} = MessageHandler.new()

      # Register a request
      Registry.register(handler, request_id, caller_pid)

      # Wait for response
      receive do
        {:response, response} -> handle_response(response)
      end

  ## Message Flow

  1. Client creates its own handler instance
  2. Client registers request ID with caller's PID
  3. Request is sent through transport
  4. Response is received and matched with request
  5. Response is sent to registered caller
  6. Request registration is automatically cleaned up

  ## Error Handling

  The handler handles several error cases:
    * Process crashes (automatic cleanup)
    * Orphaned responses
    * Timeouts
    * Transport errors

  ## Transport Implementation

  Any transport implementation can be used with the handler as long as it:
    * Implements the `Exth.Transport.Transportable` protocol
    * Handles asynchronous communication
    * Sends responses back to the handler using `{:response, encoded_response}` messages
  """

  alias Exth.Rpc.Request
  alias Exth.Rpc.Response
  alias Exth.Transport

  @type request_id :: pos_integer() | String.t()
  @type handler :: Registry.registry()
  @call_timeout 5_000

  @doc """
  Creates a new handler instance for a client.

  ## Returns
    * `{:ok, handler()}` - Successfully created handler
    * `{:error, term()}` - Failed to create handler

  ## Example
      {:ok, handler} = MessageHandler.new()
  """
  @spec new() :: {:ok, handler()} | {:error, term()}
  def new do
    name = :crypto.strong_rand_bytes(20) |> Base.encode64() |> String.to_atom()
    Registry.start_link(keys: :unique, name: name)
    {:ok, name}
  end

  @doc """
  Sends a request through the handler and waits for a response.

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
    request_id = get_request_id(requests)
    caller = self()

    with {:ok, _} <- Registry.register(handler, request_id, caller),
         :ok <- send_request(requests, transport) do
      receive do
        {:response, response} -> {:ok, response}
      after
        timeout -> {:error, :timeout}
      end
    end
  end

  @doc """
  Handles an incoming response by routing it to the appropriate caller.

  ## Parameters
    * `handler` - The handler instance to use
    * `encoded_response` - The encoded JSON-RPC response

  ## Returns
    * `:ok` - Response was handled
    * `:error` - Response could not be handled
  """
  @spec handle_response(handler(), String.t()) :: :ok | :error
  def handle_response(handler, encoded_response) do
    case Response.deserialize(encoded_response) do
      {:ok, response} ->
        response_id = get_response_id(response)

        case Registry.lookup(handler, response_id) do
          [{pid, _}] ->
            send(pid, {:response, response})
            Registry.unregister(handler, response_id)
            :ok

          [] ->
            # when there are no requests for the response, weird but possible?
            :error
        end

      {:error, _reason} ->
        :error
    end
  end

  # Private functions

  @doc false
  defp get_request_id(%{id: id}), do: id
  defp get_request_id(requests), do: Enum.map_join(requests, "_", &get_request_id/1)

  @doc false
  defp get_response_id(%{id: id}), do: id
  defp get_response_id(responses), do: Enum.map_join(responses, "_", &get_response_id/1)

  @doc false
  defp send_request(requests, transport) do
    {:ok, encoded_request} = Request.serialize(requests)
    Transport.call(transport, encoded_request)
  end
end
