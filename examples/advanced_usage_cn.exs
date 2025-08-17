#!/usr/bin/env elixir

# ExCache 高级使用示例
#
# 本文件演示了在复杂应用场景中使用 ExCache 的高级模式和最佳实践。

# Mix.install([
#   {:ex_cache, path: ".."}
# ])

alias ExCache.Ets

IO.puts("=== ExCache 高级使用示例 ===\n")

# 示例 1：数据库查询缓存
IO.puts("1. 数据库查询缓存模式")
IO.puts("================================")

# 模拟数据库模块
defmodule Database do
  def get_user(id) do
    IO.puts("🗄️  正在从数据库查询用户 #{id}...")
    :timer.sleep(100)  # 模拟数据库查询延迟
    %{id: id, name: "用户#{id}", email: "user#{id}@example.com", created_at: DateTime.utc_now()}
  end

  def get_product(sku) do
    IO.puts("🗄️  正在从数据库查询产品 #{sku}...")
    :timer.sleep(150)  # 模拟数据库查询延迟
    %{sku: sku, name: "产品#{sku}", price: :rand.uniform(1000), stock: :rand.uniform(100)}
  end
end

# 启动缓存
{:ok, _cache_pid} = ExCache.Ets.start_link(:db_cache)

# 使用 fetch 缓存数据库查询
IO.puts("🔄 第一次查询用户 1（会访问数据库）...")
user1 = ExCache.Ets.fetch(:db_cache, :user_1, [ttl: 300_000], fn _key ->
  {:commit, Database.get_user(1)}
end)
IO.puts("📖 用户 1: #{inspect(user1)}")

IO.puts("\n🔄 第二次查询用户 1（应该来自缓存）...")
user1_cached = ExCache.Ets.fetch(:db_cache, :user_1, [], fn _key ->
  {:commit, Database.get_user(1)}  # 这个函数不应该被调用
end)
IO.puts("📖 用户 1（缓存）: #{inspect(user1_cached)}")

# 验证是同一个对象
IO.puts("✅ 是否为同一对象: #{user1 == user1_cached}")

# 示例 2：API 响应缓存
IO.puts("\n2. API 响应缓存模式")
IO.puts("========================")

defmodule APIClient do
  def fetch_weather(city) do
    IO.puts("🌐 正在调用天气 API 获取 #{city} 的天气...")
    :timer.sleep(200)  # 模拟 API 调用延迟

    # 模拟 API 响应
    %{
      city: city,
      temperature: :rand.uniform(40) - 10,
      humidity: :rand.uniform(100),
      description: Enum.random(["晴天", "多云", "小雨", "阴天"]),
      timestamp: DateTime.utc_now()
    }
  end
end

# 缓存 API 响应，但使用较短的 TTL 因为天气数据变化快
weather_data = ExCache.Ets.fetch(:db_cache, "weather:北京", [ttl: 600_000], fn _key ->
  {:commit, APIClient.fetch_weather("北京")}
end)
IO.puts("📖 北京天气: #{inspect(weather_data)}")

# 示例 3：计算密集型操作缓存
IO.puts("\n3. 计算密集型操作缓存")
IO.puts("=============================")

defmodule MathService do
  def fibonacci(0), do: 0
  def fibonacci(1), do: 1
  def fibonacci(n) when n > 1 do
    fibonacci(n - 1) + fibonacci(n - 2)
  end

  def expensive_calculation(n) do
    IO.puts("🧮 正在进行复杂计算 (n=#{n})...")
    :timer.sleep(50)  # 模拟计算时间

    # 计算一些复杂的东西
    1..n
    |> Enum.map(fn x -> :math.pow(x, 2) end)
    |> Enum.sum()
    |> :math.sqrt()
  end
end

# 缓存斐波那契数列
fib_result = ExCache.Ets.fetch(:db_cache, "fib:30", [ttl: :infinity], fn _key ->
  IO.puts("🧮 计算斐波那契数列...")
  {:commit, MathService.fibonacci(30)}
end)
IO.puts("📖 斐波那契(30): #{fib_result}")

# 缓存复杂计算
calc_result = ExCache.Ets.fetch(:db_cache, "calc:1000", [ttl: 3600_000], fn _key ->
  {:commit, MathService.expensive_calculation(1000)}
end)
IO.puts("📖 复杂计算结果(1000): #{Float.round(calc_result, 2)}")

# 示例 4：会话数据管理
IO.puts("\n4. 会话数据管理模式")
IO.puts("=====================")

# 创建会话缓存
{:ok, _session_cache_pid} = ExCache.Ets.start_link(:session_cache)

defmodule SessionManager do
  def create_session(user_id, ip_address) do
    session_id = generate_session_id()
    session_data = %{
      session_id: session_id,
      user_id: user_id,
      ip_address: ip_address,
      created_at: DateTime.utc_now(),
      last_activity: DateTime.utc_now(),
      data: %{}
    }

    ExCache.Ets.put(:session_cache, session_id, session_data, ttl: 1800_000)  # 30分钟 TTL
    session_id
  end

  def get_session(session_id) do
    case ExCache.Ets.get(:session_cache, session_id) do
      nil -> {:error, :not_found}
      session -> {:ok, update_session_activity(session)}
    end
  end

  def add_session_data(session_id, key, value) do
    case get_session(session_id) do
      {:error, :not_found} -> {:error, :not_found}
      {:ok, session} ->
        updated_data = put_in(session.data, key, value)
        updated_session = %{session | data: updated_data}
        ExCache.Ets.put(:session_cache, session_id, updated_session, ttl: 1800_000)
        :ok
    end
  end

  defp update_session_activity(session) do
    %{session | last_activity: DateTime.utc_now()}
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64() |> binary_part(0, 22)
  end
end

# 创建会话
session_id = SessionManager.create_session(123, "192.168.1.100")
IO.puts("🆔 创建会话: #{session_id}")

# 获取会话
{:ok, session} = SessionManager.get_session(session_id)
IO.puts("📖 会话数据: #{inspect(session.data)}")

# 添加会话数据
:ok = SessionManager.add_session_data(session_id, :cart, [%{product_id: "p1", quantity: 2}])
:ok = SessionManager.add_session_data(session_id, :preferences, %{theme: :dark, language: "zh-CN"})

# 验证会话数据已更新
{:ok, updated_session} = SessionManager.get_session(session_id)
IO.puts("📖 更新后的会话数据: #{inspect(updated_session.data)}")

# 示例 5：分布式缓存配置
IO.puts("\n5. 分布式缓存配置")
IO.puts("=====================")

# 在分布式系统中，可以为不同的服务配置不同的缓存
cache_configs = [
  {:user_cache, "用户服务缓存", ttl: 600_000},      # 10分钟
  {:product_cache, "产品服务缓存", ttl: 1800_000}, # 30分钟
  {:config_cache, "配置缓存", ttl: :infinity},     # 永不过期
  {:temp_cache, "临时数据缓存", ttl: 60_000}       # 1分钟
]

Enum.each(cache_configs, fn {name, description, ttl} ->
  {:ok, _pid} = ExCache.Ets.start_link(name)
  IO.puts("🏗️  启动缓存: #{description} (TTL: #{format_ttl(ttl)})")

  # 存储一些示例数据
  ExCache.Ets.put(name, :example, "示例数据", ttl: ttl)
end)

# 辅助函数
defp format_ttl(:infinity), do: "永不过期"
defp format_ttl(ms), do: "#{div(ms, 1000)}秒"

# 示例 6：缓存预热策略
IO.puts("\n6. 缓存预热策略")
IO.puts("================")

defmodule CacheWarmer do
  def warm_user_cache() do
    IO.puts("🔥 正在预热用户缓存...")

    # 模拟从数据库批量加载用户
    users = Enum.map(1..10, fn id ->
      %{id: id, name: "预热用户#{id}", email: "warm#{id}@example.com"}
    end)

    # 批量存储到缓存
    Enum.each(users, fn user ->
      ExCache.Ets.put(:user_cache, "user:#{user.id}", user, ttl: 900_000)
    end)

    IO.puts("✅ 预热了 #{length(users)} 个用户到缓存")
  end

  def warm_product_cache() do
    IO.puts("🔥 正在预热产品缓存...")

    # 模拟加载热门产品
    hot_products = Enum.map(1..20, fn i ->
      %{sku: "HOT#{i}", name: "热门产品#{i}", price: i * 10}
    end)

    Enum.each(hot_products, fn product ->
      ExCache.Ets.put(:product_cache, "product:#{product.sku}", product, ttl: 1800_000)
    end)

    IO.puts("✅ 预热了 #{length(hot_products)} 个热门产品到缓存")
  end
end

# 执行缓存预热
CacheWarmer.warm_user_cache()
CacheWarmer.warm_product_cache()

# 验证预热数据
user_count = ExCache.Ets.stats(:user_cache).puts
product_count = ExCache.Ets.stats(:product_cache).puts
IO.puts("📊 预热统计 - 用户: #{user_count}, 产品: #{product_count}")

# 示例 7：缓存性能监控
IO.puts("\n7. 缓存性能监控")
IO.puts("================")

# 性能监控函数
defmodule CacheMonitor do
  def monitor_cache_performance(cache_name, duration_ms) do
    IO.puts("📊 开始监控缓存性能 #{inspect(cache_name)}...")

    # 重置统计
    ExCache.Ets.reset_stats(cache_name)

    # 模拟负载
    start_time = System.monotonic_time(:millisecond)
    end_time = start_time + duration_ms

    perform_load(cache_name, start_time, end_time)

    # 获取统计信息
    stats = ExCache.Ets.stats(cache_name)
    actual_duration = System.monotonic_time(:millisecond) - start_time

    # 计算性能指标
    ops_per_second = stats.total_operations / (actual_duration / 1000)
    hit_rate = if stats.hits + stats.misses > 0 do
      stats.hits / (stats.hits + stats.misses) * 100
    else
      0
    end

    %{
      duration: actual_duration,
      total_operations: stats.total_operations,
      ops_per_second: Float.round(ops_per_second, 2),
      hit_rate: Float.round(hit_rate, 2),
      stats: stats
    }
  end

  defp perform_load(_cache_name, start_time, end_time) when start_time >= end_time do
    :ok
  end

  defp perform_load(cache_name, start_time, end_time) do
    # 随机执行操作
    key = "key_#{:rand.uniform(100)}"

    case :rand.uniform(3) do
      1 -> ExCache.Ets.put(cache_name, key, "value_#{key}")
      2 -> ExCache.Ets.get(cache_name, key)
      3 -> ExCache.Ets.del(cache_name, key)
    end

    # 控制操作频率
    :timer.sleep(1)
    perform_load(cache_name, System.monotonic_time(:millisecond), end_time)
  end
end

# 监控性能
performance = CacheMonitor.monitor_cache_performance(:db_cache, 2000)
IO.puts("📈 性能监控结果:")
IO.puts("   运行时间: #{performance.duration}ms")
IO.puts("   总操作数: #{performance.total_operations}")
IO.puts("   操作/秒: #{performance.ops_per_second}")
IO.puts("   命中率: #{performance.hit_rate}%")

# 示例 8：缓存层次结构
IO.puts("\n8. 缓存层次结构")
IO.puts("================")

# 实现一个简单的 L1/L2 缓存层次
defmodule CacheHierarchy do
  # L1 缓存 - 小而快
  def get_l1(key) do
    ExCache.Ets.get(:l1_cache, key)
  end

  def put_l1(key, value) do
    ExCache.Ets.put(:l1_cache, key, value, ttl: 60_000)  # 1分钟
  end

  # L2 缓存 - 大而稍慢
  def get_l2(key) do
    ExCache.Ets.get(:l2_cache, key)
  end

  def put_l2(key, value) do
    ExCache.Ets.put(:l2_cache, key, value, ttl: 300_000)  # 5分钟
  end

  # 层次化获取
  def get(key) do
    case get_l1(key) do
      nil ->
        # L1 未命中，尝试 L2
        case get_l2(key) do
          nil ->
            {:miss, nil}
          value ->
            # L2 命中，回填到 L1
            put_l1(key, value)
            {:l2_hit, value}
        end
      value ->
        {:l1_hit, value}
    end
  end

  # 层次化存储（存储到 L1 和 L2）
  def put(key, value) do
    put_l1(key, value)
    put_l2(key, value)
    :ok
  end
end

# 启动层次缓存
{:ok, _l1_pid} = ExCache.Ets.start_link(:l1_cache)
{:ok, _l2_pid} = ExCache.Ets.start_link(:l2_cache)

# 测试缓存层次
IO.puts("🧪 测试缓存层次...")

# 初始获取（应该未命中）
{:miss, nil} = CacheHierarchy.get("hierarchy_key")
IO.puts("📖 初始获取: 未命中")

# 存储值
:ok = CacheHierarchy.put("hierarchy_key", "层次值")
IO.puts("📝 存储值到层次缓存")

# 再次获取（应该 L1 命中）
{:l1_hit, value} = CacheHierarchy.get("hierarchy_key")
IO.puts("📖 第二次获取: L1 命中, 值: #{value}")

# 清理
IO.puts("\n🧹 正在清理缓存进程...")
Enum.each([:db_cache, :session_cache, :user_cache, :product_cache,
           :config_cache, :temp_cache, :l1_cache, :l2_cache], fn name ->
  GenServer.stop(name)
  IO.puts("✅ 已停止缓存: #{inspect(name)}")
end)

# 最终统计总结
IO.puts("\n📊 最终统计总结")
IO.puts("==================")

IO.puts("✅ ExCache 高级使用示例完成！")
IO.puts("\n💡 主要要点:")
IO.puts("   1. 使用 fetch/4 缓存数据库查询和 API 调用")
IO.puts("   2. 为不同数据类型设置合适的 TTL")
IO.puts("   3. 实现会话管理，包括活动更新")
IO.puts("   4. 为分布式系统配置多个缓存实例")
IO.puts("   5. 使用缓存预热提高初始性能")
IO.puts("   6. 监控缓存性能指标")
IO.puts("   7. 实现缓存层次结构优化命中率")
IO.puts("\n🚀 开始在你的应用中应用这些模式吧！")
