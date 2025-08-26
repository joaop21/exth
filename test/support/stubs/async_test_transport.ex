defmodule Exth.AsyncTestTransport do
  @moduledoc false

  use Exth.Transport

  defstruct [:config]

  @impl Exth.Transport
  def init_transport(opts) do
    {:ok, %Exth.AsyncTestTransport{config: opts}}
  end

  @impl Exth.Transport
  def handle_request(_transport, _request), do: :ok
end
