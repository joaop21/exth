defmodule Exth.ProviderTest do
  # This is the samme as ClientCacheTest. We can't use async: true because we're
  # using :persistent_term
  use ExUnit.Case

  import Exth.TestHelpers

  doctest Exth.Provider

  # Test implementation of Provider
  defmodule TestProvider do
    use Exth.Provider,
      transport_type: :http,
      rpc_url: generate_rpc_url()
  end

  describe "configuration validation" do
    test "raises when required options are missing" do
      assert_raise ArgumentError, ~r/Missing required options/, fn ->
        defmodule InvalidProvider do
          use Exth.Provider
        end
      end

      assert_raise ArgumentError, ~r/Missing required options.*:rpc_url/, fn ->
        defmodule PartialProvider do
          use Exth.Provider, transport_type: :http
        end
      end
    end

    test "accepts valid configuration" do
      defmodule ValidProvider do
        use Exth.Provider,
          transport_type: :http,
          rpc_url: generate_rpc_url()
      end

      assert {:module, ValidProvider} = Code.ensure_compiled(ValidProvider)
    end
  end

  describe "method generation" do
    test "generates methods defined in Methods module" do
      methods = TestProvider.__info__(:functions)
      assert Keyword.has_key?(methods, :block_number)
      assert Keyword.has_key?(methods, :get_balance)
      assert Keyword.has_key?(methods, :get_block_by_number)
    end

    test "generated methods have correct arity" do
      methods = TestProvider.__info__(:functions)
      assert methods[:block_number] == 0
      # /1, address
      # /2, address, block_tag
      assert Keyword.get_values(methods, :get_balance) == [1, 2]
      # block_number, full_txs
      assert methods[:get_block_by_number] == 2
    end
  end

  describe "client management" do
    test "get_client returns a client" do
      client = TestProvider.get_client()
      assert is_map(client)
    end

    test "get_client returns the same client on subsequent calls" do
      client1 = TestProvider.get_client()
      client2 = TestProvider.get_client()
      assert client1 == client2
    end
  end

  describe "provider interface" do
    test "eth_getBalance has correct function signature" do
      {:arity, 2} =
        :erlang.fun_info(
          &TestProvider.get_balance/2,
          :arity
        )
    end

    test "eth_blockNumber has correct function signature" do
      {:arity, 0} =
        :erlang.fun_info(
          &TestProvider.block_number/0,
          :arity
        )
    end

    test "eth_getBlockByNumber has correct function signature" do
      {:arity, 2} =
        :erlang.fun_info(
          &TestProvider.get_block_by_number/2,
          :arity
        )
    end
  end
end
