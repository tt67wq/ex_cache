defmodule ExCache do
  @moduledoc """
  ExCache - A simple cache framework for Elixir.

  This module defines the behaviour that cache implementations should follow.
  It also provides a `__using__` macro that injects common functionality
  including the `fetch/4` function with fallback support.

  ## Usage

      defmodule MyCache do
        use ExCache

        # Implement required callbacks
        @impl ExCache
        def get(name, key), do: ...

        @impl ExCache
        def put(name, key, value, opts \\\\ []), do: ...

        @impl ExCache
        def del(name, key), do: ...
      end
  """
  alias ExCache.Typespecs

  @type name :: term()
  @type t :: pid() | {atom(), node()} | Typespecs.name()
  @type k :: term()
  @type v :: term() | nil
  @type put_opts :: [
          {:ttl, pos_integer() | :infinity}
        ]
  @type fallback :: (k() -> {:commit, v()} | {:ignore, v()})

  @callback get(t(), k()) :: v()
  @callback put(t(), k(), v(), put_opts()) :: :ok
  @callback del(t(), k()) :: :ok

  defmacro __using__(_opts) do
    quote do
      @behaviour ExCache

      @doc """
      Fetch a value from cache with fallback functionality.

      If the key is not found in cache, calls the fallback function.
      The fallback function should return either:
      - `{:commit, value}` - stores the value in cache and returns it
      - `{:ignore, value}` - returns the value without storing it

      ## Examples

          iex> cache.fetch(name, :key, [], fn _key ->
          ...>   {:commit, "computed_value"}
          ...> end)
          "computed_value"
      """
      @spec fetch(ExCache.t(), ExCache.k(), ExCache.put_opts(), ExCache.fallback()) :: ExCache.v()
      def fetch(t, key, opts, fallback) do
        with nil <- __MODULE__.get(t, key) do
          case fallback.(key) do
            {:commit, value} ->
              :ok = __MODULE__.put(t, key, value, opts)
              value

            {:ignore, value} ->
              value
          end
        end
      end

      # Allow override of fetch/4 if needed
      defoverridable fetch: 4
    end
  end
end
