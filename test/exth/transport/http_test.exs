defmodule Exth.Transport.HttpTest do
  use ExUnit.Case, async: true

  import Exth.TransportFixtures

  alias Exth.Rpc.Request
  alias Exth.Rpc.Response
  alias Exth.Transport.Http
  alias Tesla.Mock, as: MockAdapter

  @valid_json_headers [{"content-type", "application/json"}]

  setup_all do
    %{
      opts: valid_transport_opts(),
      sample_request: Request.new("eth_blockNumber", [], 1) |> Request.serialize(),
      known_methods: Exth.TestTransport.get_known_methods()
    }
  end

  describe "init_transport/1 - transport initialization" do
    test "creates transport with valid options", %{opts: opts} do
      assert {:ok, %Http{client: %Tesla.Client{}}} = Http.init_transport(opts)
    end

    test "validates required RPC URL", %{opts: opts} do
      opts = Keyword.delete(opts, :rpc_url)

      assert {:error, "RPC URL is required but was not provided"} =
               Http.init_transport(opts)
    end

    test "returns error when RPC URL is not a string", %{opts: opts} do
      opts = Keyword.put(opts, :rpc_url, 123)

      assert {:error, "Invalid RPC URL format: expected string, got: 123"} =
               Http.init_transport(opts)
    end

    test "returns error when RPC URL has an invalid scheme", %{opts: opts} do
      opts = Keyword.put(opts, :rpc_url, "ftp://example.com")

      assert {:error,
              "Invalid RPC URL format: \"ftp://example.com\". The URL must start with http:// or https://"} =
               Http.init_transport(opts)
    end

    test "returns error when RPC URL has no host", %{opts: opts} do
      opts = Keyword.put(opts, :rpc_url, "http://")

      assert {:error, "Invalid RPC URL format: \"http://\". The URL must contain a valid host"} =
               Http.init_transport(opts)
    end

    test "accepts custom headers", %{opts: opts} do
      opts = Keyword.put(opts, :headers, [{"x-api-key", "test"}])

      assert {:ok, transport} = Http.init_transport(opts)
      assert %Tesla.Client{pre: pre} = transport.client
      {_, :call, [headers]} = find_middleware(pre, Tesla.Middleware.Headers)
      assert {"x-api-key", "test"} in headers
    end

    test "sets default headers", %{opts: opts} do
      assert {:ok, transport} = Http.init_transport(opts)

      %Tesla.Client{pre: pre} = transport.client
      {_, :call, [headers]} = find_middleware(pre, Tesla.Middleware.Headers)

      assert {"content-type", "application/json"} in headers
      assert {"user-agent", _} = Enum.find(headers, &(elem(&1, 0) == "user-agent"))
    end

    test "accepts custom timeout", %{opts: opts} do
      timeout = 5_000
      opts = Keyword.put(opts, :timeout, timeout)

      assert {:ok, transport} = Http.init_transport(opts)

      %Tesla.Client{pre: pre} = transport.client
      {_, :call, [middleware]} = find_middleware(pre, Tesla.Middleware.Timeout)
      assert middleware[:timeout] == timeout
    end
  end

  describe "handle_request/2 - RPC requests" do
    setup %{opts: opts} do
      opts = Keyword.put(opts, :adapter, MockAdapter)
      {:ok, transport} = Http.init_transport(opts)
      {:ok, transport: transport}
    end

    test "handles successful response", %{transport: transport, sample_request: request} do
      mock_success("0x1")
      assert {:ok, encoded_response} = Http.handle_request(transport, request)
      assert {:ok, %Response.Success{result: "0x1"}} = Response.deserialize(encoded_response)
    end

    test "handles various successful response types", %{transport: transport} do
      test_cases = [
        {"eth_getLogs", ["0x1", "0x2"]},
        {"eth_getBlock", %{"key" => "value"}},
        {"eth_mining", true},
        {"eth_chainId", 42}
      ]

      for {method, result} <- test_cases do
        mock_success(result)
        encoded_request = Request.new(method, [], 1) |> Request.serialize()
        assert {:ok, encoded_response} = Http.handle_request(transport, encoded_request)
        assert {:ok, %Response.Success{result: ^result}} = Response.deserialize(encoded_response)
      end
    end

    test "handles JSON-RPC error responses", %{transport: transport} do
      error_cases = [
        {-32_700, "Parse error"},
        {-32_600, "Invalid Request"},
        {-32_601, "Method not found"},
        {-32_602, "Invalid params"},
        {-32_603, "Internal error"}
      ]

      for {code, message} <- error_cases do
        mock_error(code, message)
        encoded_request = Request.new("test_method", [], 1) |> Request.serialize()

        assert {:ok, encoded_response} = Http.handle_request(transport, encoded_request)

        assert {:ok, %Response.Error{error: %{code: ^code, message: ^message}}} =
                 Response.deserialize(encoded_response)
      end
    end

    test "handles various HTTP error codes", %{transport: transport, sample_request: request} do
      error_codes = [400, 401, 403, 404, 429, 500, 502, 503]

      for status <- error_codes do
        mock_http_error(status)
        assert {:error, {:http_error, ^status}} = Http.handle_request(transport, request)
      end
    end

    test "handles network errors", %{transport: transport, sample_request: request} do
      network_errors = [:econnrefused, :timeout, :enetunreach, :nxdomain]

      for error <- network_errors do
        MockAdapter.mock(fn %{method: :post} -> {:error, error} end)
        assert {:error, ^error} = Http.handle_request(transport, request)
      end
    end

    test "handles timeout with custom timeout value", %{
      opts: opts,
      sample_request: request
    } do
      opts =
        opts
        |> Keyword.put(:adapter, MockAdapter)
        |> Keyword.put(:timeout, 100)

      {:ok, transport} = Http.init_transport(opts)

      MockAdapter.mock(fn %{method: :post} ->
        Process.sleep(200)
        {:error, :timeout}
      end)

      assert {:error, :timeout} = Http.handle_request(transport, request)
    end
  end

  defp find_middleware(pre, module) do
    Enum.find(pre, &match?({^module, _, _}, &1))
  end

  defp mock_success(result) do
    MockAdapter.mock(fn %{method: :post} ->
      {:ok,
       %Tesla.Env{
         status: 200,
         headers: @valid_json_headers,
         body:
           JSON.encode!(%{
             jsonrpc: "2.0",
             id: 1,
             result: result
           })
       }}
    end)
  end

  defp mock_error(code, message) do
    MockAdapter.mock(fn %{method: :post} ->
      {:ok,
       %Tesla.Env{
         status: 200,
         headers: @valid_json_headers,
         body:
           JSON.encode!(%{
             jsonrpc: "2.0",
             id: 1,
             error: %{
               code: code,
               message: message
             }
           })
       }}
    end)
  end

  defp mock_http_error(status, body \\ "") do
    MockAdapter.mock(fn %{method: :post} ->
      {:ok, %Tesla.Env{status: status, body: body}}
    end)
  end
end
