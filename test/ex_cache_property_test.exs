defmodule ExCachePropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ExCache.Ets

  # Setup a fresh cache for each property test
  setup do
    name = :"property_test_#{System.unique_integer([:positive])}"
    start_supervised!({Ets, name})
    [name: name]
  end

  # Test that put and get are consistent for various data types
  property "put and get are consistent for various data types", %{name: name} do
    check all(
            key <- term(),
            value <- term(),
            max_runs: 100
          ) do
      # Put the value
      assert Ets.put(name, key, value) == :ok

      # Get the value back
      result = Ets.get(name, key)

      # Compare the values
      assert result == value

      # Clean up
      Ets.del(name, key)
    end
  end

  # Test that TTL expiration works correctly
  property "TTL expiration works correctly", %{name: name} do
    check all(
            key <- term(),
            value <- term(),
            ttl <- integer(1..100),
            max_runs: 50
          ) do
      # Put with TTL
      assert Ets.put(name, key, value, ttl: ttl) == :ok

      # Should be available immediately
      assert Ets.get(name, key) == value

      # Wait for TTL to expire
      :timer.sleep(ttl + 10)

      # Should be nil after expiration
      assert Ets.get(name, key) == nil
    end
  end

  # Test that delete removes keys correctly
  property "delete removes keys correctly", %{name: name} do
    check all(
            key <- term(),
            value <- term(),
            max_runs: 100
          ) do
      # Put the value
      assert Ets.put(name, key, value) == :ok

      # Verify it's there
      assert Ets.get(name, key) == value

      # Delete it
      assert Ets.del(name, key) == :ok

      # Verify it's gone
      assert Ets.get(name, key) == nil
    end
  end

  # Test that fetch with commit works correctly
  property "fetch with commit works correctly", %{name: name} do
    check all(
            key <- term(),
            value <- term(),
            ttl <- one_of([integer(1..1000), constant(:infinity)]),
            max_runs: 50
          ) do
      # Clean up key first
      Ets.del(name, key)

      # Define fallback function
      fallback = fn _k -> {:commit, value} end

      # Fetch with commit
      result = Ets.fetch(name, key, [ttl: ttl], fallback)

      # Should return the value
      assert result == value

      # Value should be stored in cache
      if ttl == :infinity do
        assert Ets.get(name, key) == value
      else
        # If TTL is set, verify it's stored temporarily
        assert Ets.get(name, key) == value
      end
    end
  end

  # Test that fetch with ignore works correctly
  property "fetch with ignore works correctly", %{name: name} do
    check all(
            key <- term(),
            value <- term(),
            max_runs: 50
          ) do
      # Clean up key first
      Ets.del(name, key)

      # Define fallback function that ignores
      fallback = fn _k -> {:ignore, value} end

      # Fetch with ignore
      result = Ets.fetch(name, key, [], fallback)

      # Should return the value
      assert result == value

      # Value should NOT be stored in cache
      assert Ets.get(name, key) == nil
    end
  end

  # Test that overwriting keys works correctly
  property "overwriting keys works correctly", %{name: name} do
    check all(
            key <- term(),
            value1 <- term(),
            value2 <- term(),
            max_runs: 50
          ) do
      # Put first value
      assert Ets.put(name, key, value1) == :ok
      assert Ets.get(name, key) == value1

      # Overwrite with second value
      assert Ets.put(name, key, value2) == :ok
      assert Ets.get(name, key) == value2

      # Clean up
      Ets.del(name, key)
    end
  end

  # Test that different key types don't interfere
  property "different key types don't interfere", %{name: name} do
    check all(
            key1 <- term(),
            key2 <- filter(term(), &(&1 != key1)),
            value1 <- term(),
            value2 <- term(),
            max_runs: 50
          ) do
      # Put two different keys
      assert Ets.put(name, key1, value1) == :ok
      assert Ets.put(name, key2, value2) == :ok

      # Verify both values are correct
      assert Ets.get(name, key1) == value1
      assert Ets.get(name, key2) == value2

      # Delete one key
      assert Ets.del(name, key1) == :ok

      # Verify only the deleted key is gone
      assert Ets.get(name, key1) == nil
      assert Ets.get(name, key2) == value2

      # Clean up
      Ets.del(name, key2)
    end
  end

  # Test that invalid TTL values are handled gracefully
  property "invalid TTL values are handled gracefully", %{name: name} do
    check all(
            key <- term(),
            value <- term(),
            invalid_ttl <-
              one_of([
                constant(-1),
                constant(0),
                constant(nil),
                constant(:invalid),
                filter(term(), &(not is_integer(&1)))
              ]),
            max_runs: 50
          ) do
      # Put with invalid TTL
      assert Ets.put(name, key, value, ttl: invalid_ttl) == :ok

      # Should still work (treated as infinity)
      assert Ets.get(name, key) == value

      # Clean up
      Ets.del(name, key)
    end
  end

  # Test concurrent operations don't corrupt data
  property "concurrent puts and gets don't corrupt data", %{name: name} do
    check all(
            operations <-
              list_of(
                one_of([
                  tuple({constant(:put), term(), term()}),
                  tuple({constant(:get), term()}),
                  tuple({constant(:del), term()})
                ]),
                min_length: 1,
                max_length: 50
              ),
            max_runs: 30
          ) do
      # Execute all operations concurrently
      tasks =
        Enum.map(operations, fn op ->
          Task.async(fn ->
            case op do
              {:put, key, value} -> Ets.put(name, key, value)
              {:get, key} -> Ets.get(name, key)
              {:del, key} -> Ets.del(name, key)
            end
          end)
        end)

      # Wait for all operations to complete
      results = Task.await_many(tasks, 5000)

      # All operations should complete without crashing
      assert length(results) == length(operations)
    end
  end

  # Test that fetch operations with different fallbacks work correctly
  property "fetch operations with different fallbacks work correctly", %{name: name} do
    check all(
            key <- term(),
            fallback_result <-
              one_of([
                tuple({constant(:commit), term()}),
                tuple({constant(:ignore), term()})
              ]),
            max_runs: 50
          ) do
      # Clean up key first
      Ets.del(name, key)

      # Define fallback function
      fallback = fn _k -> fallback_result end

      # Fetch
      result = Ets.fetch(name, key, [], fallback)

      # Check result
      case fallback_result do
        {:commit, value} ->
          assert result == value
          # Value should be stored
          assert Ets.get(name, key) == value

        {:ignore, value} ->
          assert result == value
          # Value should NOT be stored
          assert Ets.get(name, key) == nil
      end
    end
  end
end
