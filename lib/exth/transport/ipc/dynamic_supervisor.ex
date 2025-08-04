defmodule Exth.Transport.Ipc.DynamicSupervisor do
  @moduledoc false

  use DynamicSupervisor

  def start_link do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end

  def start_pool(pool_spec) do
    DynamicSupervisor.start_child(__MODULE__, pool_spec)
  end
end
