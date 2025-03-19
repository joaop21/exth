defmodule Exiris.Rpc.Encoding do
  @moduledoc """
  Handles encoding and decoding of JSON-RPC requests and responses.
  """

  alias Exiris.Rpc.Response
  alias Exiris.Rpc.Request

  @spec encode_request(Request.t() | [Request.t()]) :: {:ok, String.t()} | {:error, Exception.t()}
  def encode_request(%Request{} = request) do
    request
    |> do_encode_request()
    |> Jason.encode()
  end

  def encode_request(requests) when is_list(requests) do
    requests
    |> Enum.map(&do_encode_request/1)
    |> Jason.encode()
  end

  defp do_encode_request(%Request{} = request), do: Map.from_struct(request)

  @spec decode_response(String.t()) ::
          {:ok, Response.t() | [Response.t()]} | {:error, Exception.t()}
  def decode_response(json) do
    with {:ok, response} <- Jason.decode(json) do
      {:ok, do_decode_response(response)}
    end
  end

  defp do_decode_response(%{"id" => id, "result" => result}), do: Response.success(id, result)

  defp do_decode_response(%{"id" => id, "error" => error}),
    do: Response.error(id, error["code"], error["message"])

  defp do_decode_response(response) when is_list(response) do
    Enum.map(response, &do_decode_response/1)
  end
end
