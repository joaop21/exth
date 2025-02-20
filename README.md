# Exiris

Exiris (pronounced as "here she is") is a Elixir client for interacting with
EVM-compatible blockchain nodes via JSON-RPC.

## Installation

Add `exiris` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:exiris, "~> 0.1.0"}
  ]
end
```

## Quick Start

1. Define your client module:

```elixir
defmodule MyClient do
  use Exiris.PublicClient,
    transport_type: :http,
    rpc_url: "https://YOUR-RPC-URL"
end
```

2. Make RPC calls:

```elixir
# Get the latest block number
{:ok, block_number} = MyClient.eth_block_number()

# Get balance for an address
{:ok, balance} = MyClient.eth_get_balance("0x742d35Cc6634C0532925a3b844Bc454e4438f44e", "latest")

# Get block by number with full transactions
{:ok, block} = MyClient.eth_get_block_by_number("0x1", true)
```

## Requirements

- Elixir ~> 1.18
- Erlang/OTP 26 or later

## License

This project is licensed under the MIT License.
