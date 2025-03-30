defmodule Exth.Provider.ClientCache do
  @moduledoc """
  Provides caching functionality for Ethereum JSON-RPC clients.

  This module implements a high-performance, persistent caching mechanism for RPC clients
  using Erlang's `:persistent_term` storage. It ensures efficient client reuse while
  maintaining a small memory footprint.

  ## Features

    * Persistent client caching
    * Thread-safe operations
    * O(1) lookup performance
    * Memory-efficient storage
    * Process-independent cache
    * Atomic operations
    * Automatic client lifecycle

  ## Cache Architecture

  The cache is built on `:persistent_term` and provides:

    * Fast, constant-time lookups
    * Single copy per cached term
    * Process crash resilience
    * Node-local storage
    * Atomic operations
    * Low memory overhead

  ## Cache Structure

  Keys:
    * Format: `{__MODULE__, transport_type, rpc_url}`
    * Unique per client configuration
    * Efficient lookup pattern

  Values:
    * Type: `Exth.Rpc.Client` structs
    * Complete client configuration
    * Ready-to-use instances

  ## Usage Examples

      # Fetch existing client
      {:ok, client} = ClientCache.get_client(:http, "https://eth-mainnet.example.com")

      # Create and cache new client
      client = ClientCache.create_client(
        :http,
        "https://eth-mainnet.example.com",
        %Client{
          transport: transport,
          counter: counter
        }
      )

      # Pattern for get-or-create
      case ClientCache.get_client(transport_type, rpc_url) do
        {:ok, client} ->
          client
        {:error, :not_found} ->
          client = create_new_client()
          ClientCache.create_client(transport_type, rpc_url, client)
      end

  ## Performance Characteristics

  Read Operations:
    * O(1) lookup time
    * No process communication
    * Zero-copy term sharing
    * Minimal memory overhead

  Write Operations:
    * Atomic updates
    * Copy-on-write semantics
    * Process-independent durability

  Cache Properties:
    * Node-local scope
    * Process-independent
    * Crash-resilient
    * Memory-efficient

  ## Best Practices

    * Reuse clients when possible
    * Handle cache misses gracefully
    * Monitor cache size
    * Clean up unused clients
    * Use appropriate timeouts
    * Implement circuit breakers

  ## Limitations

    * Node-local only (not distributed)
    * No automatic cleanup
    * Memory limited by node
    * No expiration mechanism

  ## Error Handling

    * `{:ok, client}` - Client found in cache
    * `{:error, :not_found}` - Cache miss
    * Raises `ArgumentError` for invalid inputs

  ## Implementation Details

  The cache uses Erlang's `:persistent_term` module which:
    * Stores terms in a special ETS table
    * Provides fast, copy-free reads
    * Maintains single source of truth
    * Survives process crashes
    * Uses minimal memory

  See `Exth.Rpc.Client` for client details and
  `Exth.Transport` for transport configuration.
  """

  alias Exth.Rpc.Client
  alias Exth.Rpc.Client

  @doc """
  Retrieves a cached RPC client for the given transport type and URL.

  Attempts to fetch an existing client from the persistent term storage.
  Returns `{:error, :not_found}` if no client exists for the given combination.

  ## Parameters

    * `transport_type` - The type of transport (e.g., `:http`, `:websocket`)
    * `rpc_url` - The URL of the Ethereum JSON-RPC endpoint

  ## Returns

    * `{:ok, client}` - When a cached client is found
    * `{:error, :not_found}` - When no cached client exists

  ## Examples

      iex> ClientCache.get_client(:http, "https://eth-mainnet.example.com")
      {:ok, %Client{}}

      iex> ClientCache.get_client(:http, "https://non-existing.example.com")
      {:error, :not_found}
  """
  @spec get_client(Exth.Transport.type(), String.t()) ::
          {:ok, Client.t()} | {:error, :not_found}
  def get_client(transport_type, rpc_url) do
    %Client{} = client = :persistent_term.get(build_key(transport_type, rpc_url))
    {:ok, client}
  rescue
    ArgumentError ->
      {:error, :not_found}
  end

  @doc """
  Creates and caches a new RPC client for the given transport type and URL.

  Stores the client in persistent term storage and returns the cached client.
  If a client already exists for the given combination, it will be overwritten.

  ## Parameters

    * `transport_type` - The type of transport (e.g., `:http`, `:websocket`)
    * `rpc_url` - The URL of the Ethereum JSON-RPC endpoint
    * `client` - The `Client` struct to cache

  ## Returns

    * The cached client instance

  ## Examples

      iex> client = %Client{}
      iex> ClientCache.create_client(:http, "https://eth-mainnet.example.com", client)
      %Client{}
  """
  @spec create_client(Exth.Transport.type(), String.t(), Client.t()) :: Client.t()
  def create_client(transport_type, rpc_url, client) do
    with :ok <- :persistent_term.put(build_key(transport_type, rpc_url), client) do
      client
    end
  end

  defp build_key(transport_type, rpc_url), do: {__MODULE__, transport_type, rpc_url}
end
