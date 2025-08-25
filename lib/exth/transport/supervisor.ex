defmodule Exth.Transport.Supervisor do
  @moduledoc """
  Supervisor for transport-related processes.

  This module supervises the transport registry and dynamic supervisors for IPC and WebSocket
  connections, ensuring proper lifecycle management of transport resources.
  """

  use Supervisor

  alias Exth.Transport

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    children = [
      Transport.Registry,
      Transport.Ipc.DynamicSupervisor,
      Transport.Websocket.DynamicSupervisor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
