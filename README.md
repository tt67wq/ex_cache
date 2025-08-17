# ExCache

ExCache is a simple, yet powerful caching framework for Elixir applications. It provides a fast, in-memory caching solution with TTL (Time To Live) support, comprehensive statistics, and a clean, idiomatic API.

## Features

- **Fast In-Memory Caching**: Built on ETS (Erlang Term Storage) for optimal performance
- **TTL Support**: Automatic expiration of cached entries with configurable time-to-live
- **Comprehensive Statistics**: Real-time tracking of cache hits, misses, and operations
- **Manual Cleanup**: On-demand cleanup of expired entries in addition to automatic cleanup
- **OTP Integration**: Full GenServer-based implementation with supervisor support
- **Concurrent Access**: Thread-safe operations with excellent performance under load
- **Flexible API**: Simple put/get/delete operations with powerful fallback functionality
- **Idiomatic Elixir**: Follows Elixir conventions and best practices

## Installation

Add `ex_cache` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_cache, "~> 0.2.0"}
  ]
end
```

Then run `mix deps.get` to install the dependency.

## Usage

### Basic Usage

```elixir
# Start a cache process
{:ok, pid} = ExCache.Ets.start_link(:my_cache)

# Store a value
:ok = ExCache.Ets.put(:my_cache, :user_123, %{name: "John", email: "john@example.com"})

# Retrieve a value
user = ExCache.Ets.get(:my_cache, :user_123)
# => %{name: "John", email: "john@example.com"}

# Store with TTL (in milliseconds)
:ok = ExCache.Ets.put(:my_cache, :session_token, "abc123", ttl: 3600000)  # 1 hour

# Delete a value
:ok = ExCache.Ets.del(:my_cache, :user_123)
```

### Using Fetch with Fallback

The `fetch/4` function provides a powerful pattern for retrieving values with fallback logic:

```elixir
# Fetch with automatic caching of computed value
user = ExCache.Ets.fetch(:my_cache, :user_456, [ttl: 300000], fn user_id ->
  # This function is only called if the key is not in cache
  {:commit, Database.get_user(user_id)}  # Store the result in cache
end)

# Fetch without caching (ignore pattern)
config = ExCache.Ets.fetch(:my_cache, :app_config, [], fn key ->
  {:ignore, File.read!("config/#{key}.json")}  # Return without storing
end)
```

### Supervisor Integration

ExCache is designed to work seamlessly with OTP supervisors:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      {ExCache.Ets, name: :my_cache},
      # ... other children
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Cache Statistics

Monitor cache performance with built-in statistics:

```elixir
# Get current statistics
stats = ExCache.Ets.stats(:my_cache)
# => %{
#   hits: 1250,
#   misses: 42,
#   puts: 1320,
#   deletes: 89,
#   total_operations: 2701
# }

# Calculate hit rate
hit_rate = stats.hits / (stats.hits + stats.misses)
# => 0.9675 (96.75% hit rate)

# Reset statistics when needed
:ok = ExCache.Ets.reset_stats(:my_cache)
```

### Manual Cleanup

While ExCache automatically cleans up expired entries, you can also trigger manual cleanup:

```elixir
# Manually clean up expired entries
{:ok, deleted_count} = ExCache.Ets.cleanup_expired(:my_cache)
IO.puts("Cleaned up #{deleted_count} expired entries")
```

## API Reference

### Core Functions

#### `put(name, key, value, opts \\ [])`

Store a key-value pair in the cache.

- **Parameters**:
  - `name`: Cache process name or PID
  - `key`: Any term to use as the key
  - `value`: Any term to store as the value
  - `opts`: Keyword list of options

- **Options**:
  - `:ttl` - Time to live in milliseconds (default: `:infinity`)

- **Returns**: `:ok`

#### `get(name, key)`

Retrieve a value from the cache.

- **Parameters**:
  - `name`: Cache process name or PID
  - `key`: Key to retrieve

- **Returns**: `value | nil` (returns `nil` if key doesn't exist or has expired)

#### `del(name, key)`

Delete a key-value pair from the cache.

- **Parameters**:
  - `name`: Cache process name or PID
  - `key`: Key to delete

- **Returns**: `:ok`

### Advanced Functions

#### `fetch(name, key, opts \\ [], fallback)`

Retrieve a value with fallback functionality.

- **Parameters**:
  - `name`: Cache process name or PID
  - `key`: Key to retrieve
  - `opts`: Keyword list of options
  - `fallback`: Function to call if key is not found

- **Options**:
  - `:ttl` - Time to live for newly cached values (default: `:infinity`)

- **Fallback Function**: Should return either:
  - `{:commit, value}` - Store the value in cache and return it
  - `{:ignore, value}` - Return the value without storing it

- **Returns**: The cached or computed value

### Statistics Functions

#### `stats(name)`

Get cache statistics.

- **Parameters**:
  - `name`: Cache process name or PID

- **Returns**: Map containing:
  - `:hits` - Number of cache hits
  - `:misses` - Number of cache misses
  - `:puts` - Number of put operations
  - `:deletes` - Number of delete operations
  - `:total_operations` - Total number of operations

#### `reset_stats(name)`

Reset all cache statistics to zero.

- **Parameters**:
  - `name`: Cache process name or PID

- **Returns**: `:ok`

### Maintenance Functions

#### `cleanup_expired(name)`

Manually clean up expired entries.

- **Parameters**:
  - `name`: Cache process name or PID

- **Returns**: `{:ok, deleted_count}` where `deleted_count` is the number of entries deleted

## Configuration

### Cache Process Configuration

The cache process uses a timeout of 5000 milliseconds for automatic cleanup of expired entries. This is currently not configurable but provides a good balance between cleanup frequency and performance.

### TTL Management

- **Infinite TTL**: Use `ttl: :infinity` for entries that should never expire
- **Short TTL**: Values like `ttl: 1000` (1 second) for temporary data
- **Long TTL**: Values like `ttl: 86400000` (24 hours) for long-term caching

### Error Handling

ExCache gracefully handles various edge cases:

- **Invalid TTL Values**: Negative, zero, or invalid TTL values are treated as `:infinity`
- **Missing Keys**: `get/3` and `del/3` operations on non-existent keys are safe and return appropriate values
- **Concurrent Access**: All operations are thread-safe and designed for concurrent use

## Performance Considerations

### Memory Usage

ExCache uses ETS tables for storage, which are kept in memory. Monitor memory usage when caching large amounts of data.

### Automatic Cleanup

Expired entries are automatically cleaned up every 5 seconds. This process is efficient and doesn't block normal operations.

### Concurrency

The cache is designed for high concurrency with minimal contention between operations. All read operations are synchronous, while write operations are asynchronous.

## Testing

Run the test suite:

```bash
mix test
```

Include property tests:

```bash
mix test test/ex_cache_property_test.exs
```

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup

1. Fork the repository
2. Clone your fork: `git clone https://github.com/your-username/ex_cache.git`
3. Create your feature branch: `git checkout -b feature/amazing-feature`
4. Install dependencies: `mix deps.get`
5. Run tests: `mix test`
6. Commit your changes: `git commit -m 'Add amazing feature'`
7. Push to the branch: `git push origin feature/amazing-feature`
8. Open a Pull Request

### Code Style

- Follow the existing code style
- Ensure all tests pass
- Add tests for new functionality
- Update documentation as needed

## License

ExCache is released under the [MIT License](LICENSE).

## Changelog

### v0.2.0 (2024-01-XX)

#### Added
- Comprehensive statistics tracking for cache operations
- Manual cleanup functionality for expired entries
- Enhanced TTL management with graceful error handling
- Extensive test suite including property-based tests
- Complete API documentation and usage examples

#### Changed
- Improved error handling for invalid TTL values
- Optimized cleanup algorithm for better performance
- Enhanced concurrent operation support

#### Fixed
- API return value consistency across all operations
- TTL expiration edge cases
- Memory leaks in cleanup process

### v0.1.1 (2024-01-XX)

- Initial release
- Basic ETS-based caching implementation
- TTL support
- Core API functions