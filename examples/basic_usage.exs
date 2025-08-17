#!/usr/bin/env elixir

# Basic Usage Examples for ExCache
#
# This file demonstrates the fundamental operations and patterns
# for using ExCache in your application.

# Mix.install([
#   {:ex_cache, path: ".."}
# ])

alias ExCache.Ets

IO.puts("=== ExCache Basic Usage Examples ===\n")

# Example 1: Starting a Cache
IO.puts("1. Starting a Cache")
IO.puts("--------------------------------")

# Start a cache process
{:ok, cache_pid} = ExCache.Ets.start_link(:example_cache)
IO.puts("✅ Cache started: #{inspect(cache_pid)}")

# Example 2: Basic Put and Get Operations
IO.puts("\n2. Basic Put and Get Operations")
IO.puts("--------------------------------")

# Store a simple value
ExCache.Ets.put(:example_cache, :greeting, "Hello, World!")
IO.puts("📝 Stored: :greeting => \"Hello, World!\"")

# Retrieve the value
greeting = ExCache.Ets.get(:example_cache, :greeting)
IO.puts("📖 Retrieved: #{inspect(greeting)}")

# Example 3: Working with Different Data Types
IO.puts("\n3. Working with Different Data Types")
IO.puts("--------------------------------")

# Store various types of data
data_examples = %{
  string: "Elixir is awesome!",
  number: 42,
  float: 3.14159,
  atom: :elixir,
  list: [1, 2, 3, 4, 5],
  map: %{name: "John", age: 30, city: "New York"},
  tuple: {:user, "john@example.com", :active}
}

Enum.each(data_examples, fn {key, value} ->
  # Store the data
  ExCache.Ets.put(:example_cache, key, value)
  IO.puts("📝 Stored #{inspect(key)} => #{inspect(value)}")

  # Retrieve and verify
  retrieved = ExCache.Ets.get(:example_cache, key)
  IO.puts("📖 Retrieved #{inspect(key)} => #{inspect(retrieved)}")
  IO.puts("")
end)

# Example 4: Using TTL (Time To Live)
IO.puts("4. Using TTL (Time To Live)")
IO.puts("--------------------------------")

# Store a value that expires in 2 seconds
ExCache.Ets.put(:example_cache, :temp_session, "session_abc123", ttl: 2000)
IO.puts("📝 Stored temporary session (expires in 2s)")

# Retrieve immediately
session = ExCache.Ets.get(:example_cache, :temp_session)
IO.puts("📖 Retrieved immediately: #{inspect(session)}")

# Wait for expiration
IO.puts("⏳ Waiting for expiration...")
:timer.sleep(2100)

# Try to retrieve after expiration
expired_session = ExCache.Ets.get(:example_cache, :temp_session)
IO.puts("📖 Retrieved after expiration: #{inspect(expired_session)}")

# Example 5: Delete Operations
IO.puts("\n5. Delete Operations")
IO.puts("--------------------------------")

# Store a value we'll delete
ExCache.Ets.put(:example_cache, :to_delete, "This will be removed")
IO.puts("📝 Stored value to delete")

# Verify it's there
before_delete = ExCache.Ets.get(:example_cache, :to_delete)
IO.puts("📖 Before delete: #{inspect(before_delete)}")

# Delete it
ExCache.Ets.del(:example_cache, :to_delete)
IO.puts("🗑️  Deleted value")

# Verify it's gone
after_delete = ExCache.Ets.get(:example_cache, :to_delete)
IO.puts("📖 After delete: #{inspect(after_delete)}")

# Example 6: Working with Complex Keys
IO.puts("\n6. Working with Complex Keys")
IO.puts("--------------------------------")

complex_keys = [
  {:user, 123},
  ["config", "app", "settings"],
  %{type: "session", id: "abc123"},
  "simple_string_key"
]

Enum.each(complex_keys, fn key ->
  value = "Value for #{inspect(key)}"
  ExCache.Ets.put(:example_cache, key, value)
  IO.puts("📝 Stored with key #{inspect(key)}")

  retrieved = ExCache.Ets.get(:example_cache, key)
  IO.puts("📖 Retrieved: #{retrieved}")
  IO.puts("")
end)

# Example 7: Basic Error Handling
IO.puts("\n7. Basic Error Handling")
IO.puts("--------------------------------")

# Try to get a non-existent key
non_existent = ExCache.Ets.get(:example_cache, :non_existent_key)
IO.puts("📖 Non-existent key result: #{inspect(non_existent)}")

# Delete a non-existent key (should not crash)
result = ExCache.Ets.del(:example_cache, :definitely_not_there)
IO.puts("🗑️  Delete non-existent key result: #{inspect(result)}")

# Example 8: Cache Statistics
IO.puts("\n8. Cache Statistics")
IO.puts("--------------------------------")

# Reset statistics to start clean
ExCache.Ets.reset_stats(:example_cache)

# Perform some operations
ExCache.Ets.put(:example_cache, :stats_key1, "value1")
ExCache.Ets.put(:example_cache, :stats_key2, "value2")
ExCache.Ets.get(:example_cache, :stats_key1)  # hit
ExCache.Ets.get(:example_cache, :stats_key1)  # hit
ExCache.Ets.get(:example_cache, :nonexistent)  # miss
ExCache.Ets.del(:example_cache, :stats_key2)

# Get statistics
stats = ExCache.Ets.stats(:example_cache)
IO.puts("📊 Cache Statistics:")
IO.puts("   Hits: #{stats.hits}")
IO.puts("   Misses: #{stats.misses}")
IO.puts("   Puts: #{stats.puts}")
IO.puts("   Deletes: #{stats.deletes}")
IO.puts("   Total Operations: #{stats.total_operations}")

# Calculate hit rate
total_access = stats.hits + stats.misses
hit_rate = if total_access > 0, do: stats.hits / total_access * 100, else: 0
IO.puts("   Hit Rate: #{Float.round(hit_rate, 2)}%")

# Clean up
IO.puts("\n🧹 Cleaning up...")
GenServer.stop(:example_cache)
IO.puts("✅ Cache process stopped")

IO.puts("\n🎉 Basic usage examples completed!")
IO.puts("\n💡 Next step: Check out advanced_usage.exs for more sophisticated patterns!")
