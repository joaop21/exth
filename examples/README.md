# Examples

This directory contains example application demonstrating how to use the Exth library to interact with Ethereum and other networks using JSON-RPC.

## Overview

The example app showcases:

- Multiple provider configurations (Ethereum and Polygon)
- Different ways to make RPC calls
- Both high-level provider API and low-level client usage

## Setup

1. Make sure you have Elixir installed
2. Install dependencies:

```bash
mix deps.get
```

## Running Examples

There are three main ways to run the examples:

### 1. Using Provider API

Start an IEx session and run:

```elixir
# Using default Vitalik's address
iex> Examples.run()

# Or with a custom address
iex> Examples.run("0xYourAddressHere")
```

### 2. Using Low-level Client API

For more direct control over RPC calls:

```elixir
iex> Examples.run_with_clients()
```

### 3. Using WebSocket Subscriptions

For real-time updates and subscriptions:

```elixir
iex> Examples.subscribe_to_new_blocks()
```

### 4. Using IPC Transport

For local node communication via Unix domain sockets:

```elixir
iex> Examples.run_with_ipc()
```

## Configuration

The app demonstrates four different ways to configure providers:

1. **Runtime Configuration** (Ethereum Provider):

   - Configuration is loaded at runtime from `config/runtime.exs`

2. **Inline Configuration** (Polygon Provider):

   - Configuration is specified directly in the provider module

3. **WebSocket Subscriptions** (WsEthereum Provider):

   - Configuration is specified directly in the provider module

4. **IPC Configuration** (IpcEthereum Provider):

   - Configuration is specified directly in the provider module
