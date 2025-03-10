defmodule Exiris.Rpc do
  @moduledoc """
  Handles JSON-RPC communication with EVM-compatible blockchain nodes.

  This module provides:
    * Auto-generated functions for all standard EVM JSON-RPC methods
    * Request building and response parsing
    * Automatic request ID generation and tracking
    * Type safety for request/response handling

  ## Examples

      iex> Exiris.Rpc.eth_block_number()
      %Exiris.Rpc.Request{
        jsonrpc: "2.0",
        method: "eth_blockNumber",
        params: [],
        id: 1
      }

      iex> Exiris.Rpc.eth_get_balance("0x742d35Cc6634C0532925a3b844Bc454e4438f44e", "latest")
      %Exiris.Rpc.Request{
        jsonrpc: "2.0",
        method: "eth_getBalance",
        params: ["0x742d35Cc6634C0532925a3b844Bc454e4438f44e", "latest"],
        id: 2
      }

  All standard EVM JSON-RPC methods are available as functions, with proper parameter
  validation and type conversion. The module automatically handles request ID generation
  and maintains the JSON-RPC 2.0 protocol format.
  """

  alias Exiris.RequestCounter
  alias __MODULE__.Methods
  alias __MODULE__.JsonRpc.Request

  @type id :: pos_integer()
  @type jsonrpc :: String.t()
  @type method :: String.t()
  @type params :: list(binary())

  @spec build_request(method(), params(), id()) :: Request.t()
  def build_request(method, params, id \\ RequestCounter.next()) do
    Request.new(method, params, id)
  end

  @spec methods() :: %{atom() => {atom(), list(atom()), boolean()}}
  defdelegate methods, to: Methods
end
