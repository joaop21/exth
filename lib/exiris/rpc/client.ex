defmodule Exiris.Rpc.Client do
  alias Exiris.Transport
  alias Exiris.Rpc.Encoding
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
    opts = build_opts(opts)
    transport = Transport.new(type, opts)

    %__MODULE__{
      counter: :atomics.new(1, signed: false),
      transport: transport
    }
  end

  def request(%__MODULE__{} = client, method, params)
      when is_binary(method) or is_atom(method) do
    id = :atomics.add_get(client.counter, 1, 1)
    Request.new(method, params, id)
  end

  def send(%__MODULE__{} = client, %Request{} = request) do
    Transport.call(client.transport, request)
  end

  defp build_opts(opts) do
    encoder = &Encoding.encode_request/1
    decoder = &Encoding.decode_response/1

    base_opts = Keyword.new(encoder: encoder, decoder: decoder)

    Keyword.merge(base_opts, opts)
  end
end
