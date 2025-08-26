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
- ⚙️ **Dynamic Configuration**: Flexible configuration through both inline options and application config

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
2. **RPC Client** (Low-Level): Direct client usage with more control, requiring
   explicit client handling.

<!-- tabs-open -->

### Provider (Recommended)

```elixir
# Basic usage with inline configuration
defmodule MyProvider do
  use Exth.Provider,
    otp_app: :your_otp_app,
    transport_type: :http,
    rpc_url: "https://YOUR-RPC-URL"
end

# Dynamic configuration through application config
# In your config/config.exs or similar:
config :your_otp_app, MyProvider,
  rpc_url: "https://YOUR-RPC-URL",
  timeout: 30_000,
  max_retries: 3

# Then in your provider module:
defmodule MyProvider do
  use Exth.Provider,
    otp_app: :your_otp_app,
    transport_type: :http
end

# Configuration is merged with inline options taking precedence
defmodule MyProvider do
  use Exth.Provider,
    otp_app: :your_otp_app,
    transport_type: :http,
    rpc_url: "https://OVERRIDE-RPC-URL" # This will override the config value
end

# Use the provider
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
- ⚙️ Flexible configuration through both inline options and application config

#### Configuration Options

Providers can be configured through both inline options and application config.
Inline options take precedence over application config. Here are the available options:

```elixir
# Required options
transport_type: :http | :websocket | :ipc | :custom  # Transport type to use
rpc_url: "https://..."          # RPC endpoint URL (for HTTP/WebSocket)
path: "/tmp/ethereum.ipc"       # Socket path (for IPC)

# Required inline option
otp_app: :your_otp_app          # Application name for config lookup

# Custom transport options
module: MyCustomTransport       # Required when transport_type is :custom

# Optional HTTP options
timeout: 30_000                 # Request timeout in milliseconds
headers: [{"header", "value"}]  # Custom headers for HTTP transport
adapter: Tesla.Adapter.Mint     # HTTP adapter (defaults to Mint)

# Optional WebSocket options
dispatch_callback: fn response -> handle_response(response) end  # Required for WebSocket

# Optional IPC options
pool_size: 10                   # Connection pool size
socket_opts: [:binary, active: false, reuseaddr: true]  # Socket options
```

### RPC Client

```elixir
alias Exth.Rpc

# 1. Define a client
{:ok, client} = Rpc.new_client(
  transport_type: :http,
  rpc_url: "https://YOUR-RPC-URL"
)

# 2.1. Make RPC calls with explicit client
request1 = Rpc.request(client, "eth_blockNumber", [])
{:ok, block_number} = Rpc.send(client, request1)

# 2.2. Or make RPC calls without a client
request2 = Rpc.request(
  "eth_getBalance",
  ["0x742d35Cc6634C0532925a3b844Bc454e4438f44e", "latest"]
)
{:ok, balance} = Rpc.send(client, request2)

# 3. You can also send multiple requests in one call
requests = [request1, request2]
{:ok, responses} = Rpc.send(client, requests)

# 4. You can invert the order of the arguments and pipe
Rpc.request("eth_blockNumber", [])
|> Rpc.send(client)

# OR
[request1, request2]
|> Rpc.send(client)
```

Use the RPC Client approach when you need:

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

The HTTP transport provides robust HTTP/HTTPS communication with configurable middleware:

```elixir
# Provider configuration
defmodule MyProvider do
  use Exth.Provider,
    transport_type: :http,
    rpc_url: "https://eth-mainnet.example.com",
    # Optional HTTP-specific configuration
    adapter: Tesla.Adapter.Mint, # Default HTTP adapter
    headers: [{"authorization", "Bearer token"}],
    timeout: 30_000 # Request timeout in ms
end

# Direct client configuration
{:ok, client} = Exth.Rpc.new_client(
  transport_type: :http,
  rpc_url: "https://eth-mainnet.example.com",
  adapter: Tesla.Adapter.Mint,
  headers: [{"authorization", "Bearer token"}],
  timeout: 30_000
)
```

**HTTP Features:**

- Built on Tesla HTTP client with middleware support
- Configurable adapters (Mint, Hackney, etc.)
- Configurable headers and timeouts
- Automatic URL validation and formatting

### WebSocket Transport

The WebSocket transport provides full-duplex communication for real-time updates and subscriptions:

```elixir
# Provider configuration
defmodule MyProvider do
  use Exth.Provider,
    transport_type: :websocket,
    rpc_url: "wss://eth-mainnet.example.com",
    dispatch_callback: fn response -> handle_response(response) end
end

# Direct client configuration
{:ok, client} = Exth.Rpc.new_client(
  transport_type: :websocket,
  rpc_url: "wss://eth-mainnet.example.com",
  dispatch_callback: fn response -> handle_response(response) end
)

# Example subscription
request = Rpc.request("eth_subscribe", ["newHeads"])
{:ok, response} = Rpc.send(client, request)
```

**WebSocket Features:**

- Full-duplex communication
- Support for subscriptions and real-time updates
- Automatic connection management and lifecycle
- Asynchronous message handling via dispatch callbacks
- Connection state management and supervision

### IPC Transport

The IPC transport provides communication with local Ethereum nodes via Unix domain sockets:

```elixir
# Provider configuration
defmodule MyProvider do
  use Exth.Provider,
    transport_type: :ipc,
    path: "/tmp/ethereum.ipc",
    # Optional IPC-specific configuration
    timeout: 30_000, # Request timeout in ms
    pool_size: 10, # Number of connections in the pool
    socket_opts: [:binary, active: false, reuseaddr: true]
end

# Direct client configuration
{:ok, client} = Exth.Rpc.new_client(
  transport_type: :ipc,
  path: "/tmp/ethereum.ipc",
  timeout: 30_000,
  pool_size: 5
)

# Make requests
request = Rpc.request("eth_blockNumber", [])
{:ok, response} = Rpc.send(client, request)
```

**IPC Features:**

- Unix domain socket communication
- Connection pooling with NimblePool for efficient resource management
- Low latency for local nodes
- Automatic connection lifecycle management
- **Note**: Only available on Unix-like systems

**IPC Configuration Options:**

- `:path` - (required) The Unix domain socket path (e.g., "/tmp/ethereum.ipc")
- `:timeout` - Request timeout in milliseconds (default: 30,000ms)
- `:socket_opts` - TCP socket options (default: [:binary, active: false, reuseaddr: true])
- `:pool_size` - Number of connections in the pool (default: 10)
- `:pool_lazy_workers` - Whether to create workers lazily (default: true)
- `:pool_worker_idle_timeout` - Worker idle timeout (default: nil)
- `:pool_max_idle_pings` - Maximum idle pings before worker termination (default: -1)

### Custom Transport

Implement your own transport by creating a module and implementing the
`Exth.Transport` behaviour:

```elixir
defmodule MyCustomTransport do
  use Exth.Transport

  @impl Exth.Transport
  def init(opts) do
    # Initialize your transport
    {:ok, transport_state}
  end

  @impl Exth.Transport
  def handle_request(transport_state, request) do
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
{:ok, client} = Exth.Rpc.new_client(
  transport_type: :custom,
  module: MyCustomTransport,
  custom_option: "value"
)
```

**Custom Transport Features:**

- Full control over transport implementation
- Custom state management
- Behaviour-based implementation for consistency

<!-- tabs-close -->

## Examples

Check out our [examples](https://github.com/joaop21/exth/tree/main/examples)
directory for practical usage examples.

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
