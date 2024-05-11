defmodule ExCache.Typespecs do
  @moduledoc """
  types
  """

  @type name :: atom() | {:global, term()} | {:via, module(), term()}
end
