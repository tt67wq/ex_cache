defmodule ExCache.Typespecs do
  @moduledoc """
  Common type specifications for ExCache implementations.

  This module defines shared types used throughout the ExCache framework.
  Implementations can import or alias these types to ensure consistency
  across different cache backends.

  ## Usage

      defmodule MyCache do
        alias ExCache.Typespecs

        @spec get(Typespecs.name(), Typespecs.k()) :: Typespecs.v()
        def get(name, key), do: ...
      end

  ## Types

  - `name/0` - Cache process identifier
  - `k/0` - Cache key type (any term)
  - `v/0` - Cache value type (any term or nil)
  - `t/0` - Generic cache process identifier
  - `put_opts/0` - Options for put operations
  - `fallback/0` - Fallback function type for fetch operations
  """

  @type name :: atom() | {:global, term()} | {:via, module(), term()}
  @type k :: term()
  @type v :: term() | nil
  @type t :: pid() | {atom(), node()} | name()
  @type put_opts :: [
          {:ttl, pos_integer() | :infinity}
        ]
  @type fallback :: (k() -> {:commit, v()} | {:ignore, v()})
end
