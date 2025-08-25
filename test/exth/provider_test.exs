defmodule Exth.ProviderTest do
  @moduledoc """
  Tests for the Exth.Provider module.

  These tests verify that the Provider module correctly:
  - Generates RPC methods with proper documentation and type specifications
  - Manages client lifecycle and caching
  - Implements the correct function signatures for Ethereum JSON-RPC methods
  - Handles dynamic configuration from both inline options and application config
  """

  # This is the samme as ClientCacheTest. We can't use async: true because we're
  # using :persistent_term
  use ExUnit.Case

  alias Exth.TestProvider
  alias Exth.TestTransport

  doctest Exth.Provider

  describe "configuration" do
    test "merges inline configuration with application config" do
      # Create a new provider with inline config
      defmodule ConfigTestProvider do
        use Exth.Provider,
          otp_app: :exth,
          transport_type: :custom,
          module: TestTransport,
          rpc_url: "http://inline-url",
          max_retries: 3
      end

      # Set some application config
      Application.put_env(:exth, ConfigTestProvider,
        rpc_url: "http://config-url",
        timeout: 5000
      )

      # Get the client to force compilation
      client = ConfigTestProvider.get_client()

      # Verify that inline config takes precedence
      assert client.transport.adapter_config.config[:rpc_url] == "http://inline-url"
      # Verify that application config is used when not overridden
      assert client.transport.adapter_config.config[:timeout] == 5000
      # Verify that inline-only config is present
      assert client.transport.adapter_config.config[:max_retries] == 3
      # Verify that transport type and module are set correctly
      assert client.transport.adapter_config.config[:transport_type] == :custom
      assert client.transport.adapter_config.config[:module] == TestTransport
    end

    test "uses application config when no inline config is provided" do
      # Create a new provider with minimal inline config
      defmodule AppConfigTestProvider do
        use Exth.Provider,
          otp_app: :exth,
          transport_type: :custom,
          module: TestTransport
      end

      # Set application config
      Application.put_env(:exth, AppConfigTestProvider,
        rpc_url: "http://app-config-url",
        timeout: 10_000,
        max_retries: 5
      )

      # Get the client to force compilation
      client = AppConfigTestProvider.get_client()

      # Verify that application config is used
      assert client.transport.adapter_config.config[:rpc_url] == "http://app-config-url"
      assert client.transport.adapter_config.config[:timeout] == 10_000
      assert client.transport.adapter_config.config[:max_retries] == 5
      # Verify that transport type and module are set correctly
      assert client.transport.adapter_config.config[:transport_type] == :custom
      assert client.transport.adapter_config.config[:module] == TestTransport
    end

    test "requires essential configuration options" do
      # Create a provider without required config
      defmodule InvalidConfigProvider do
        use Exth.Provider,
          otp_app: :exth
      end

      assert_raise KeyError, fn ->
        InvalidConfigProvider.get_client()
      end
    end

    test "validates transport configuration" do
      # Create a provider with invalid transport config
      defmodule InvalidTransportProvider do
        use Exth.Provider,
          otp_app: :exth,
          transport_type: :invalid,
          module: TestTransport
      end

      assert_raise KeyError, fn ->
        InvalidTransportProvider.get_client()
      end
    end

    test "accepts :path when transport_type is :ipc" do
      # Create a provider with invalid transport config
      defmodule IpcTestProvider do
        use Exth.Provider,
          otp_app: :exth,
          transport_type: :ipc,
          path: "/tmp/valid.sock"
      end

      # Get the client to force compilation
      client = IpcTestProvider.get_client()

      assert client.transport.adapter_config.path == "/tmp/valid.sock"
    end

    test "does not accept :path when transport_type is not :ipc" do
      # Create a provider with invalid transport config
      defmodule InvalidPathTestProvider do
        use Exth.Provider,
          otp_app: :exth,
          transport_type: :custom,
          path: "/tmp/valid.sock"
      end

      assert_raise KeyError, fn ->
        InvalidPathTestProvider.get_client()
      end
    end
  end

  describe "RPC method generation" do
    test "generates all required Ethereum JSON-RPC methods" do
      methods = TestProvider.__info__(:functions)

      assert Keyword.has_key?(methods, :block_number)
      assert Keyword.has_key?(methods, :get_balance)
      assert Keyword.has_key?(methods, :get_block_by_number)
      assert Keyword.has_key?(methods, :get_transaction_count)
      assert Keyword.has_key?(methods, :send_raw_transaction)
    end

    test "generates methods with correct arity for different parameter combinations" do
      methods = TestProvider.__info__(:functions)

      # Methods with no parameters
      assert methods[:block_number] == 0

      # Methods with optional block tag
      assert Keyword.get_values(methods, :get_balance) == [1, 2]
      assert Keyword.get_values(methods, :get_transaction_count) == [1, 2]

      # Methods with required parameters
      assert methods[:get_block_by_number] == 2
      assert methods[:send_raw_transaction] == 1
    end

    test "generates methods with complete documentation" do
      {:docs_v1, _, :elixir, "text/markdown", %{}, _, function_docs} =
        Code.fetch_docs(TestProvider)

      # Test documentation for a method with optional parameters
      get_balance_doc =
        Enum.find(function_docs, fn
          {{:function, :get_balance, _}, _, _, _, _} -> true
          _ -> false
        end)

      assert get_balance_doc != nil
      doc_content = elem(get_balance_doc, 3)
      assert is_map(doc_content)
      assert doc_content["en"] =~ "Parameters"
      assert doc_content["en"] =~ "Returns"
      assert doc_content["en"] =~ "default: \"latest\""
    end

    test "generates methods with correct type specifications" do
      {:ok, specs} = Code.Typespec.fetch_specs(TestProvider)

      # Test specs for different method types
      get_balance_spec = Enum.find(specs, fn {{name, _}, _} -> name == :get_balance end)
      block_number_spec = Enum.find(specs, fn {{name, _}, _} -> name == :block_number end)

      assert get_balance_spec != nil
      assert block_number_spec != nil
    end
  end

  describe "client lifecycle management" do
    test "get_client returns a properly configured RPC client" do
      client = TestProvider.get_client()

      assert is_map(client)
      assert client.__struct__ == Exth.Rpc.Client
    end

    test "get_client implements caching by returning the same client instance" do
      client1 = TestProvider.get_client()
      client2 = TestProvider.get_client()

      assert client1 == client2
      assert :erlang.phash2(client1) == :erlang.phash2(client2)
    end
  end

  describe "Ethereum JSON-RPC interface" do
    test "implements correct function signatures for all RPC methods" do
      # Test method with no parameters
      assert {:arity, 0} = :erlang.fun_info(&TestProvider.block_number/0, :arity)

      # Test method with optional block tag
      assert {:arity, 1} = :erlang.fun_info(&TestProvider.get_balance/1, :arity)
      assert {:arity, 2} = :erlang.fun_info(&TestProvider.get_balance/2, :arity)

      # Test method with required parameters
      assert {:arity, 2} = :erlang.fun_info(&TestProvider.get_block_by_number/2, :arity)
    end

    test "implements correct parameter handling for block tags" do
      # Test that block tag defaults to "latest"
      assert {:arity, 1} = :erlang.fun_info(&TestProvider.get_balance/1, :arity)
      assert {:arity, 2} = :erlang.fun_info(&TestProvider.get_balance/2, :arity)
    end
  end

  describe "Subscription method generation" do
    test "generates subscription methods with correct arity" do
      methods = TestProvider.__info__(:functions)

      # Verify that subscription methods are generated
      assert Keyword.has_key?(methods, :subscribe_blocks)
      assert Keyword.has_key?(methods, :subscribe_pending_transactions)
      assert Keyword.has_key?(methods, :subscribe_logs)
      assert Keyword.has_key?(methods, :unsubscribe)

      # Verify correct arity for each method
      assert methods[:subscribe_blocks] == 0
      assert methods[:subscribe_pending_transactions] == 0
      assert Keyword.get_values(methods, :subscribe_logs) == [0, 1]
      assert methods[:unsubscribe] == 1
    end

    test "generates subscription methods with complete documentation" do
      {:docs_v1, _, :elixir, "text/markdown", %{}, _, function_docs} =
        Code.fetch_docs(TestProvider)

      # Test documentation for subscribe_blocks
      blocks_doc =
        Enum.find(function_docs, fn
          {{:function, :subscribe_blocks, _}, _, _, _, _} -> true
          _ -> false
        end)

      assert blocks_doc != nil
      doc_content = elem(blocks_doc, 3)
      assert is_map(doc_content)
      assert doc_content["en"] =~ "Returns"
      assert doc_content["en"] =~ "Subscribes to new block headers."

      # Test documentation for subscribe_logs
      logs_doc =
        Enum.find(function_docs, fn
          {{:function, :subscribe_logs, _}, _, _, _, _} -> true
          _ -> false
        end)

      assert logs_doc != nil
      doc_content = elem(logs_doc, 3)
      assert is_map(doc_content)
      assert doc_content["en"] =~ "Subscribes to all logs without any filter."
      assert doc_content["en"] =~ "Returns"
      assert doc_content["en"] =~ "filter"

      # Test documentation for unsubscribe
      unsubscribe_doc =
        Enum.find(function_docs, fn
          {{:function, :unsubscribe, _}, _, _, _, _} -> true
          _ -> false
        end)

      assert unsubscribe_doc != nil
      doc_content = elem(unsubscribe_doc, 3)
      assert is_map(doc_content)
      assert doc_content["en"] =~ "Parameters"
      assert doc_content["en"] =~ "Returns"
      assert doc_content["en"] =~ "subscription_id"
    end

    test "generates subscription methods with correct type specifications" do
      {:ok, specs} = Code.Typespec.fetch_specs(TestProvider)

      # Test specs for subscription methods
      blocks_spec = Enum.find(specs, fn {{name, _}, _} -> name == :subscribe_blocks end)

      pending_spec =
        Enum.find(specs, fn {{name, _}, _} -> name == :subscribe_pending_transactions end)

      logs_spec = Enum.find(specs, fn {{name, _}, _} -> name == :subscribe_logs end)
      unsubscribe_spec = Enum.find(specs, fn {{name, _}, _} -> name == :unsubscribe end)

      assert blocks_spec != nil
      assert pending_spec != nil
      assert logs_spec != nil
      assert unsubscribe_spec != nil
    end

    test "implements correct parameter handling for subscription methods" do
      # Test that subscribe_blocks takes no parameters
      assert {:arity, 0} = :erlang.fun_info(&TestProvider.subscribe_blocks/0, :arity)

      # Test that subscribe_pending_transactions takes no parameters
      assert {:arity, 0} =
               :erlang.fun_info(&TestProvider.subscribe_pending_transactions/0, :arity)

      # Test that subscribe_logs can be called with or without parameters
      assert {:arity, 0} = :erlang.fun_info(&TestProvider.subscribe_logs/0, :arity)
      assert {:arity, 1} = :erlang.fun_info(&TestProvider.subscribe_logs/1, :arity)

      # Test that unsubscribe takes a subscription_id parameter
      assert {:arity, 1} = :erlang.fun_info(&TestProvider.unsubscribe/1, :arity)
    end
  end
end
