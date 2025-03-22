defmodule Exiris.Provider.ClientCache do
  @moduledoc """
  Provides caching functionality for Ethereum JSON-RPC clients.

  This module implements a persistent caching mechanism for RPC clients using Erlang's
  `:persistent_term` storage, which provides fast read access with a small memory footprint.

  ## Cache Implementation

  The cache:
    * Uses `:persistent_term` for storage
    * Keys are tuples of `{__MODULE__, transport_type, rpc_url}`
    * Values are `Exiris.Rpc.Client` structs
    * Provides atomic operations for getting and creating clients

  ## Performance Characteristics

    * Fast reads: O(1) lookup time
    * Memory efficient: Only one copy per term
    * Process-independent: Cache survives process restarts
    * Node-local: Cache is not distributed

  ## Usage

      # Get a client from cache
      {:ok, client} = ClientCache.get_client(:http, "https://eth-mainnet.example.com")

      # Create and cache a new client
      client = ClientCache.create_client(:http, "https://eth-mainnet.example.com", %Client{})
  """

  alias Exiris.Rpc.Client
  alias Exiris.Rpc.Client

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
  @spec get_client(Exiris.Transport.type(), String.t()) ::
          {:ok, Client.t()} | {:error, :not_found}
  def get_client(transport_type, rpc_url) do
    try do
      %Client{} = client = :persistent_term.get(build_key(transport_type, rpc_url))
      {:ok, client}
    rescue
      ArgumentError ->
        {:error, :not_found}
    end
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
  @spec create_client(Exiris.Transport.type(), String.t(), Client.t()) :: Client.t()
  def create_client(transport_type, rpc_url, client) do
    with :ok <- :persistent_term.put(build_key(transport_type, rpc_url), client) do
      client
    end
  end

  defp build_key(transport_type, rpc_url), do: {__MODULE__, transport_type, rpc_url}
end
