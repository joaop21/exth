defmodule Exiris.Rpc.Encoding do
  @moduledoc """
  Handles encoding and decoding of JSON-RPC requests and responses.
  """

  alias Exiris.Rpc.Response
  alias Exiris.Rpc.Request
  # alias Exiris.Rpc.Response

  @spec encode_request(Request.t()) :: {:ok, String.t()} | {:error, Exception.t()}
  def encode_request(%Request{} = request) do
    request
    |> Map.from_struct()
    |> Jason.encode()
  end

  @spec decode_response(String.t()) ::
          {:ok, Response.t()} | {:error, Exception.t()}
  def decode_response(json) do
    case Jason.decode(json) do
      {:ok, %{"id" => id, "jsonrpc" => jsonrpc, "result" => result}} ->
        {:ok, Response.new(id, jsonrpc, result)}

      {:ok, %{"id" => id, "jsonrpc" => jsonrpc, "error" => error}} ->
        {:ok, Response.new(id, jsonrpc, error)}

      error ->
        {:error, error}
    end
  end
end
