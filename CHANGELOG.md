# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-03

### 🎉 Initial Release

A comprehensive async toolkit for Dart providing cancellation tokens, timeout management, retry mechanisms, parallel execution control, and rate limiting.

### ✨ Added

#### Cancellation System
- **CancellationToken & CancellationTokenSource** - Cooperative cancellation pattern
- **Enhanced `whenCancelledOrTimeout`** - Returns `CancellationCompletionReason` enum for clear completion detection
- **Composite tokens** - `CancellationTokenSource.any()` for coordinating multiple cancellation sources
- **Proper resource management** - Automatic cleanup of subscriptions and resources
- **Backward compatibility** - Deprecated legacy methods with migration path

#### Timeout Management  
- **`withTimeout<T>()`** - Execute operations with timeout
- **`withTimeoutOrNull<T>()`** - Return null on timeout instead of throwing
- **`withTimeoutOrDefault<T>()`** - Return default value on timeout
- **Cancellation integration** - Seamless integration with CancellationToken
- **Simplified implementation** - Uses Dart's built-in `Future.timeout()`

#### Retry Mechanisms
- **`withRetry<T>()`** - Basic retry with custom backoff
- **`withExponentialBackoff<T>()`** - Exponential backoff with jitter
- **`withLinearBackoff<T>()`** - Linear delay increment
- **`withFixedDelay<T>()`** - Fixed delay between attempts  
- **`RetryConfig`** - Comprehensive retry configuration
- **Cancellation-aware delays** - Can be cancelled during wait periods
- **Custom retry conditions** - `retryIf` predicate for selective retries

#### Parallel Execution
- **`runLimitedParallel<T>()`** - Execute with limited concurrency (ordered results)
- **`runLimitedParallelUnordered<T>()`** - Execute with limited concurrency (completion order)
- **`runLimitedParallelWithCallback<T>()`** - Execute with result callbacks
- **Resource optimization** - Efficient memory usage with simple counters vs Maps
- **Cancellation support** - Cancel entire parallel operations
- **Clean architecture** - Single core implementation with specialized wrappers

#### Rate Limiting (Throttle & Debounce)
- **`ThrottleManager<T>`** - Rate limiting with result caching
- **`DebounceManager<T>`** - Delay execution until pause in calls
- **Global functions** - `throttle<T>()` and `debounce<T>()` for one-off usage
- **Custom keys** - Isolate operations with unique keys
- **Error handling** - Failed operations don't cache results
- **Resource management** - Proper disposal with `isDisposed` state
- **Global cleanup** - `clearGlobalManagers()` for test cleanup

### 🔧 Technical Improvements

#### Code Quality
- **DRY principle** - Eliminated code duplication across implementations
- **Single responsibility** - Clear separation of concerns
- **Type safety** - Enum-based completion detection vs exception-based
- **Resource efficiency** - Optimized memory usage and cleanup patterns

#### Testing
- **Comprehensive test suite** - 148 tests covering all functionality
- **Edge case coverage** - Disposal, race conditions, error scenarios
- **Performance tests** - Timing-sensitive operations with variance tolerance
- **Integration tests** - Real-world usage patterns

#### Documentation
- **Comprehensive README** - Usage examples and API reference
- **Inline documentation** - Detailed method and class documentation
- **Migration guide** - Clear path from legacy APIs
- **Examples** - Working examples for all features

### 📚 Examples

#### Main Example (`example/example.dart`)
- Cancellation tokens with API calls
- Enhanced cancellation completion detection
- Composite token coordination
- Timeout control strategies
- Retry mechanisms with backoff
- Parallel execution patterns
- Basic throttle/debounce usage

#### Specialized Example (`example/throttle_debounce_example.dart`)
- Detailed ThrottleManager usage
- DebounceManager patterns
- Real-world search implementation
- Resource management best practices

### 🏗️ Architecture

#### Design Patterns
- **Strategy pattern** - Pluggable backoff strategies
- **Observer pattern** - Cancellation token notifications
- **Factory pattern** - Composite token creation
- **Disposable pattern** - Resource lifecycle management

#### Performance Optimizations
- **Reduced allocations** - Simple counters vs complex Maps
- **Efficient cleanup** - Proper subscription management
- **Lazy initialization** - Resources created only when needed
- **Memory-friendly** - Automatic cleanup of unused resources

### 🔒 Stability

- **Null safety** - Full null safety support
- **Exception safety** - Proper error handling and cleanup
- **Thread safety** - Safe for use in async contexts
- **Resource safety** - No memory leaks with proper disposal

### 📦 Package Info

- **Dart SDK**: `>=3.0.0 <4.0.0`
- **Dependencies**: None (pure Dart implementation)
- **License**: MIT
- **Repository**: [https://github.com/duymainek/async_toolkit](https://github.com/duymainek/async_toolkit)

---

## Future Roadmap

### Planned Features
- **Stream utilities** - Cancellable stream operations
- **Batch operations** - Efficient batch processing utilities  
- **Circuit breaker** - Fault tolerance patterns
- **Rate limiter** - Token bucket and sliding window algorithms
- **Async locks** - Semaphores and mutexes for async coordination

### Performance Improvements
- **Benchmarking suite** - Performance regression testing
- **Memory profiling** - Optimize memory usage patterns
- **Async optimization** - Further reduce Future allocations

---

**Note**: This is the initial release establishing the foundation for async utilities in Dart. Future versions will focus on expanding functionality while maintaining backward compatibility.