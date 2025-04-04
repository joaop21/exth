defmodule Exth.Provider.Validator do
  @moduledoc false

  @required_opts [:transport_type, :rpc_url]

  @doc """
  Validates the configuration options provided to the provider.

  This macro ensures that all required options are present and have valid values.
  It raises an `ArgumentError` if any required options are missing.

  ## Parameters

    * `opts` - Keyword list of provider options
    * `required_opts` - List of required option keys

  ## Raises

    * `ArgumentError` - When required options are missing
  """
  defmacro validate_options!(opts) do
    quote bind_quoted: [opts: opts, required_opts: @required_opts] do
      missing_opts = Enum.reject(required_opts, &Keyword.has_key?(opts, &1))

      unless Enum.empty?(missing_opts) do
        raise ArgumentError, """
        Missing required options: #{inspect(missing_opts)}
        Required options: #{inspect(required_opts)}
        """
      end
    end
  end
end
