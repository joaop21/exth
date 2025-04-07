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
      base_opts: valid_transport_opts(),
      sample_request: Request.new("eth_blockNumber", [], 1),
      known_methods: Exth.TestTransport.get_known_methods()
    }
  end

  describe "new/1 - transport initialization" do
    setup %{base_opts: base_opts} do
      {:ok, opts: base_opts}
    end

    test "creates transport with valid options", %{opts: opts} do
      assert %Http{client: %Tesla.Client{}} = Http.new(opts)
    end

    test "validates required RPC URL", %{opts: opts} do
      assert_raise ArgumentError, ~r/RPC URL is required/, fn ->
        Http.new(opts |> Keyword.delete(:rpc_url))
      end
    end

    test "validates URL format" do
      invalid_urls = [
        "not-a-url",
        "ftp://example.com",
        "http:/invalid",
        123
      ]

      for url <- invalid_urls do
        assert_raise ArgumentError, ~r/Invalid RPC URL/, fn ->
          Http.new(Keyword.put(valid_transport_opts(), :rpc_url, url))
        end
      end
    end

    test "validates decoder function", %{opts: opts} do
      opts = Keyword.delete(opts, :decoder)

      assert_raise ArgumentError, ~r/decoder function is required/, fn ->
        Http.new(opts)
      end

      assert_raise ArgumentError, ~r/Invalid decoder/, fn ->
        Http.new(opts |> Keyword.put(:decoder, "not a function"))
      end
    end

    test "accepts custom headers", %{opts: opts} do
      opts = Keyword.put(opts, :headers, [{"x-api-key", "test"}])
      transport = Http.new(opts)

      assert %Tesla.Client{pre: pre} = transport.client
      {_, :call, [headers]} = find_middleware(pre, Tesla.Middleware.Headers)
      assert {"x-api-key", "test"} in headers
    end

    test "sets default headers", %{opts: opts} do
      transport = Http.new(opts)
      %Tesla.Client{pre: pre} = transport.client
      {_, :call, [headers]} = find_middleware(pre, Tesla.Middleware.Headers)

      assert {"content-type", "application/json"} in headers
      assert {"user-agent", _} = Enum.find(headers, &(elem(&1, 0) == "user-agent"))
    end

    test "accepts custom timeout", %{opts: base_opts} do
      timeout = 5_000
      opts = Keyword.put(base_opts, :timeout, timeout)
      transport = Http.new(opts)

      %Tesla.Client{pre: pre} = transport.client
      {_, :call, [middleware]} = find_middleware(pre, Tesla.Middleware.Timeout)
      assert middleware[:timeout] == timeout
    end
  end

  describe "call/2 - RPC requests" do
    setup %{base_opts: base_opts} do
      opts = Keyword.put(base_opts, :adapter, MockAdapter)
      transport = Http.new(opts)
      {:ok, transport: transport}
    end

    test "handles successful response", %{transport: transport, sample_request: request} do
      mock_success("0x1")
      assert {:ok, %Response.Success{result: "0x1"}} = Http.call(transport, request)
    end

    test "handles various successful response types", %{transport: transport} do
      test_cases = [
        {["0x1", "0x2"], "eth_getLogs"},
        {%{"key" => "value"}, "eth_getBlock"},
        {true, "eth_mining"},
        {42, "eth_chainId"}
      ]

      for {result, method} <- test_cases do
        mock_success(result)
        request = Request.new(method, [], 1)
        assert {:ok, %Response.Success{result: ^result}} = Http.call(transport, request)
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
        request = Request.new("test_method", [], 1)

        assert {:ok, %Response.Error{error: %{code: ^code, message: ^message}}} =
                 Http.call(transport, request)
      end
    end

    test "handles various HTTP error codes", %{transport: transport, sample_request: request} do
      error_codes = [400, 401, 403, 404, 429, 500, 502, 503]

      for status <- error_codes do
        mock_http_error(status)
        assert {:error, {:http_error, ^status}} = Http.call(transport, request)
      end
    end

    test "handles network errors", %{transport: transport, sample_request: request} do
      network_errors = [:econnrefused, :timeout, :enetunreach, :nxdomain]

      for error <- network_errors do
        MockAdapter.mock(fn %{method: :post} -> {:error, error} end)
        assert {:error, ^error} = Http.call(transport, request)
      end
    end

    test "handles timeout with custom timeout value", %{
      base_opts: base_opts,
      sample_request: request
    } do
      opts =
        base_opts
        |> Keyword.put(:adapter, MockAdapter)
        |> Keyword.put(:timeout, 100)

      transport = Http.new(opts)

      MockAdapter.mock(fn %{method: :post} ->
        Process.sleep(200)
        {:error, :timeout}
      end)

      assert {:error, :timeout} = Http.call(transport, request)
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
