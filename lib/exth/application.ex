defmodule Exth.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Exth.Transport.Supervisor
    ]

    opts = [strategy: :one_for_one, name: Exth.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
