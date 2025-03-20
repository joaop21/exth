defmodule Exiris.Provider.ClientCache do
  alias Exiris.Rpc.Client

  @spec get_client(Exiris.Transport.type(), String.t()) ::
          {:ok, Client.t()} | {:error, :not_found}
  def get_client(transport_type, rpc_url) do
    try do
      %Client{} = client = :persistent_term.get(build_key(transport_type, rpc_url))
      {:ok, client}
    rescue
      ArgumentError ->
        {:error, :not_found}
    end
  end

  @spec create_client(Exiris.Transport.type(), String.t(), Client.t()) :: Client.t()
  def create_client(transport_type, rpc_url, client) do
    with :ok <- :persistent_term.put(build_key(transport_type, rpc_url), client) do
      client
    end
  end

  defp build_key(transport_type, rpc_url), do: {__MODULE__, transport_type, rpc_url}
end
