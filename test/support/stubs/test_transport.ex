defmodule Exth.TestTransport do
  @moduledoc false

  use Exth.Transport

  defstruct [:config]

  @known_methods %{
    "eth_blockNumber" => "0x10",
    "eth_chainId" => "0x1",
    "eth_gasPrice" => "0x1",
    "eth_getBalance" => "0x1000",
    "net_version" => "1"
  }

  def get_known_methods, do: @known_methods

  @impl Exth.Transport
  def init_transport(opts, _opts) do
    {:ok, %__MODULE__{config: opts}}
  end

  @impl Exth.Transport
  def handle_request(transport, request) do
    decoded_request = JSON.decode!(request)
    do_call(transport, decoded_request)
  end

  defp do_call(_transport, %{"method" => method, "id" => id} = _request) do
    case Map.get(get_known_methods(), method) do
      nil -> {:ok, JSON.encode!(%{id: id, error: %{code: -32_601, message: "Method not found"}})}
      result -> {:ok, JSON.encode!(%{id: id, result: result})}
    end
  end

  defp do_call(transport, requests) do
    requests
    |> Enum.map(&do_call(transport, &1))
    |> Enum.map_join(",", fn {:ok, response} -> response end)
    |> then(fn response -> {:ok, "[#{response}]"} end)
  end
end
