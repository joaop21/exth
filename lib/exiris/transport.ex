defmodule Exiris.Transport do
  @moduledoc """
  Defines a behavior for transport modules (HTTP, WebSocket, IPC).
  """

  alias Exiris.Rpc.Request
  alias Exiris.Rpc.Response
  alias __MODULE__.Http

  @type type :: :custom | :http
  @type encoder :: (Request.t() -> String.t())
  @type decoder :: (String.t() -> Response.t())

  @type t :: %__MODULE__{
          decoder: encoder(),
          encoder: decoder(),
          module: __MODULE__.Behaviour.t() | nil,
          opts: Http.opts() | map(),
          rpc_url: String.t(),
          type: type()
        }

  defstruct [
    :rpc_url,
    :encoder,
    :decoder,
    :module,
    :opts,
    :type
  ]

  ### 
  ### Public Functions
  ###

  @behaviour __MODULE__.Behaviour

  @impl true
  def build_opts(opts) do
    rpc_url = opts[:rpc_url] || raise ArgumentError, "missing required option :rpc_url"
    encoder = opts[:encoder]
    decoder = opts[:decoder]
    type = opts[:transport_type]

    module =
      case type do
        :http -> Exiris.Transport.Http
        :custom -> opts[:module] || raise ArgumentError, "missing required option :module"
        _ -> raise(ArgumentError, "invalid transport type: #{inspect(type)}")
      end

    # transport specific options
    transport_opts = module.build_opts(opts[:opts] || [])

    %__MODULE__{
      rpc_url: rpc_url,
      encoder: encoder,
      decoder: decoder,
      opts: transport_opts,
      type: type,
      module: module
    }
  end

  @impl true
  def request(%__MODULE__{} = transport, body) do
    transport.module.request(transport, body)
  end

  @spec new(type(), keyword()) :: __MODULE__.t()
  def new(type, opts \\ []) do
    opts = Keyword.merge(opts, transport_type: type)
    build_opts(opts)
  end
end
