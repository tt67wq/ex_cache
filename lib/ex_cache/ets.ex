defmodule ExCache.Ets do
  @moduledoc """
  ETS-based cache implementation for ExCache.

  This module provides a cache implementation using ETS (Erlang Term Storage)
  as the underlying storage mechanism. It supports TTL (Time To Live) for automatic
  expiration of cached values and comprehensive statistics tracking.

  ## Features

  - Fast in-memory caching using ETS
  - TTL support with automatic expiration
  - Asynchronous operations (put/delete)
  - Synchronous read operations
  - Automatic cleanup of expired entries
  - Cache statistics and performance monitoring

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

  ## Statistics

  The cache provides comprehensive statistics that can be retrieved using `stats/1`:

      # Get cache statistics
      stats = ExCache.Ets.stats(:my_cache)
      # => %{
      #   hits: 150,
      #   misses: 25,
      #   puts: 175,
      #   deletes: 30,
      #   total_operations: 380
      # }

  Statistics can be reset using `reset_stats/1`:

      # Reset all statistics
      :ok = ExCache.Ets.reset_stats(:my_cache)
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

  @doc """
  Get cache statistics.

  ## Parameters

  - `name`: The cache process name or pid

  ## Returns

  A map containing cache statistics:
  - `:hits` - Number of cache hits
  - `:misses` - Number of cache misses
  - `:puts` - Number of put operations
  - `:deletes` - Number of delete operations
  - `:total_operations` - Total number of operations

  ## Examples

      iex> ExCache.Ets.put(:my_cache, :key, "value")
      :ok
      iex> ExCache.Ets.get(:my_cache, :key)
      "value"
      iex> stats = ExCache.Ets.stats(:my_cache)
      iex> stats.hits
      1
      iex> stats.puts
      1
  """
  @spec stats(ExCache.t()) :: %{
          hits: non_neg_integer(),
          misses: non_neg_integer(),
          puts: non_neg_integer(),
          deletes: non_neg_integer(),
          total_operations: non_neg_integer()
        }
  def stats(name) do
    GenServer.call(name, :stats)
  end

  @doc """
  Reset cache statistics.

  ## Parameters

  - `name`: The cache process name or pid

  ## Returns

  `:ok` if the operation was successful

  ## Examples

      iex> ExCache.Ets.put(:my_cache, :key, "value")
      :ok
      iex> ExCache.Ets.get(:my_cache, :key)
      "value"
      iex> ExCache.Ets.reset_stats(:my_cache)
      :ok
      iex> stats = ExCache.Ets.stats(:my_cache)
      iex> stats.hits
      0
  """
  @spec reset_stats(ExCache.t()) :: :ok
  def reset_stats(name) do
    GenServer.cast(name, :reset_stats)
  end

  # ------------------- server ----------------------

  defp ets_name(name) do
    :"#{name}_ets"
  end

  @impl GenServer
  def init(name) do
    table = ets_name(name)
    :ets.new(table, [:named_table, :public, :set])

    state = %{
      table: table,
      stats: %{
        hits: 0,
        misses: 0,
        puts: 0,
        deletes: 0,
        total_operations: 0
      }
    }

    {:ok, state, @timeout}
  end

  @impl GenServer
  def handle_call({:get, key}, _, state) do
    %{table: table, stats: stats} = state

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

    # Update statistics
    updated_stats =
      if val != nil do
        %{stats | hits: stats.hits + 1, total_operations: stats.total_operations + 1}
      else
        %{stats | misses: stats.misses + 1, total_operations: stats.total_operations + 1}
      end

    updated_state = %{state | stats: updated_stats}
    {:reply, val, updated_state}
  end

  @impl GenServer
  def handle_call(:stats, _, state) do
    %{stats: stats} = state
    {:reply, stats, state}
  end

  @impl GenServer
  def handle_call(:cleanup_expired, _, state) do
    %{table: table} = state
    now = :os.system_time(:millisecond)

    # Count and delete expired entries
    deleted_count =
      :ets.select_delete(
        table,
        [
          {{:"$1", :"$2", :infinity}, [], [false]},
          {{:"$1", :"$2", :"$3"}, [{:<, :"$3", now}], [true]},
          {:_, [], [false]}
        ]
      )

    {:reply, {:ok, deleted_count}, state}
  end

  @impl GenServer
  def handle_cast({:del, key}, state) do
    %{table: table, stats: stats} = state
    :ets.delete(table, key)

    # Update statistics
    updated_stats = %{stats | deletes: stats.deletes + 1, total_operations: stats.total_operations + 1}
    updated_state = %{state | stats: updated_stats}

    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_cast(:reset_stats, state) do
    reset_stats = %{
      hits: 0,
      misses: 0,
      puts: 0,
      deletes: 0,
      total_operations: 0
    }

    updated_state = %{state | stats: reset_stats}
    {:noreply, updated_state}
  end

  def handle_cast({:put, key, value, ttl: :infinity}, state) do
    %{table: table, stats: stats} = state
    :ets.insert(table, {key, value, :infinity})

    # Update statistics
    updated_stats = %{stats | puts: stats.puts + 1, total_operations: stats.total_operations + 1}
    updated_state = %{state | stats: updated_stats}

    {:noreply, updated_state}
  end

  def handle_cast({:put, key, value, ttl: ttl}, state) when is_integer(ttl) and ttl > 0 do
    %{table: table, stats: stats} = state
    :ets.insert(table, {key, value, :os.system_time(:millisecond) + ttl})

    # Update statistics
    updated_stats = %{stats | puts: stats.puts + 1, total_operations: stats.total_operations + 1}
    updated_state = %{state | stats: updated_stats}

    {:noreply, updated_state}
  end

  def handle_cast({:put, key, value, ttl: _invalid_ttl}, state) do
    %{table: table, stats: stats} = state
    # Treat invalid TTL values as infinity
    :ets.insert(table, {key, value, :infinity})

    # Update statistics
    updated_stats = %{stats | puts: stats.puts + 1, total_operations: stats.total_operations + 1}
    updated_state = %{state | stats: updated_stats}

    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_info(:timeout, state) do
    %{table: table} = state
    now = :os.system_time(:millisecond)

    # Optimized cleanup strategy:
    # 1. Use select_delete for efficient batch deletion
    # 2. First count expired entries for statistics
    # 3. Then delete them in one operation
    expired_count =
      :ets.select_count(
        table,
        [
          {{:"$1", :"$2", :"$3"}, [{:<, :"$3", now}], [true]}
        ]
      )

    if expired_count > 0 do
      # Delete all expired entries in one operation
      deleted_count =
        :ets.select_delete(
          table,
          [
            {{:"$1", :"$2", :infinity}, [], [false]},
            {{:"$1", :"$2", :"$3"}, [{:<, :"$3", now}], [true]},
            {:_, [], [false]}
          ]
        )

      # Log cleanup activity (could be enhanced with telemetry)
      if deleted_count > 0 do
        :logger.debug("[ExCache] Cleaned up #{deleted_count} expired entries")
      end
    end

    {:noreply, state, @timeout}
  end

  @doc """
  Manually trigger cleanup of expired entries.

  This function can be called to manually clean up expired entries
  without waiting for the automatic timeout-based cleanup.

  ## Parameters

  - `name`: The cache process name or pid

  ## Returns

  `{:ok, deleted_count}` where deleted_count is the number of entries that were deleted

  ## Examples

      iex> {:ok, count} = ExCache.Ets.cleanup_expired(:my_cache)
      iex> count
      5

  """
  @spec cleanup_expired(ExCache.t()) :: {:ok, non_neg_integer()}
  def cleanup_expired(name) do
    GenServer.call(name, :cleanup_expired)
  end
end
