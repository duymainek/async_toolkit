# Async Toolkit

[![Pub Version](https://img.shields.io/pub/v/async_toolkit.svg)](https://pub.dev/packages/async_toolkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Stars](https://img.shields.io/github/stars/duymainek/async_toolkit.svg)](https://github.com/duymainek/async_toolkit)

A comprehensive Dart package providing powerful utilities for asynchronous programming, including cancellation tokens, timeout management, retry mechanisms, parallel execution control, and rate limiting (throttle/debounce).

## 🚀 Features

### 🔧 Cancellation Tokens
- **CancellationToken & CancellationTokenSource** - Cooperative cancellation for async operations
- **Enhanced completion detection** - Clear distinction between cancellation and timeout
- **Composite tokens** - Coordinate multiple cancellation sources
- **Resource management** - Proper cleanup and disposal patterns

### ⏱️ Timeout Management
- **Flexible timeout control** - With fallback values and custom error handling
- **Cancellation integration** - Seamless integration with cancellation tokens
- **Simplified implementation** - Leveraging Dart's built-in timeout mechanisms

### 🔄 Retry Mechanisms
- **Exponential backoff** - With configurable multiplier and jitter
- **Linear backoff** - Fixed increment delay strategies
- **Custom backoff** - Define your own delay functions
- **Cancellation-aware** - Respects cancellation during delays

### ⚡ Parallel Execution
- **Limited parallelism** - Control concurrent operation count
- **Multiple result patterns** - Ordered, unordered, or callback-based
- **Resource efficient** - Optimized memory usage and cleanup
- **Cancellation support** - Cancel entire parallel operations

### 🚦 Rate Limiting (Throttle & Debounce)
- **Throttle** - Limit execution frequency with result caching
- **Debounce** - Delay execution until pause in calls
- **Global functions** - Convenient one-off usage
- **Manager classes** - For repeated use with lifecycle management
- **Error handling** - Proper exception propagation and cleanup

## 📦 Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  async_toolkit: ^1.0.0
```

Then run:

```bash
dart pub get
```

## 🎯 Quick Start

### Cancellation Tokens

```dart
import 'package:async_toolkit/async_toolkit.dart';

Future<void> main() async {
  final source = CancellationTokenSource();
  
  // Cancel after 5 seconds
  Timer(Duration(seconds: 5), () => source.cancel());
  
  try {
    await longRunningOperation(source.token);
  } on OperationCanceledException {
    print('Operation was cancelled');
  } finally {
    source.dispose();
  }
}

Future<String> longRunningOperation(CancellationToken token) async {
  for (int i = 0; i < 10; i++) {
    // Check for cancellation
    token.throwIfCancellationRequested();
    
    await Future.delayed(Duration(seconds: 1));
    print('Step ${i + 1}/10 completed');
  }
  return 'Operation completed';
}
```

### Enhanced Cancellation Completion

```dart
// New: Clear completion reason detection
final reason = await token.whenCancelledOrTimeout(Duration(seconds: 30));
switch (reason) {
  case CancellationCompletionReason.cancelled:
    print('User cancelled the operation');
    break;
  case CancellationCompletionReason.timeout:
    print('Operation timed out');
    break;
}
```

### Timeout Control

```dart
// Simple timeout
final result = await withTimeout(
  slowOperation(),
  Duration(seconds: 10),
);

// Timeout with default value
final result = await withTimeoutOrDefault(
  slowOperation(),
  Duration(seconds: 10),
  'Default value',
);
```

### Retry with Exponential Backoff

```dart
final result = await withExponentialBackoff(
  () => unstableApiCall(),
  maxAttempts: 5,
  baseDelay: Duration(milliseconds: 100),
  multiplier: 2.0,
  jitter: true,
);
```

### Parallel Execution

```dart
final futures = List.generate(10, (i) => 
  Future.delayed(Duration(seconds: 1), () => 'Task $i')
);

// Run max 3 concurrent operations
final results = await runLimitedParallel(
  futures,
  maxParallel: 3,
);
```

### Throttle & Debounce

```dart
// Throttle: Execute once per duration, cache results
final throttleManager = ThrottleManager<String>(Duration(seconds: 1));
final result = await throttleManager.throttle(() => expensiveOperation());

// Debounce: Execute after pause in calls
final debounceManager = DebounceManager<String>(Duration(milliseconds: 300));
final result = await debounceManager.debounce(() => searchOperation());

// Global functions for one-off usage
final throttledResult = await throttle(operation, Duration(seconds: 1));
final debouncedResult = await debounce(operation, Duration(milliseconds: 300));
```

## 📚 Advanced Usage

### Composite Cancellation Tokens

```dart
final tokenA = CancellationTokenSource();
final tokenB = CancellationTokenSource();
final tokenC = CancellationTokenSource();

// Create composite token that cancels when ANY source cancels
final compositeSource = CancellationTokenSource.any([
  tokenA.token,
  tokenB.token,
  tokenC.token,
]);

// Use composite token
await someOperation(compositeSource.token);

// Cleanup
tokenA.dispose();
tokenB.dispose();
tokenC.dispose();
compositeSource.dispose();
```

### Custom Retry Strategies

```dart
final result = await withRetryConfig(
  () => apiCall(),
  RetryConfig(
    maxAttempts: 5,
    backoff: (attempt) => Duration(milliseconds: 100 * attempt * attempt), // Quadratic backoff
    retryIf: (exception) => exception is SocketException, // Only retry network errors
    jitter: true,
    maxDelay: Duration(seconds: 30),
  ),
);
```

### Real-world Search Implementation

```dart
class SearchController {
  final _debounceManager = DebounceManager<List<String>>(Duration(milliseconds: 300));
  
  Future<void> onSearchChanged(String query) async {
    if (query.isEmpty) return;
    
    try {
      final results = await _debounceManager.debounce(() => performSearch(query));
      updateUI(results);
    } on OperationCanceledException {
      // Search was cancelled by newer search
    }
  }
  
  void dispose() => _debounceManager.dispose();
}
```

## 🔧 API Reference

### Core Classes

| Class | Description |
|-------|-------------|
| `CancellationToken` | Token for cooperative cancellation |
| `CancellationTokenSource` | Creates and controls cancellation tokens |
| `ThrottleManager<T>` | Manages throttled operation execution |
| `DebounceManager<T>` | Manages debounced operation execution |
| `RetryConfig` | Configuration for retry strategies |

### Key Functions

| Function | Description |
|----------|-------------|
| `withTimeout<T>()` | Execute with timeout |
| `withRetry<T>()` | Execute with retry logic |
| `withExponentialBackoff<T>()` | Retry with exponential backoff |
| `runLimitedParallel<T>()` | Execute with limited parallelism |
| `throttle<T>()` | Global throttle function |
| `debounce<T>()` | Global debounce function |

### Enums

| Enum | Values | Description |
|------|--------|-------------|
| `CancellationCompletionReason` | `cancelled`, `timeout` | Reason for completion |

## 📖 Examples

Check out the comprehensive examples in the [`example/`](./example) directory:

- **[Main Example](./example/example.dart)** - Showcases all features
- **[Throttle/Debounce Example](./example/throttle_debounce_example.dart)** - Detailed rate limiting examples

Run examples:

```bash
# Main comprehensive example
dart run example/example.dart

# Detailed throttle/debounce examples
dart run example/throttle_debounce_example.dart
```

## 🧪 Testing

The package includes comprehensive tests covering all functionality:

```bash
dart test
```

Current test coverage: **148 tests passing** ✅

## 🔄 Migration Guide

### From Legacy APIs

The package maintains backward compatibility while introducing enhanced APIs:

```dart
// Old (still works, but deprecated)
try {
  await token.whenCancelledOrTimeoutLegacy(duration);
} on TimeoutException {
  // Handle timeout
}

// New (recommended)
final reason = await token.whenCancelledOrTimeout(duration);
switch (reason) {
  case CancellationCompletionReason.cancelled:
    // Handle cancellation
  case CancellationCompletionReason.timeout:
    // Handle timeout
}
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by .NET's CancellationToken pattern
- Built with Dart's powerful async/await capabilities
- Follows Dart/Flutter best practices for package development

## 📞 Support

- **GitHub Issues**: [Report bugs or request features](https://github.com/duymainek/async_toolkit/issues)
- **Pub.dev**: [Package page](https://pub.dev/packages/async_toolkit)
- **Documentation**: [API documentation](https://pub.dev/documentation/async_toolkit/latest/)

---

**Made with ❤️ for the Dart/Flutter community**