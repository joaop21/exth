defmodule Exiris.Transport.Behaviour do
  alias Exiris.Transport
  alias Exiris.Rpc.Request
  alias Exiris.Rpc.Response

  @type t :: module()

  @callback build_opts(opts :: keyword()) :: struct()
  @callback request(transport :: Transport.t(), body :: Request.t()) ::
              {:ok, Response.t()} | {:error, any()}
end
