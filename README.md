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

# 2.1. Make RPC calls with explicit client
request1 = Client.request(client, "eth_blockNumber", [])
{:ok, block_number} = Client.send(client, request1)

# 2.2. Or make RPC calls without a client
request2 = Client.request(
  "eth_getBalance",
  ["0x742d35Cc6634C0532925a3b844Bc454e4438f44e", "latest"]
)
{:ok, balance} = Client.send(client, request2)

# 3. You can also send multiple requests in one call
requests = [request1, request2]
{:ok, responses} = Client.send(client, requests)

# 4. You can invert the order of the arguments and pipe
Client.request("eth_blockNumber", [])
|> Client.send(client)

# OR
[request1, request2]
|> Client.send(client)
```

Use the Client approach when you need:

- 🔧 Direct control over RPC calls
- 🔄 Dynamic method names
- 🛠️ Custom parameter handling
- 🎛️ Flexible client management (multiple clients, runtime configuration)

<!-- tabs-close -->

## Transport Options

Exth uses a pluggable transport system that supports different communication
protocols. Each transport type can be configured with specific options:

<!-- tabs-open -->

### HTTP Transport

The default HTTP transport is built on Tesla, providing a robust HTTP client
with middleware support:

```elixir
# Provider configuration
defmodule MyProvider do
  use Exth.Provider,
    transport_type: :http,
    rpc_url: "https://eth-mainnet.example.com",
    # Optional HTTP-specific configuration
    adapter: Tesla.Adapter.Mint, # Default HTTP adapter
    headers: [{"authorization", "Bearer token"}],
    timeout: 30_000, # Request timeout in ms
end

# Direct client configuration
{:ok, client} = Exth.Client.new(
  transport_type: :http,
  rpc_url: "https://eth-mainnet.example.com",
  adapter: Tesla.Adapter.Mint,
  headers: [{"authorization", "Bearer token"}],
  timeout: 30_000
)
```

- ✨ **HTTP** (`:http`)

  - Built on Tesla HTTP client
  - Configurable adapters (Mint, Hackney, etc.)
  - Configurable headers and timeouts

### Custom Transport

Implement your own transport by creating a module and implementing the
`Exth.Transport.Transportable` protocol:

```elixir
defmodule MyCustomTransport do
  # Transport struct should be whatever you need
  defstruct [:config]
end

defimpl Exth.Transport.Transportable, for: MyCustomTransport do
  def new(transport, opts) do
    # Initialize your transport configuration
    %MyCustomTransport{config: opts}
  end

  def call(transport, request) do
    # Handle the JSON-RPC request
    # Return {:ok, response} or {:error, reason}
  end
end

# Use your custom transport
defmodule MyProvider do
  use Exth.Provider,
    transport_type: :custom,
    module: MyCustomTransport,
    rpc_url: "custom://endpoint",
    # Additional custom options
    custom_option: "value"
end

# Direct client configuration
{:ok, client} = Exth.Client.new(
  transport_type: :custom,
  rpc_url: "https://eth-mainnet.example.com",
  module: MyCustomTransport,
  custom_option: "value"
)
```

- 🔧 **Custom** (`:custom`)
  - Full control over transport implementation
  - Custom state management

<!-- tabs-close -->

## Examples

Check out our [examples](https://github.com/joaop21/exth/tree/main/examples)
directory for practical usage examples:

- [multichain.exs](https://github.com/joaop21/exth/blob/main/examples/multichain.exs)
  : Working with multiple chains/providers
- More examples coming soon!

To run an example:

```bash
mix run --no-mix-exs examples/multichain.exs
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
