defmodule Exiris do
  @moduledoc """
  Exiris is an Elixir library for interacting with EVM-compatible blockchain nodes.

  ## Key Features

  - Type-safe JSON-RPC client
  - Multiple transport options (HTTP, WebSocket, IPC)
  - Auto-generated functions for standard Ethereum methods
  - Built-in request ID management
  - Configurable providers

  ## Quick Start

      # Define your client
      defmodule MyClient do
        use Exiris.PublicClient,
          transport_type: :http,
          rpc_url: "https://mainnet.infura.io/v3/YOUR-PROJECT-ID"
      end

      # Make RPC calls
      {:ok, block_number} = MyClient.eth_block_number()
      {:ok, balance} = MyClient.eth_get_balance("0x123...", "latest")

  See `Exiris.PublicClient` for detailed usage instructions.
  """
end
