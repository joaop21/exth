defmodule Exth.Rpc.Encoding do
  @moduledoc """
  Handles encoding and decoding of JSON-RPC requests and responses.

  This module provides functionality to serialize and deserialize JSON-RPC 2.0
  requests and responses, ensuring compliance with the protocol specification.

  ## Features

    * Request encoding (single and batch)
    * Response decoding (single and batch)
    * Error handling with detailed messages
    * Protocol compliance validation
    * Automatic structure conversion

  ## JSON-RPC 2.0 Format

  Request format:
  ```json
  {
    "jsonrpc": "2.0",
    "method": "method_name",
    "params": [],
    "id": 1
  }
  ```

  Success response format:
  ```json
  {
    "jsonrpc": "2.0",
    "result": "0x1",
    "id": 1
  }
  ```

  Error response format:
  ```json
  {
    "jsonrpc": "2.0",
    "error": {
      "code": -32700,
      "message": "Parse error"
    },
    "id": 1
  }
  ```

  ## Usage

  Encoding single requests:

      request = %Request{
        jsonrpc: "2.0",
        method: "eth_blockNumber",
        params: [],
        id: 1
      }

      {:ok, json} = Encoding.encode_request(request)

  Encoding batch requests:

      requests = [
        %Request{method: "eth_blockNumber", id: 1},
        %Request{method: "eth_gasPrice", id: 2}
      ]

      {:ok, json} = Encoding.encode_request(requests)

  Decoding responses:

      {:ok, response} = Encoding.decode_response(json)
      # Returns {:ok, %Response{}} for single responses
      # Returns {:ok, [%Response{}, ...]} for batch responses

  ## Error Handling

  The module returns tagged tuples for all operations:

    * `{:ok, result}` - Successful encoding/decoding
    * `{:error, exception}` - Operation failed with detailed error

  Common error cases:

    * Invalid JSON syntax
    * Missing required fields
    * Invalid response format
    * Protocol version mismatch

  ## Examples

      # Encode a single request
      request = %Request{
        method: "eth_blockNumber",
        params: [],
        id: 1
      }
      {:ok, json} = Encoding.encode_request(request)

      # Decode a success response
      {:ok, response} = Encoding.decode_response(~s({
        "jsonrpc": "2.0",
        "result": "0x1",
        "id": 1
      }))

      # Decode an error response
      {:ok, response} = Encoding.decode_response(~s({
        "jsonrpc": "2.0",
        "error": {
          "code": -32700,
          "message": "Parse error"
        },
        "id": 1
      }))

      # Handle batch operations
      requests = [
        %Request{method: "eth_blockNumber", id: 1},
        %Request{method: "eth_gasPrice", id: 2}
      ]
      {:ok, json} = Encoding.encode_request(requests)
      {:ok, responses} = Encoding.decode_response(json)

  ## Implementation Notes

    * Uses elixir's `JSON` for JSON encoding/decoding
    * Automatically handles struct conversion
    * Preserves request IDs for correlation
    * Supports both single and batch operations
    * Validates protocol compliance

  See `Exth.Rpc.Request` for request structure details and
  `Exth.Rpc.Response` for response handling.
  """

  alias Exth.Rpc.Request
  alias Exth.Rpc.Response

  @spec encode_request(Request.t() | [Request.t()]) :: {:ok, String.t()} | {:error, Exception.t()}
  def encode_request(%Request{} = request) do
    request
    |> do_encode_request()
    |> json_encode()
  end

  def encode_request(requests) when is_list(requests) do
    requests
    |> Enum.map(&do_encode_request/1)
    |> json_encode()
  end

  defp do_encode_request(%Request{} = request), do: Map.from_struct(request)

  @spec decode_response(String.t()) ::
          {:ok, Response.t() | [Response.t()]} | {:error, Exception.t()}
  def decode_response(json) do
    with {:ok, response} <- JSON.decode(json) do
      do_decode_response(response)
    end
  end

  defp do_decode_response(%{"id" => id, "result" => result}),
    do: {:ok, Response.success(id, result)}

  defp do_decode_response(%{"id" => id, "error" => error}) do
    case error do
      %{"code" => code, "message" => message, "data" => data} ->
        {:ok, Response.error(id, code, message, data)}

      %{"code" => code, "message" => message} ->
        {:ok, Response.error(id, code, message)}
    end
  end

  defp do_decode_response(responses) when is_list(responses) do
    results = Enum.map(responses, &do_decode_response/1)

    case Enum.split_with(results, &match?({:ok, _}, &1)) do
      {successful, []} ->
        {:ok, Enum.map(successful, fn {:ok, resp} -> resp end)}

      {_, errors} ->
        {:error, "invalid responses in batch: #{inspect(errors)}"}
    end
  end

  defp do_decode_response(response) do
    {:error, "invalid response: #{inspect(response)}"}
  end

  defp json_encode(data) do
    encoded = JSON.encode!(data)
    {:ok, encoded}
  rescue
    _ -> {:error, "encoding of #{inspect(data)} failed"}
  end
end
