# Exth

Exth is an Elixir client for interacting with EVM-compatible blockchain nodes
via JSON-RPC. It provides a robust, type-safe interface for making Ethereum RPC
calls.

## Features

- 🔒 **Type Safety**: Comprehensive type specs and validation
- 🔄 **Transport Agnostic**: Pluggable transport system (HTTP, WebSocket, IPC)
- 🎯 **Smart Defaults**: Sensible defaults with full configurability
- 🛡️ **Error Handling**: Detailed error reporting and recovery
- 📦 **Batch Support**: Efficient batch request processing
- 🔌 **Protocol Compliance**: Full JSON-RPC 2.0 specification support

## Installation

Add `exth` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:exth, "~> 0.1.0"}
  ]
end
```

## Quick Start

1. Define your client module:

```elixir
defmodule MyClient do
  use Exth.Provider,
    transport_type: :http,
    rpc_url: "https://YOUR-RPC-URL"
end
```

2. Make RPC calls:

```elixir
# Get the latest block number
{:ok, block_number} = MyClient.block_number()

# Get balance for an address
{:ok, balance} = MyClient.eth_get_balance(
  "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
  "latest"
)

# Get block by number with full transactions
{:ok, block} = MyClient.get_block_by_number("0x1", true)

# Send raw transaction
{:ok, tx_hash} = MyClient.send_raw_transaction("0x...")
```

## Configuration

### Transport Options

```elixir
# HTTP Transport
config = [
  transport_type: :http,
  rpc_url: "https://eth-mainnet.example.com",
  headers: [{"authorization", "Bearer token"}],
  timeout: 30_000
]

# Custom Transport
config = [
  transport_type: :custom,
  rpc_url: "custom://endpoint",
  module: MyCustomTransport
]
```

### Client Options

```elixir
defmodule MyClient do
  use Exth.Provider,
    transport_type: :http,
    rpc_url: "https://eth-mainnet.example.com",
    headers: [
      {"authorization", "Bearer token"}
    ],
    timeout: 30_000
end
```

## Error Handling

Exth provides detailed error information:

```elixir
case MyClient.get_balance("0x123...", "latest") do
  {:ok, balance} ->
    # Handle success
    balance

  {:error, %{code: code, message: msg}} ->
    # Handle RPC error
    Logger.error("RPC Error: #{code} - #{msg}")

  {:error, reason} ->
    # Handle other errors
    Logger.error("Error: #{inspect(reason)}")
end
```

## Requirements

- Elixir ~> 1.18
- Erlang/OTP 26 or later

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-new-feature`)
5. Create new Pull Request

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
