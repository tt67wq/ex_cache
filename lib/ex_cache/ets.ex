defmodule ExCache.Ets do
  @moduledoc """
  Ets-based cache impl.
  """

  use ExCache
  use GenServer

  @timeout 5000

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: name)
  end

  @impl ExCache
  def put(name, key, value, put_opts \\ []) do
    ttl = Keyword.get(put_opts, :ttl, :infinity)
    GenServer.cast(name, {:put, key, value, ttl: ttl})
  end

  @impl ExCache
  def get(name, key) do
    GenServer.call(name, {:get, key})
  end

  @impl ExCache
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

  def handle_cast({:put, key, value, ttl: ttl}, table) do
    :ets.insert(table, {key, value, :os.system_time(:millisecond) + ttl})
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
