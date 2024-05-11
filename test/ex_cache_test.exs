defmodule ExCacheTest do
  use ExUnit.Case

  alias ExCache.Ets

  setup do
    name = :test_cache

    start_supervised!({Ets, name})

    [name: name]
  end

  # test "put and get", %{name: name} do
  #   assert Ets.put(name, :key, :value) == :ok
  #   assert Ets.get(name, :key) == :value
  # end

  # test "put and get with ttl", %{name: name} do
  #   assert Ets.put(name, :key, :value, ttl: 1000) == :ok
  #   assert Ets.get(name, :key) == :value
  #   :timer.sleep(1001)
  #   assert Ets.get(name, :key) == nil
  # end

  # test "delete", %{name: name} do
  #   assert Ets.put(name, :key, :value) == :ok
  #   assert Ets.get(name, :key) == :value
  #   assert Ets.del(name, :key) == :ok
  #   assert Ets.get(name, :key) == nil
  # end

  test "fetch", %{name: name} do
    Ets.del(name, :key)
    assert Ets.fetch(name, :key, [ttl: 1000], fn _ -> {:commit, :value} end) == :value
    assert Ets.get(name, :key) == :value
    :timer.sleep(1001)
    assert Ets.fetch(name, :key, [ttl: 1000], fn _ -> {:ignore, :value} end) == :value
    assert Ets.get(name, :key) == nil
  end
end
