defmodule ExCache do
  @moduledoc """
  Documentation for `ExCache`.
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
  @callback put(t(), k(), v(), put_opts()) :: any()
  @callback del(t(), k()) :: any()

  defmacro __using__(_opts) do
    quote do
      @behaviour ExCache

      @spec fetch(ExCache.t(), ExCache.k(), ExCache.put_opts(), ExCache.fallback()) :: ExCache.v()
      def fetch(t, key, opts, fallback) do
        with nil <- __MODULE__.get(t, key) do
          case fallback.(key) do
            {:commit, value} ->
              __MODULE__.put(t, key, value, opts)
              value

            {:ignore, value} ->
              value
          end
        end
      end
    end
  end
end
