defmodule Exth.Transport.Registry do
  @moduledoc false

  @spec start_link() :: {:ok, pid()} | {:error, term()}
  def start_link do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  @spec via_tuple(any()) :: {:via, Registry, {__MODULE__, any()}}
  def via_tuple(key) do
    {:via, Registry, {__MODULE__, key}}
  end

  @spec child_spec(any()) :: Supervisor.child_spec()
  def child_spec(_opts) do
    Supervisor.child_spec(Registry, id: __MODULE__, start: {__MODULE__, :start_link, []})
  end
end
