defmodule ExCacheTest do
  use ExUnit.Case

  alias ExCache.Ets

  setup do
    name = :test_cache

    start_supervised!({Ets, name})

    [name: name]
  end

  test "put and get", %{name: name} do
    assert Ets.put(name, :key, :value) == :ok
    assert Ets.get(name, :key) == :value
  end

  test "put and get with ttl", %{name: name} do
    assert Ets.put(name, :key, :value, ttl: 1000) == :ok
    assert Ets.get(name, :key) == :value
    :timer.sleep(1001)
    assert Ets.get(name, :key) == nil
  end

  test "delete", %{name: name} do
    assert Ets.put(name, :key, :value) == :ok
    assert Ets.get(name, :key) == :value
    assert Ets.del(name, :key) == :ok
    assert Ets.get(name, :key) == nil
  end

  test "fetch", %{name: name} do
    Ets.del(name, :key)
    assert Ets.fetch(name, :key, [ttl: 1000], fn _ -> {:commit, :value} end) == :value
    assert Ets.get(name, :key) == :value
    :timer.sleep(1001)
    assert Ets.fetch(name, :key, [ttl: 1000], fn _ -> {:ignore, :value} end) == :value
    assert Ets.get(name, :key) == nil
  end

  # --- 边界情况测试 ---

  test "handle various key types", %{name: name} do
    # Test atom keys
    assert Ets.put(name, :atom_key, "atom_value") == :ok
    assert Ets.get(name, :atom_key) == "atom_value"

    # Test string keys
    assert Ets.put(name, "string_key", "string_value") == :ok
    assert Ets.get(name, "string_key") == "string_value"

    # Test integer keys
    assert Ets.put(name, 42, "integer_value") == :ok
    assert Ets.get(name, 42) == "integer_value"

    # Test tuple keys
    assert Ets.put(name, {:complex, "key"}, "tuple_value") == :ok
    assert Ets.get(name, {:complex, "key"}) == "tuple_value"

    # Test list keys
    assert Ets.put(name, [1, 2, 3], "list_value") == :ok
    assert Ets.get(name, [1, 2, 3]) == "list_value"
  end

  test "handle various value types", %{name: name} do
    # Test string values
    assert Ets.put(name, :string_val, "hello") == :ok
    assert Ets.get(name, :string_val) == "hello"

    # Test integer values
    assert Ets.put(name, :int_val, 42) == :ok
    assert Ets.get(name, :int_val) == 42

    # Test float values
    assert Ets.put(name, :float_val, 3.14) == :ok
    assert Ets.get(name, :float_val) == 3.14

    # Test atom values
    assert Ets.put(name, :atom_val, :atom) == :ok
    assert Ets.get(name, :atom_val) == :atom

    # Test list values
    assert Ets.put(name, :list_val, [1, 2, 3]) == :ok
    assert Ets.get(name, :list_val) == [1, 2, 3]

    # Test map values
    assert Ets.put(name, :map_val, %{key: "value"}) == :ok
    assert Ets.get(name, :map_val) == %{key: "value"}

    # Test tuple values
    assert Ets.put(name, :tuple_val, {:a, :b, :c}) == :ok
    assert Ets.get(name, :tuple_val) == {:a, :b, :c}
  end

  test "handle ttl edge cases", %{name: name} do
    # Test very small TTL (1ms)
    assert Ets.put(name, :tiny_ttl, "value", ttl: 1) == :ok
    :timer.sleep(2)
    assert Ets.get(name, :tiny_ttl) == nil

    # Test small TTL (10ms)
    assert Ets.put(name, :small_ttl, "value", ttl: 10) == :ok
    assert Ets.get(name, :small_ttl) == "value"
    :timer.sleep(15)
    assert Ets.get(name, :small_ttl) == nil

    # Test large TTL (should not expire soon)
    assert Ets.put(name, :large_ttl, "value", ttl: 100_000) == :ok
    assert Ets.get(name, :large_ttl) == "value"
  end

  test "handle missing keys", %{name: name} do
    # Test getting non-existent key
    assert Ets.get(name, :nonexistent) == nil

    # Test deleting non-existent key
    assert Ets.del(name, :nonexistent) == :ok

    # Test operations on non-existent key should not crash
    assert Ets.get(name, [:complex, :missing, :key]) == nil
    assert Ets.del(name, [:complex, :missing, :key]) == :ok
  end

  test "handle large data", %{name: name} do
    # Test large string
    large_string = String.duplicate("a", 10_000)
    assert Ets.put(name, :large_string, large_string) == :ok
    assert Ets.get(name, :large_string) == large_string

    # Test large list
    large_list = Enum.to_list(1..1000)
    assert Ets.put(name, :large_list, large_list) == :ok
    assert Ets.get(name, :large_list) == large_list

    # Test large map
    large_map = Map.new(1..100, fn i -> {i, "value_#{i}"} end)
    assert Ets.put(name, :large_map, large_map) == :ok
    assert Ets.get(name, :large_map) == large_map
  end

  test "handle concurrent access", %{name: name} do
    # Test concurrent puts
    tasks =
      Enum.map(1..100, fn i ->
        Task.async(fn ->
          Ets.put(name, :"key_#{i}", "value_#{i}")
        end)
      end)

    # Wait for all puts to complete
    results = Task.await_many(tasks, 5000)
    assert Enum.all?(results, fn result -> result == :ok end)

    # Verify all values were stored
    for i <- 1..100 do
      assert Ets.get(name, :"key_#{i}") == "value_#{i}"
    end

    # Test concurrent gets
    get_tasks =
      Enum.map(1..100, fn i ->
        Task.async(fn ->
          Ets.get(name, :"key_#{i}")
        end)
      end)

    get_results = Task.await_many(get_tasks, 5000)
    expected = Enum.map(1..100, fn i -> "value_#{i}" end)
    assert get_results == expected

    # Test concurrent deletes
    del_tasks =
      Enum.map(1..100, fn i ->
        Task.async(fn ->
          Ets.del(name, :"key_#{i}")
        end)
      end)

    del_results = Task.await_many(del_tasks, 5000)
    assert Enum.all?(del_results, fn result -> result == :ok end)

    # Verify all values were deleted
    for i <- 1..100 do
      assert Ets.get(name, :"key_#{i}") == nil
    end
  end

  test "handle mixed concurrent operations", %{name: name} do
    # Setup initial data
    Enum.each(1..50, fn i ->
      Ets.put(name, :"mixed_key_#{i}", "initial_value_#{i}")
    end)

    # Create mixed operations (puts, gets, deletes)
    operations =
      Enum.map(1..100, fn i ->
        Task.async(fn ->
          case rem(i, 3) do
            # put operation
            0 ->
              key = :"mixed_key_#{rem(i, 50) + 1}"
              Ets.put(name, key, "updated_value_#{i}")

            # get operation
            1 ->
              key = :"mixed_key_#{rem(i, 50) + 1}"
              Ets.get(name, key)

            # delete operation
            2 ->
              key = :"mixed_key_#{rem(i, 50) + 1}"
              Ets.del(name, key)
          end
        end)
      end)

    # All operations should complete without crashing
    results = Task.await_many(operations, 5000)
    assert length(results) == 100
  end

  test "handle error scenarios", %{name: name} do
    # Test with invalid options (should not crash)
    assert Ets.put(name, :invalid_opt_test, "value", invalid_opt: :something) == :ok
    assert Ets.get(name, :invalid_opt_test) == "value"

    # Test with empty options
    assert Ets.put(name, :empty_opt_test, "value", []) == :ok
    assert Ets.get(name, :empty_opt_test) == "value"

    # Test with negative TTL (should be handled gracefully)
    assert Ets.put(name, :negative_ttl_test, "value", ttl: -100) == :ok
    assert Ets.get(name, :negative_ttl_test) == "value"
  end

  test "handle duplicate puts", %{name: name} do
    # Put initial value
    assert Ets.put(name, :duplicate_key, "initial_value") == :ok
    assert Ets.get(name, :duplicate_key) == "initial_value"

    # Overwrite with same key
    assert Ets.put(name, :duplicate_key, "new_value") == :ok
    assert Ets.get(name, :duplicate_key) == "new_value"

    # Overwrite with different TTL
    assert Ets.put(name, :duplicate_key, "ttl_value", ttl: 100) == :ok
    assert Ets.get(name, :duplicate_key) == "ttl_value"
    :timer.sleep(110)
    assert Ets.get(name, :duplicate_key) == nil
  end

  test "handle fetch edge cases", %{name: name} do
    # Test fetch with nil return from fallback
    result = Ets.fetch(name, :fetch_nil, [], fn _ -> {:commit, nil} end)
    assert result == nil
    assert Ets.get(name, :fetch_nil) == nil

    # Test fetch with complex value
    complex_value = %{user: "john", prefs: %{theme: :dark, notifications: true}}
    result = Ets.fetch(name, :fetch_complex, [ttl: 1000], fn _ -> {:commit, complex_value} end)
    assert result == complex_value
    assert Ets.get(name, :fetch_complex) == complex_value

    # Test fetch with ignore
    result = Ets.fetch(name, :fetch_ignore, [], fn _ -> {:ignore, "ignored_value"} end)
    assert result == "ignored_value"
    assert Ets.get(name, :fetch_ignore) == nil
  end

  # --- 统计功能测试 ---

  test "statistics tracking", %{name: name} do
    # Initial stats should be empty
    stats = Ets.stats(name)
    assert stats.hits == 0
    assert stats.misses == 0
    assert stats.puts == 0
    assert stats.deletes == 0
    assert stats.total_operations == 0

    # Perform put operations
    assert Ets.put(name, :stats_key1, "value1") == :ok
    assert Ets.put(name, :stats_key2, "value2") == :ok

    stats = Ets.stats(name)
    assert stats.puts == 2
    assert stats.total_operations == 2

    # Perform get operations
    assert Ets.get(name, :stats_key1) == "value1"
    # Second get
    assert Ets.get(name, :stats_key1) == "value1"
    assert Ets.get(name, :nonexistent) == nil

    stats = Ets.stats(name)
    assert stats.hits == 2
    assert stats.misses == 1
    # 2 puts + 3 gets
    assert stats.total_operations == 5

    # Perform delete operations
    assert Ets.del(name, :stats_key1) == :ok
    assert Ets.del(name, :stats_key2) == :ok

    stats = Ets.stats(name)
    assert stats.deletes == 2
    # 2 puts + 3 gets + 2 deletes
    assert stats.total_operations == 7
  end

  test "statistics reset", %{name: name} do
    # Perform some operations to populate stats
    assert Ets.put(name, :reset_key, "value") == :ok
    assert Ets.get(name, :reset_key) == "value"
    assert Ets.del(name, :reset_key) == :ok

    # Check stats are not zero
    stats = Ets.stats(name)
    assert stats.total_operations > 0
    assert stats.puts == 1
    assert stats.hits == 1
    assert stats.deletes == 1

    # Reset statistics
    assert Ets.reset_stats(name) == :ok

    # Check all stats are reset to zero
    stats = Ets.stats(name)
    assert stats.hits == 0
    assert stats.misses == 0
    assert stats.puts == 0
    assert stats.deletes == 0
    assert stats.total_operations == 0
  end

  test "statistics with fetch operations", %{name: name} do
    # Reset stats for clean test
    Ets.reset_stats(name)

    # Initial stats should be empty
    stats = Ets.stats(name)
    assert stats.total_operations == 0

    # Use fetch with commit
    Ets.del(name, :fetch_key)
    result = Ets.fetch(name, :fetch_key, [], fn _ -> {:commit, "committed_value"} end)
    assert result == "committed_value"

    stats = Ets.stats(name)
    # del (1) + fetch get miss (1) + put (1) = 3 operations
    assert stats.total_operations == 3
    assert stats.misses == 1
    assert stats.puts == 1

    # Use fetch with ignore
    Ets.del(name, :fetch_key2)
    result = Ets.fetch(name, :fetch_key2, [], fn _ -> {:ignore, "ignored_value"} end)
    assert result == "ignored_value"

    stats = Ets.stats(name)
    # Previous (3) + del (1) + fetch get miss (1) = 5 operations
    assert stats.total_operations == 5
    assert stats.misses == 2
    # No additional put
    assert stats.puts == 1

    # Use fetch with cache hit
    result = Ets.fetch(name, :fetch_key, [], fn _ -> {:commit, "should_not_be_used"} end)
    assert result == "committed_value"

    stats = Ets.stats(name)
    # Previous (5) + fetch get hit (1) = 6 operations
    assert stats.total_operations == 6
    assert stats.hits == 1
    assert stats.misses == 2
    assert stats.puts == 1
  end

  test "statistics with TTL expiration", %{name: name} do
    # Put with short TTL
    assert Ets.put(name, :ttl_key, "ttl_value", ttl: 10) == :ok
    # Hit
    assert Ets.get(name, :ttl_key) == "ttl_value"

    stats = Ets.stats(name)
    assert stats.hits == 1
    assert stats.misses == 0
    assert stats.puts == 1
    assert stats.total_operations == 2

    # Wait for expiration
    :timer.sleep(15)
    # Miss due to expiration
    assert Ets.get(name, :ttl_key) == nil

    stats = Ets.stats(name)
    assert stats.hits == 1
    assert stats.misses == 1
    assert stats.total_operations == 3
  end

  # --- 清理功能测试 ---

  test "manual cleanup of expired entries", %{name: name} do
    # Put entries with short TTL
    assert Ets.put(name, :expired1, "value1", ttl: 10) == :ok
    assert Ets.put(name, :expired2, "value2", ttl: 10) == :ok
    assert Ets.put(name, :expired3, "value3", ttl: 10) == :ok

    # Put entries with long TTL
    assert Ets.put(name, :valid1, "value4", ttl: 10_000) == :ok
    assert Ets.put(name, :valid2, "value5", ttl: 10_000) == :ok

    # Verify all entries are present initially
    assert Ets.get(name, :expired1) == "value1"
    assert Ets.get(name, :expired2) == "value2"
    assert Ets.get(name, :expired3) == "value3"
    assert Ets.get(name, :valid1) == "value4"
    assert Ets.get(name, :valid2) == "value5"

    # Wait for entries to expire
    :timer.sleep(15)

    # Manual cleanup should remove expired entries
    {:ok, deleted_count} = Ets.cleanup_expired(name)
    assert deleted_count == 3

    # Verify expired entries are gone
    assert Ets.get(name, :expired1) == nil
    assert Ets.get(name, :expired2) == nil
    assert Ets.get(name, :expired3) == nil

    # Verify valid entries are still present
    assert Ets.get(name, :valid1) == "value4"
    assert Ets.get(name, :valid2) == "value5"

    # Cleanup again should delete nothing
    {:ok, deleted_count} = Ets.cleanup_expired(name)
    assert deleted_count == 0
  end

  test "cleanup with mixed TTL values", %{name: name} do
    # Test with infinity TTL
    assert Ets.put(name, :infinity_key, "infinity_value", ttl: :infinity) == :ok
    assert Ets.put(name, :future_key, "future_value", ttl: 100_000) == :ok
    assert Ets.put(name, :past_key, "past_value", ttl: 1) == :ok

    # Wait for past entry to expire
    :timer.sleep(5)

    # Manual cleanup
    {:ok, deleted_count} = Ets.cleanup_expired(name)
    assert deleted_count == 1

    # Verify only past entry was removed
    assert Ets.get(name, :infinity_key) == "infinity_value"
    assert Ets.get(name, :future_key) == "future_value"
    assert Ets.get(name, :past_key) == nil
  end

  test "cleanup with empty cache", %{name: name} do
    # Manual cleanup on empty cache should delete nothing
    {:ok, deleted_count} = Ets.cleanup_expired(name)
    assert deleted_count == 0
  end

  test "automatic cleanup during timeout", %{name: name} do
    # Reset stats to monitor cleanup activity
    Ets.reset_stats(name)

    # Put entries with very short TTL (shorter than cleanup timeout)
    assert Ets.put(name, :auto_expired, "auto_value", ttl: 10) == :ok
    # This get counts as a hit
    assert Ets.get(name, :auto_expired) == "auto_value"

    # Wait for automatic cleanup to trigger
    :timer.sleep(5010)

    # Verify automatic cleanup worked
    # This get will count as a miss because the entry expired
    assert Ets.get(name, :auto_expired) == nil

    # Stats should show: put (1) + hit (1) + miss (1) = 3 operations
    stats = Ets.stats(name)
    assert stats.puts == 1
    assert stats.hits == 1
    assert stats.misses == 1
    assert stats.total_operations == 3
  end
end
