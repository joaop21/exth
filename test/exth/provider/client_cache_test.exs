defmodule Exth.Provider.ClientCacheTest do
  @moduledoc false

  # We can't use async: true because we're using :persistent_term
  # which is a global shared storage in the Erlang VM.
  # When tests run asynchronously (async: true), multiple tests run in parallel
  # in different processes. This could cause race conditions and inconsistent 
  # test results because:
  # 1. Multiple tests would be reading/writing to the same global 
  # `:persistent_term` storage
  # 2. The `setup` block that erases the persistent term 
  # (`:persistent_term.erase({ClientCache, @test_transport, @test_url})`) could
  # interfere with other concurrent tests
  # 3. Tests like "cache persistence" that verify behavior across process 
  # boundaries could be affected by other tests modifying the same global state
  #
  # For example, if these tests ran in parallel:
  # - Test A creates a client in persistent_term
  # - Test B runs setup and erases that client
  # - Test A fails because its client unexpectedly disappeared

  use ExUnit.Case

  import Exth.TestHelpers

  alias Exth.Provider.ClientCache
  alias Exth.Rpc.Client
  alias Exth.TestTransport

  @test_url generate_rpc_url()
  @test_transport :http

  setup do
    client = %Client{
      transport: TestTransport,
      counter: :atomics.new(1, [])
    }

    :persistent_term.erase({ClientCache, @test_transport, @test_url})

    {:ok, client: client}
  end

  describe "get_client/2" do
    test "returns {:error, :not_found} when client is not cached" do
      assert {:error, :not_found} = ClientCache.get_client(@test_transport, @test_url)
    end

    test "returns {:ok, client} when client exists", %{client: client} do
      ClientCache.create_client(@test_transport, @test_url, client)

      assert {:ok, cached_client} = ClientCache.get_client(@test_transport, @test_url)
      assert %Client{} = cached_client
      assert cached_client == client
    end

    test "handles different transport types", %{client: client} do
      ClientCache.create_client(:websocket, @test_url, client)
      assert {:ok, _} = ClientCache.get_client(:websocket, @test_url)
      assert {:error, :not_found} = ClientCache.get_client(:http, @test_url)
    end

    test "handles different URLs", %{client: client} do
      url1 = generate_rpc_url()
      url2 = generate_rpc_url()

      ClientCache.create_client(@test_transport, url1, client)
      assert {:ok, _} = ClientCache.get_client(@test_transport, url1)
      assert {:error, :not_found} = ClientCache.get_client(@test_transport, url2)
    end
  end

  describe "create_client/3" do
    test "successfully caches a client", %{client: client} do
      cached = ClientCache.create_client(@test_transport, @test_url, client)
      assert cached == client
      assert {:ok, ^client} = ClientCache.get_client(@test_transport, @test_url)
    end

    test "overwrites existing client", %{client: client} do
      ClientCache.create_client(@test_transport, @test_url, client)

      new_client = %{client | transport: Exth.Transport.Http}
      ClientCache.create_client(@test_transport, @test_url, new_client)

      assert {:ok, cached_client} = ClientCache.get_client(@test_transport, @test_url)
      assert cached_client == new_client
      refute cached_client == client
    end

    test "caches multiple clients with different keys", %{client: client} do
      url1 = generate_rpc_url()
      url2 = generate_rpc_url()

      client1 = ClientCache.create_client(@test_transport, url1, client)
      client2 = ClientCache.create_client(@test_transport, url2, client)

      assert {:ok, ^client1} = ClientCache.get_client(@test_transport, url1)
      assert {:ok, ^client2} = ClientCache.get_client(@test_transport, url2)
    end
  end

  describe "cache persistence" do
    test "client survives process termination", %{client: client} do
      # Cache client in a separate process
      task =
        Task.async(fn ->
          ClientCache.create_client(@test_transport, @test_url, client)
        end)

      Task.await(task)

      # Verify client is still cached after process exits
      assert {:ok, cached_client} = ClientCache.get_client(@test_transport, @test_url)
      assert cached_client == client
    end

    test "handles concurrent access", %{client: client} do
      tasks =
        for i <- 1..10 do
          url = "https://eth#{i}.example.com"

          Task.async(fn ->
            ClientCache.create_client(@test_transport, url, client)
            # Simulate random timing
            Process.sleep(Enum.random(1..10))
            ClientCache.get_client(@test_transport, url)
          end)
        end

      results = Task.await_many(tasks)
      assert Enum.all?(results, &match?({:ok, %Client{}}, &1))
    end

    test "memory usage remains stable with many clients", %{client: client} do
      initial_memory = :erlang.memory(:total)

      # Create many clients
      for i <- 1..1000 do
        url = "https://eth#{i}.example.com"
        ClientCache.create_client(@test_transport, url, client)
      end

      final_memory = :erlang.memory(:total)
      memory_increase = final_memory - initial_memory

      # Memory increase should be reasonable (less than 10MB for 1000 clients)
      assert memory_increase < 10 * 1024 * 1024
    end
  end

  describe "documentation" do
    test "module documentation examples work" do
      # Add tests for @moduledoc examples here
    end

    test "function documentation examples work" do
      # Add tests for @doc examples here
    end
  end
end
