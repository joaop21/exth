defmodule Exth.TransportErrorTestTransport do
  @moduledoc false
  defstruct [:config]
end

defmodule ConnectionRefusedException do
  defexception [:message]
end

defimpl Exth.Transport.Transportable, for: Exth.TransportErrorTestTransport do
  def new(_transport, opts), do: %Exth.TransportErrorTestTransport{config: opts}

  def call(_transport, _request),
    do: {:error, ConnectionRefusedException.exception(message: "connection_refused")}
end
