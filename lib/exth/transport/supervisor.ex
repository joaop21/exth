defmodule Exth.Transport.Supervisor do
  @moduledoc false

  use Supervisor

  alias Exth.Transport

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    children = [
      Transport.Registry
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
