#!/usr/bin/env elixir

# ExCache 基本使用示例
 #
 # 本文件演示了在应用程序中使用 ExCache 的基本操作和模式。

# 在项目根目录下执行: mix run examples/basic_usage_cn.exs

alias ExCache.Ets

IO.puts("=== ExCache 基本使用示例 ===\n")

# 示例 1：启动缓存
IO.puts("1. 启动缓存")
IO.puts("--------------------------------")

# 启动一个缓存进程
{:ok, cache_pid} = ExCache.Ets.start_link(:example_cache)
IO.puts("✅ 缓存已启动: #{inspect(cache_pid)}")

# 示例 2：基本的存储和检索操作
IO.puts("\n2. 基本的存储和检索操作")
IO.puts("--------------------------------")

# 存储一个简单的值
ExCache.Ets.put(:example_cache, :greeting, "你好，世界！")
IO.puts("📝 已存储: :greeting => \"你好，世界！\"")

# 检索值
greeting = ExCache.Ets.get(:example_cache, :greeting)
IO.puts("📖 已检索: #{inspect(greeting)}")

# 示例 3：处理不同的数据类型
IO.puts("\n3. 处理不同的数据类型")
IO.puts("--------------------------------")

# 存储各种类型的数据
data_examples = %{
  string: "Elixir 太棒了！",
  number: 42,
  float: 3.14159,
  atom: :elixir,
  list: [1, 2, 3, 4, 5],
  map: %{name: "张三", age: 30, city: "北京"},
  tuple: {:user, "zhangsan@example.com", :active}
}

Enum.each(data_examples, fn {key, value} ->
  # 存储数据
  ExCache.Ets.put(:example_cache, key, value)
  IO.puts("📝 已存储 #{inspect(key)} => #{inspect(value)}")

  # 检索并验证
  retrieved = ExCache.Ets.get(:example_cache, key)
  IO.puts("📖 已检索 #{inspect(key)} => #{inspect(retrieved)}")
  IO.puts("")
end)

# 示例 4：使用 TTL（生存时间）
IO.puts("\n4. 使用 TTL（生存时间）")
IO.puts("--------------------------------")

# 存储一个 2 秒后过期的值
ExCache.Ets.put(:example_cache, :temp_session, "session_abc123", ttl: 2000)
IO.puts("📝 已存储临时会话（2秒后过期）")

# 立即检索
session = ExCache.Ets.get(:example_cache, :temp_session)
IO.puts("📖 立即检索: #{inspect(session)}")

# 等待过期
IO.puts("⏳ 等待过期...")
:timer.sleep(2100)

# 过期后尝试检索
expired_session = ExCache.Ets.get(:example_cache, :temp_session)
IO.puts("📖 过期后检索: #{inspect(expired_session)}")

# 示例 5：删除操作
IO.puts("\n5. 删除操作")
IO.puts("--------------------------------")

# 存储一个要删除的值
ExCache.Ets.put(:example_cache, :to_delete, "这将被删除")
IO.puts("📝 已存储要删除的值")

# 验证它存在
before_delete = ExCache.Ets.get(:example_cache, :to_delete)
IO.puts("📖 删除前: #{inspect(before_delete)}")

# 删除它
ExCache.Ets.del(:example_cache, :to_delete)
IO.puts("🗑️  已删除值")

# 验证它已被删除
after_delete = ExCache.Ets.get(:example_cache, :to_delete)
IO.puts("📖 删除后: #{inspect(after_delete)}")

# 示例 6：使用复杂的键
IO.puts("\n6. 使用复杂的键")
IO.puts("--------------------------------")

complex_keys = [
  {:user, 123},
  ["配置", "应用", "设置"],
  %{type: "会话", id: "abc123"},
  "simple_string_key"
]

Enum.each(complex_keys, fn key ->
  value = "#{inspect(key)} 的值"
  ExCache.Ets.put(:example_cache, key, value)
  IO.puts("📝 使用键 #{inspect(key)} 存储")

  retrieved = ExCache.Ets.get(:example_cache, key)
  IO.puts("📖 检索: #{retrieved}")
  IO.puts("")
end)

# 示例 7：基本的错误处理
IO.puts("\n7. 基本的错误处理")
IO.puts("--------------------------------")

# 尝试检索不存在的键
non_existent = ExCache.Ets.get(:example_cache, :non_existent_key)
IO.puts("📖 不存在的键结果: #{inspect(non_existent)}")

# 删除不存在的键（不应该崩溃）
result = ExCache.Ets.del(:example_cache, :definitely_not_there)
IO.puts("🗑️  删除不存在的键结果: #{inspect(result)}")

# 示例 8：使用 fetch 的回退功能
IO.puts("\n8. 使用 fetch 的回退功能")
IO.puts("--------------------------------")

# 首次获取 - 会调用回退函数
result1 = ExCache.Ets.fetch(:example_cache, :fetch_key, [ttl: 5000], fn _key ->
  IO.puts("🔄 调用回退函数计算值...")
  {:commit, "计算出的值"}
end)
IO.puts("📖 首次获取结果: #{result1}")

# 再次获取 - 应该从缓存中获取
result2 = ExCache.Ets.fetch(:example_cache, :fetch_key, [], fn _key ->
  IO.puts("🔄 这个回退函数不应该被调用")
  {:commit, "不应该到达这里"}
end)
IO.puts("📖 第二次获取结果: #{result2}")

# 使用 ignore 模式
result3 = ExCache.Ets.fetch(:example_cache, :ignore_key, [], fn _key ->
  IO.puts("🔄 调用 ignore 回退函数...")
  {:ignore, "不缓存的值"}
end)
IO.puts("📖 ignore 模式结果: #{result3}")

# 检查 ignore 模式是否真的没有缓存
cached_check = ExCache.Ets.get(:example_cache, :ignore_key)
IO.puts("📖 ignore 模式后缓存检查: #{inspect(cached_check)}")

# 示例 9：缓存统计信息
IO.puts("\n9. 缓存统计信息")
IO.puts("--------------------------------")

# 重置统计信息以开始清洁
ExCache.Ets.reset_stats(:example_cache)

# 执行一些操作
ExCache.Ets.put(:example_cache, :stats_key1, "值1")
ExCache.Ets.put(:example_cache, :stats_key2, "值2")
ExCache.Ets.get(:example_cache, :stats_key1)  # 命中
ExCache.Ets.get(:example_cache, :stats_key1)  # 再次命中
ExCache.Ets.get(:example_cache, :nonexistent)  # 未命中
ExCache.Ets.del(:example_cache, :stats_key2)

# 获取统计信息
stats = ExCache.Ets.stats(:example_cache)
IO.puts("📊 缓存统计信息:")
IO.puts("   命中: #{stats.hits}")
IO.puts("   未命中: #{stats.misses}")
IO.puts("   存储操作: #{stats.puts}")
IO.puts("   删除操作: #{stats.deletes}")
IO.puts("   总操作数: #{stats.total_operations}")

# 计算命中率
total_access = stats.hits + stats.misses
hit_rate = if total_access > 0, do: stats.hits / total_access * 100, else: 0
IO.puts("   命中率: #{Float.round(hit_rate, 2)}%")

# 示例 10：手动清理
IO.puts("\n10. 手动清理")
IO.puts("--------------------------------")

# 存储一些短期条目
ExCache.Ets.put(:example_cache, :expire1, "即将过期1", ttl: 100)
ExCache.Ets.put(:example_cache, :expire2, "即将过期2", ttl: 100)
ExCache.Ets.put(:example_cache, :forever, "永不过期", ttl: :infinity)

# 验证它们都存在
IO.puts("📖 过期前检查:")
IO.puts("   expire1: #{inspect(ExCache.Ets.get(:example_cache, :expire1))}")
IO.puts("   expire2: #{inspect(ExCache.Ets.get(:example_cache, :expire2))}")
IO.puts("   forever: #{inspect(ExCache.Ets.get(:example_cache, :forever))}")

# 等待过期
:timer.sleep(150)

# 手动清理
{:ok, deleted_count} = ExCache.Ets.cleanup_expired(:example_cache)
IO.puts("🧹 手动清理完成，删除了 #{deleted_count} 个过期条目")

# 验证清理结果
IO.puts("📖 清理后检查:")
IO.puts("   expire1: #{inspect(ExCache.Ets.get(:example_cache, :expire1))}")
IO.puts("   expire2: #{inspect(ExCache.Ets.get(:example_cache, :expire2))}")
IO.puts("   forever: #{inspect(ExCache.Ets.get(:example_cache, :forever))}")

# 清理
IO.puts("\n🧹 正在清理...")
GenServer.stop(:example_cache)
IO.puts("✅ 缓存进程已停止")

IO.puts("\n🎉 基本使用示例已完成！")
IO.puts("\n💡 下一步：查看 advanced_usage_cn.exs 了解更高级的模式！")
