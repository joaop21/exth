defmodule Exiris.Rpc.Client do
  alias Exiris.Transport
  alias Exiris.Rpc.JsonRpc.Request
  alias Exiris.Transport.Transportable

  @transport_types [:http, :custom]

  @type t :: %__MODULE__{
          counter: :atomics.atomics_ref(),
          transport: Transportable.t()
        }

  defstruct [:counter, :transport]

  @spec new(Transport.type(), keyword()) :: t()
  def new(type, opts) when type in @transport_types do
    transport = Transport.new(type, opts)

    %__MODULE__{
      counter: :atomics.new(1, signed: false),
      transport: transport
    }
  end

  def request(%__MODULE__{} = client, method, params) do
    id = :atomics.add_get(client.counter, 1, 1)
    Request.new(method, params, id)
  end

  def send_request(%__MODULE__{} = client, request) do
    serialized_request = Request.serialize(request)
    Transport.call(client.transport, serialized_request)
  end
end
