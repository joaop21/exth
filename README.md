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
    {:exth, "~> 0.1.0"},
    # Optional dependencies:
    # Mint for Tesla adapter
    {:mint, "~> 1.7"}
  ]
end
```

## Usage

Exth offers two ways to interact with EVM nodes:

1. **Provider** (High-Level): Define a provider module with convenient function
   names and no need to pass client references.
2. **Client** (Low-Level): Direct client usage with more control, requiring
   explicit client handling.

<!-- tabs-open -->

### Provider (Recommended)

```elixir
defmodule MyProvider do
  use Exth.Provider,
    transport_type: :http,
    rpc_url: "https://YOUR-RPC-URL"
end

{:ok, block_number} = MyProvider.block_number()

{:ok, balance} = MyProvider.get_balance(
  "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
  "latest"
)

{:ok, block} = MyProvider.get_block_by_number("0x1", true)

{:ok, tx_hash} = MyProvider.send_raw_transaction("0x...")
```

The Provider approach is recommended for most use cases as it provides:

- ✨ Clean, intuitive function names
- 🔒 Type-safe parameters
- 📝 Better documentation and IDE support
- 🎯 No need to manage client references

### Client

```elixir
alias Exth.Client

# 1. Define a client
{:ok, client} = Client.new(
  transport_type: :http,
  rpc_url: "https://YOUR-RPC-URL"
)

# 2. Make RPC calls with explicit client
{:ok, block_number} = Client.request(client, "eth_blockNumber", [])

{:ok, balance} = Client.request(
  client,
  "eth_getBalance",
  ["0x742d35Cc6634C0532925a3b844Bc454e4438f44e", "latest"]
)

{:ok, block} = Client.request(
  client,
  "eth_getBlockByNumber",
  ["0x1", true]
)

{:ok, tx_hash} = Client.request(
  client,
  "eth_sendRawTransaction",
  ["0x..."]
)
```

Use the Client approach when you need:

- 🔧 Direct control over RPC calls
- 🔄 Dynamic method names
- 🛠️ Custom parameter handling
- 🎛️ Flexible client management (multiple clients, runtime configuration)

<!-- tabs-close -->

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
