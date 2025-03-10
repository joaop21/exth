defmodule Exiris.Rpc.Encoding do
  @moduledoc """
  Handles encoding and decoding of JSON-RPC requests and responses.
  """

  alias Exiris.Rpc.JsonRpc.Response
  alias Exiris.Rpc.JsonRpc.Request

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
      {:ok, %{"id" => id, "result" => result}} ->
        {:ok, Response.success(id, result)}

      {:ok, %{"id" => id, "error" => error}} ->
        {:ok, Response.error(id, error["code"], error["message"])}

      error ->
        {:error, error}
    end
  end
end
