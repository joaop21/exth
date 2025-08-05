defmodule Examples.Provider.IpcEthereum do
  @moduledoc false

  use Exth.Provider,
    transport_type: :ipc,
    path: "/tmp/anvil.ipc",
    timeout: 30_000,
    pool_size: 3,
    socket_opts: [:binary, active: false, reuseaddr: true]
end
