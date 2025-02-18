defmodule Exiris.RequestCounter do
  @moduledoc """
  Provides a high-performance request counter implementation using :atomics and :persistent_term.
  Counters are stored in :atomics tables and referenced via :persistent_term for fast lookups.
  """

  @type counter_name :: term()
  @type counter_ref :: :atomics.atomics_ref()

  @default_counter_name :global_counter

  @doc """
  Creates a new request counter with the given name.
  The counter starts at 0.

  Returns `:ok` if the counter was created successfully, or `{:error, :already_exists}` 
  if a counter with that name already exists.

  ## Examples

      iex> Exiris.RequestCounter.create(:api_requests)
      :ok

      iex> Exiris.RequestCounter.create(:api_requests)
      {:error, :already_exists}
  """
  @spec create(counter_name()) :: :ok | {:error, :already_exists}
  def create(name \\ @default_counter_name) when is_atom(name) do
    key = build_key(name)

    if counter_exists?(key) do
      {:error, :already_exists}
    else
      counter = :atomics.new(1, signed: false)
      :persistent_term.put(key, counter)
    end
  end

  @doc """
  Creates a new request counter with the given name.
  The counter starts at 0.

  Raises ArgumentError if a counter with the same name already exists.

  ## Examples

      iex> Exiris.RequestCounter.create!(:api_requests)
      :ok

      iex> Exiris.RequestCounter.create!(:api_requests)
      ** (ArgumentError) Counter :api_requests already exists
  """
  @spec create!(counter_name()) :: :ok
  def create!(name \\ @default_counter_name) when is_atom(name) do
    case create(name) do
      :ok ->
        :ok

      {:error, :already_exists} ->
        raise ArgumentError, "Counter #{inspect(name)} already exists"
    end
  end

  @doc """
  Increments the counter by 1 and returns the new value.

  ## Examples

      iex> Exiris.RequestCounter.next(:api_requests)
      1
  """
  @spec next(counter_name()) :: non_neg_integer()
  def next(name \\ @default_counter_name) when is_atom(name) do
    name
    |> get_counter()
    |> :atomics.add_get(1, 1)
  end

  # Private Functions

  @spec get_counter(counter_name()) :: counter_ref()
  defp get_counter(name) do
    try do
      :persistent_term.get(build_key(name))
    rescue
      ArgumentError ->
        raise ArgumentError, "Counter #{inspect(name)} not found. Create it first with create/1"
    end
  end

  @spec build_key(counter_name()) :: {module(), counter_name()}
  defp build_key(name) do
    {__MODULE__, name}
  end

  @spec counter_exists?({module(), counter_name()}) :: boolean()
  defp counter_exists?(key) do
    :persistent_term.get(key, :undefined) != :undefined
  end
end
