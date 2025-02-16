defmodule Exiris.Application do
  @moduledoc false

  use Application

  alias Exiris.RequestCounter

  @impl true
  def start(_type, _args) do
    RequestCounter.create!()

    children = []
    opts = [strategy: :one_for_one, name: Exiris.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
