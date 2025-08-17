# ExCache

ExCache 是一个简洁而强大的 Elixir 缓存框架。它提供快速的内存缓存解决方案，支持 TTL（生存时间）、全面的统计信息和清晰、符合 Elixir 惯用语的 API。

## 特性

- **快速内存缓存**: 基于 ETS（Erlang 项存储）构建，性能优化
- **TTL 支持**: 自动过期缓存条目，支持可配置的生存时间
- **全面统计**: 实时跟踪缓存命中、未命中和操作次数
- **手动清理**: 除自动清理外，支持按需清理过期条目
- **OTP 集成**: 基于 GenServer 的完整实现，支持监控器
- **并发访问**: 线程安全操作，在高负载下性能优异
- **灵活 API**: 简单的 put/get/delete 操作，支持强大的回退功能
- **惯用 Elixir**: 遵循 Elixir 约定和最佳实践

## 安装

在 `mix.exs` 中将 `ex_cache` 添加到依赖列表：

```elixir
def deps do
  [
    {:ex_cache, "~> 0.2.0"}
  ]
end
```

然后运行 `mix deps.get` 安装依赖。

## 使用方法

### 基本用法

```elixir
# 启动缓存进程
{:ok, pid} = ExCache.Ets.start_link(:my_cache)

# 存储一个值
:ok = ExCache.Ets.put(:my_cache, :user_123, %{name: "张三", email: "zhangsan@example.com"})

# 检索一个值
user = ExCache.Ets.get(:my_cache, :user_123)
# => %{name: "张三", email: "zhangsan@example.com"}

# 存储带 TTL 的值（以毫秒为单位）
:ok = ExCache.Ets.put(:my_cache, :session_token, "abc123", ttl: 3600000)  # 1小时

# 删除一个值
:ok = ExCache.Ets.del(:my_cache, :user_123)
```

### 使用回退功能的 Fetch

`fetch/4` 函数为使用回退逻辑检索值提供了强大的模式：

```elixir
# 获取并自动缓存计算值
user = ExCache.Ets.fetch(:my_cache, :user_456, [ttl: 300000], fn user_id ->
  # 仅当键不在缓存中时调用此函数
  {:commit, Database.get_user(user_id)}  # 将结果存储在缓存中
end)

# 获取但不缓存（忽略模式）
config = ExCache.Ets.fetch(:my_cache, :app_config, [], fn key ->
  {:ignore, File.read!("config/#{key}.json")}  # 返回但不存储
end)
```

### 监控器集成

ExCache 设计为与 OTP 监控器无缝协作：

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      {ExCache.Ets, name: :my_cache},
      # ... 其他子进程
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### 缓存统计

使用内置统计信息监控缓存性能：

```elixir
# 获取当前统计信息
stats = ExCache.Ets.stats(:my_cache)
# => %{
#   hits: 1250,
#   misses: 42,
#   puts: 1320,
#   deletes: 89,
#   total_operations: 2701
# }

# 计算命中率
hit_rate = stats.hits / (stats.hits + stats.misses)
# => 0.9675 (96.75% 命中率)

# 需要时重置统计信息
:ok = ExCache.Ets.reset_stats(:my_cache)
```

### 手动清理

虽然 ExCache 会自动清理过期条目，但您也可以触发手动清理：

```elixir
# 手动清理过期条目
{:ok, deleted_count} = ExCache.Ets.cleanup_expired(:my_cache)
IO.puts("清理了 #{deleted_count} 个过期条目")
```

## API 参考

### 核心函数

#### `put(name, key, value, opts \\ [])`

在缓存中存储键值对。

- **参数**:
  - `name`: 缓存进程名或 PID
  - `key`: 用作键的任何项
  - `value`: 存储为值的任何项
  - `opts`: 选项关键字列表

- **选项**:
  - `:ttl` - 生存时间（毫秒）（默认: `:infinity`）

- **返回**: `:ok`

#### `get(name, key)`

从缓存中检索值。

- **参数**:
  - `name`: 缓存进程名或 PID
  - `key`: 要检索的键

- **返回**: `value | nil`（如果键不存在或已过期则返回 `nil`）

#### `del(name, key)`

从缓存中删除键值对。

- **参数**:
  - `name`: 缓存进程名或 PID
  - `key`: 要删除的键

- **返回**: `:ok`

### 高级函数

#### `fetch(name, key, opts \\ [], fallback)`

使用回退功能检索值。

- **参数**:
  - `name`: 缓存进程名或 PID
  - `key`: 要检索的键
  - `opts`: 选项关键字列表
  - `fallback`: 如果找不到键时调用的函数

- **选项**:
  - `:ttl` - 新缓存值的生存时间（默认: `:infinity`）

- **回退函数**: 应返回以下之一：
  - `{:commit, value}` - 将值存储在缓存中并返回它
  - `{:ignore, value}` - 返回值但不存储它

- **返回**: 缓存的或计算的值

### 统计函数

#### `stats(name)`

获取缓存统计信息。

- **参数**:
  - `name`: 缓存进程名或 PID

- **返回**: 包含以下内容的映射：
  - `:hits` - 缓存命中次数
  - `:misses` - 缓存未命中次数
  - `:puts` - 存储操作次数
  - `:deletes` - 删除操作次数
  - `:total_operations` - 总操作次数

#### `reset_stats(name)`

将所有缓存统计信息重置为零。

- **参数**:
  - `name`: 缓存进程名或 PID

- **返回**: `:ok`

### 维护函数

#### `cleanup_expired(name)`

手动清理过期条目。

- **参数**:
  - `name`: 缓存进程名或 PID

- **返回**: `{:ok, deleted_count}` 其中 `deleted_count` 是被删除的条目数

## 配置

### 缓存进程配置

缓存进程使用 5000 毫秒的超时时间来自动清理过期条目。目前此值不可配置，但在清理频率和性能之间提供了良好的平衡。

### TTL 管理

- **无限 TTL**: 使用 `ttl: :infinity` 永不过期的条目
- **短 TTL**: `ttl: 1000`（1秒）等值用于临时数据
- **长 TTL**: `ttl: 86400000`（24小时）等值用于长期缓存

### 错误处理

ExCache 优雅地处理各种边缘情况：

- **无效 TTL 值**: 负数、零或无效 TTL 值被视为 `:infinity`
- **缺失键**: 对不存在键的 `get/3` 和 `del/3` 操作是安全的，并返回适当的值
- **并发访问**: 所有操作都是线程安全的，专为并发使用而设计

## 性能考虑

### 内存使用

ExCache 使用 ETS 表进行存储，这些表保存在内存中。缓存大量数据时请监控内存使用情况。

### 自动清理

过期条目每 5 秒自动清理。这个过程是高效的，不会阻塞正常操作。

### 并发性

缓存专为高并发设计，操作之间的争用最小。所有读取操作都是同步的，而写入操作是异步的。

## 测试

运行测试套件：

```bash
mix test
```

包含属性测试：

```bash
mix test test/ex_cache_property_test.exs
```

## 贡献

我们欢迎贡献！请查看我们的[贡献指南](CONTRIBUTING.md)了解详情。

### 开发设置

1. Fork 仓库
2. 克隆你的 fork: `git clone https://github.com/your-username/ex_cache.git`
3. 创建功能分支: `git checkout -b feature/amazing-feature`
4. 安装依赖: `mix deps.get`
5. 运行测试: `mix test`
6. 提交你的更改: `git commit -m '添加令人惊奇的功能'`
7. 推送到分支: `git push origin feature/amazing-feature`
8. 打开一个 Pull Request

### 代码风格

- 遵循现有代码风格
- 确保所有测试都通过
- 为新功能添加测试
- 根据需要更新文档

## 许可证

ExCache 以 [MIT 许可证](LICENSE)发布。

## 更新日志

### v0.2.0 (2024-01-XX)

#### 新增
- 缓存操作的全面统计跟踪
- 过期条目的手动清理功能
- 增强的 TTL 管理，具有优雅的错误处理
- 包括属性测试的广泛测试套件
- 完整的 API 文档和使用示例

#### 更改
- 改进了无效 TTL 值的错误处理
- 优化了清理算法以获得更好的性能
- 增强了并发操作支持

#### 修复
- 所有操作的 API 返回值一致性
- TTL 过期边缘情况
- 清理过程中的内存泄漏

### v0.1.1 (2024-01-XX)

- 初始版本
- 基于基础的 ETS 缓存实现
- TTL 支持
- 核心 API 函数