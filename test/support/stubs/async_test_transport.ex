defmodule Exth.AsyncTestTransport do
  @moduledoc false

  defstruct [:config]

  defimpl Exth.Transport.Transportable do
    def new(_transport, opts \\ []), do: %Exth.AsyncTestTransport{config: opts}

    def call(_transport, _encoded_request), do: :ok
  end
end
