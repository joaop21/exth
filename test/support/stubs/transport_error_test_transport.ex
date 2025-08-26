defmodule Exth.TransportErrorTestTransport do
  @moduledoc false
  use Exth.Transport

  defstruct [:config]

  @impl Exth.Transport
  def init_transport(opts) do
    {:ok, %Exth.TransportErrorTestTransport{config: opts}}
  end

  @impl Exth.Transport
  def handle_request(_transport, _request) do
    {:error, ConnectionRefusedException.exception(message: "connection_refused")}
  end
end

defmodule ConnectionRefusedException do
  defexception [:message]
end
