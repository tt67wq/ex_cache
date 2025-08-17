defmodule ExCache.Ets do
  @moduledoc """
  ETS-based cache implementation for ExCache.

  This module provides a cache implementation using ETS (Erlang Term Storage)
  as the underlying storage mechanism. It supports TTL (Time To Live) for automatic
  expiration of cached values.

  ## Features

  - Fast in-memory caching using ETS
  - TTL support with automatic expiration
  - Asynchronous operations (put/delete)
  - Synchronous read operations
  - Automatic cleanup of expired entries

  ## Usage

      # Start a cache process
      {:ok, pid} = ExCache.Ets.start_link(:my_cache)

      # Store a value
      :ok = ExCache.Ets.put(:my_cache, :key, "value")

      # Retrieve a value
      "value" = ExCache.Ets.get(:my_cache, :key)

      # Store with TTL (in milliseconds)
      :ok = ExCache.Ets.put(:my_cache, :temp_key, "temp_value", ttl: 5000)

      # Delete a value
      :ok = ExCache.Ets.del(:my_cache, :key)

  ## Configuration

  The cache process uses a timeout of 5000 milliseconds for cleaning up expired entries.
  This is configurable but should be balanced between cleanup frequency and performance.

  ## Supervisor Integration

  This cache implementation is designed to work with OTP supervisors:

      children = [
        {ExCache.Ets, name: :my_cache}
      ]

      Supervisor.start_link(children, strategy: :one_for_one)
  """

  use ExCache
  use GenServer

  @timeout 5000

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: name)
  end

  @impl ExCache
  @doc """
  Store a key-value pair in the cache.

  ## Parameters

  - `name`: The cache process name or pid
  - `key`: The key to store (any term)
  - `value`: The value to store (any term)
  - `put_opts`: Options for storing

  ## Options

  - `:ttl`: Time to live in milliseconds (default: `:infinity`)

  ## Returns

  `:ok` if the operation was successful

  ## Examples

      iex> ExCache.Ets.put(:my_cache, :key, "value")
      :ok

      iex> ExCache.Ets.put(:my_cache, :temp_key, "temp_value", ttl: 5000)
      :ok
  """
  def put(name, key, value, put_opts \\ []) do
    ttl =
      case Keyword.get(put_opts, :ttl, :infinity) do
        ttl when is_integer(ttl) and ttl > 0 -> ttl
        _ -> :infinity
      end

    GenServer.cast(name, {:put, key, value, ttl: ttl})
  end

  @impl ExCache
  @doc """
  Retrieve a value from the cache.

  ## Parameters

  - `name`: The cache process name or pid
  - `key`: The key to retrieve (any term)

  ## Returns

  - `value` if the key exists and hasn't expired
  - `nil` if the key doesn't exist or has expired

  ## Examples

      iex> ExCache.Ets.put(:my_cache, :key, "value")
      :ok
      iex> ExCache.Ets.get(:my_cache, :key)
      "value"

      iex> ExCache.Ets.get(:my_cache, :nonexistent_key)
      nil
  """
  def get(name, key) do
    GenServer.call(name, {:get, key})
  end

  @impl ExCache
  @doc """
  Delete a key-value pair from the cache.

  ## Parameters

  - `name`: The cache process name or pid
  - `key`: The key to delete (any term)

  ## Returns

  `:ok` if the operation was successful

  ## Examples

      iex> ExCache.Ets.put(:my_cache, :key, "value")
      :ok
      iex> ExCache.Ets.del(:my_cache, :key)
      :ok
      iex> ExCache.Ets.get(:my_cache, :key)
      nil
  """
  def del(name, key) do
    GenServer.cast(name, {:del, key})
  end

  # ------------------- server ----------------------

  defp ets_name(name) do
    :"#{name}_ets"
  end

  @impl GenServer
  def init(name) do
    table = ets_name(name)
    :ets.new(table, [:named_table, :public, :set])
    {:ok, table, @timeout}
  end

  @impl GenServer
  def handle_call({:get, key}, _, table) do
    val =
      case :ets.lookup(table, key) do
        [{^key, value, :infinity}] ->
          value

        [{^key, value, timeout}] when is_integer(timeout) ->
          if timeout < :os.system_time(:millisecond) do
            :ets.delete(table, key)
            nil
          else
            value
          end

        _ ->
          nil
      end

    {:reply, val, table}
  end

  @impl GenServer
  def handle_cast({:del, key}, table) do
    :ets.delete(table, key)
    {:noreply, table}
  end

  def handle_cast({:put, key, value, ttl: :infinity}, table) do
    :ets.insert(table, {key, value, :infinity})
    {:noreply, table}
  end

  def handle_cast({:put, key, value, ttl: ttl}, table) when is_integer(ttl) and ttl > 0 do
    :ets.insert(table, {key, value, :os.system_time(:millisecond) + ttl})
    {:noreply, table}
  end

  def handle_cast({:put, key, value, ttl: _invalid_ttl}, table) do
    # Treat invalid TTL values as infinity
    :ets.insert(table, {key, value, :infinity})
    {:noreply, table}
  end

  @impl GenServer
  def handle_info(:timeout, table) do
    now = :os.system_time(:millisecond)

    :ets.select_delete(
      table,
      [
        {{:"$1", :"$2", :infinity}, [], [false]},
        {{:"$1", :"$2", :"$3"}, [{:<, :"$3", now}], [true]},
        {:_, [], [false]}
      ]
    )

    {:noreply, table, @timeout}
  end
end
