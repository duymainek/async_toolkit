# Async Toolkit

[![Pub Version](https://img.shields.io/pub/v/async_toolkit.svg)](https://pub.dev/packages/async_toolkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Stars](https://img.shields.io/github/stars/duymainek/async_toolkit.svg)](https://github.com/duymainek/async_toolkit)

A comprehensive Dart package providing powerful utilities for asynchronous programming: timeout management, retry mechanisms, throttle/debounce, parallel execution, and cancellation tokens.

## 📦 Installation

```yaml
dependencies:
  async_toolkit: ^1.0.0
```

```bash
dart pub get
```

## 🎯 Key Features

- **⏱️ Timeout** - Set time limits for operations
- **🔄 Retry** - Retry failed operations with various strategies  
- **🚦 Throttle/Debounce** - Control execution frequency
- **⚡ Parallel** - Run multiple operations concurrently with limits
- **❌ Cancellation** - Cancel running operations gracefully

## 🚀 Basic Usage

### 1. Timeout - Set Operation Time Limits

```dart
import 'package:async_toolkit/async_toolkit.dart';

// Simple timeout - throws exception if time limit exceeded
try {
  final result = await withTimeout(
    callSlowAPI(),
    Duration(seconds: 5),
  );
  print('Result: $result');
} on TimeoutException {
  print('API call took too long!');
}

// Timeout with default value - no exception thrown
final result = await withTimeoutOrDefault(
  callSlowAPI(),
  Duration(seconds: 5),
  'Default value on timeout',
);

// Timeout returns null instead of exception
final result = await withTimeoutOrNull(
  callSlowAPI(),
  Duration(seconds: 5),
);
if (result == null) {
  print('Timeout occurred');
}
```

### 2. Retry - Retry Failed Operations

```dart
// Simple retry with exponential backoff
final result = await withExponentialBackoff(
  () => callUnstableAPI(),
  maxAttempts: 3,
  baseDelay: Duration(milliseconds: 100), // 100ms, 200ms, 400ms
);

// Retry with fixed delay
final result = await withFixedDelay(
  () => callUnstableAPI(),
  maxAttempts: 5,
  delay: Duration(seconds: 1), // 1 second between each retry
);

// Retry with linear backoff  
final result = await withLinearBackoff(
  () => callUnstableAPI(),
  maxAttempts: 3,
  baseDelay: Duration(milliseconds: 100), // 100ms, 200ms, 300ms
);
```

### 3. Throttle - Limit Execution Frequency

```dart
// Simple throttle - execute only once per second
final result = await throttle(
  () => expensiveOperation(),
  Duration(seconds: 1),
);

// Use ThrottleManager for multiple calls
final manager = ThrottleManager<String>(Duration(seconds: 1));

// Multiple calls but only execute once, cache result
final result1 = await manager.throttle(() => expensiveOperation());
final result2 = await manager.throttle(() => expensiveOperation()); // Uses cache
final result3 = await manager.throttle(() => expensiveOperation()); // Uses cache

manager.dispose(); // Remember to dispose when done
```

### 4. Debounce - Delay Execution

```dart
// Simple debounce - execute only after 300ms of no calls
final result = await debounce(
  () => searchAPI(query),
  Duration(milliseconds: 300),
);

// Use DebounceManager for realtime search
final searchManager = DebounceManager<List<String>>(Duration(milliseconds: 300));

void onSearchChanged(String query) async {
  try {
    final results = await searchManager.debounce(() => searchAPI(query));
    updateUI(results);
  } catch (e) {
    print('Search error: $e');
  }
}

// Dispose when no longer needed
searchManager.dispose();
```

### 5. Parallel - Run Operations Concurrently

```dart
// Create list of tasks
final tasks = List.generate(10, (i) => 
  () => Future.delayed(Duration(seconds: 1), () => 'Task $i')
);

// Run max 3 tasks concurrently, results in order
final results = await runLimitedParallel(
  tasks,
  maxParallel: 3,
);
print(results); // ['Task 0', 'Task 1', ..., 'Task 9']

// Run concurrently, results in completion order
final results = await runLimitedParallelUnordered(
  tasks,
  maxParallel: 3,
);
```

### 6. Cancellation - Cancel Running Operations

```dart
// Create cancellation source
final source = CancellationTokenSource();

// Cancel after 5 seconds
Timer(Duration(seconds: 5), () => source.cancel());

try {
  final result = await longRunningTask(source.token);
  print('Completed: $result');
} on OperationCanceledException {
  print('Operation cancelled');
} finally {
  source.dispose(); // Remember to dispose
}

Future<String> longRunningTask(CancellationToken token) async {
  for (int i = 0; i < 10; i++) {
    // Check if cancelled
    token.throwIfCancellationRequested();
    
    await Future.delayed(Duration(seconds: 1));
    print('Step ${i + 1}/10');
  }
  return 'Done!';
}
```

## 📱 Real-world Examples

### Search with Debounce

```dart
class SearchController {
  final _debounceManager = DebounceManager<List<String>>(Duration(milliseconds: 300));
  
  void onTextChanged(String query) async {
    if (query.isEmpty) return;
    
    try {
      final results = await _debounceManager.debounce(() => searchAPI(query));
      updateSearchResults(results);
    } on OperationCanceledException {
      // Search cancelled by new search
    }
  }
  
  void dispose() => _debounceManager.dispose();
}
```

### API Call with Timeout and Retry

```dart
Future<Map<String, dynamic>> callAPI(String endpoint) async {
  return withTimeout(
    withExponentialBackoff(
      () => http.get(Uri.parse(endpoint)).then((response) {
        if (response.statusCode != 200) {
          throw HttpException('API error: ${response.statusCode}');
        }
        return jsonDecode(response.body);
      }),
      maxAttempts: 3,
      baseDelay: Duration(milliseconds: 100),
    ),
    Duration(seconds: 10),
  );
}
```

### Download Files Concurrently

```dart
Future<void> downloadFiles(List<String> urls) async {
  final downloadTasks = urls.map((url) => () => downloadFile(url)).toList();
  
  // Download max 3 files concurrently
  final results = await runLimitedParallel(
    downloadTasks,
    maxParallel: 3,
  );
  
  print('Downloaded ${results.length} files');
}
```

### Button Click with Throttle

```dart
class ButtonController {
  final _throttleManager = ThrottleManager<void>(Duration(seconds: 2));
  
  void onButtonPressed() async {
    try {
      await _throttleManager.throttle(() => submitForm());
      showSuccess('Form submitted!');
    } catch (e) {
      showError('Submit failed: $e');
    }
  }
  
  void dispose() => _throttleManager.dispose();
}
```

## 🔧 Advanced Features

### Composite Cancellation - Combine Multiple Cancellation Sources

**Composite Cancellation allows you to combine multiple cancellation sources into a single token. When ANY source is cancelled, the composite token is also cancelled.**

#### 🎯 Why Use Composite Cancellation?

In real applications, an operation can be cancelled for various reasons:
- **User cancellation** (Cancel button pressed)
- **Timeout** (operation takes too long)  
- **Network error** (connection lost)
- **App lifecycle** (app minimized)

Instead of checking each token separately, you only need to check one composite token.

```dart
// Create different token sources
final userCancelSource = CancellationTokenSource();
final timeoutSource = CancellationTokenSource.withTimeout(Duration(seconds: 30));
final networkSource = CancellationTokenSource();

// Create composite token - cancels when ANY token is cancelled
final compositeSource = CancellationTokenSource.any([
  userCancelSource.token,
  timeoutSource.token,
  networkSource.token,
]);

// User can cancel via button
onCancelButtonPressed() => userCancelSource.cancel();

// Network error can trigger cancel
onNetworkError() => networkSource.cancel();

try {
  final result = await longOperation(compositeSource.token);
  print('Operation completed: $result');
} on OperationCanceledException {
  if (timeoutSource.isCancellationRequested) {
    print('Operation timed out');
  } else if (userCancelSource.isCancellationRequested) {
    print('User cancelled operation');
  } else if (networkSource.isCancellationRequested) {
    print('Network error occurred');
  }
} finally {
  // Cleanup all resources
  userCancelSource.dispose();
  timeoutSource.dispose();
  networkSource.dispose();
  compositeSource.dispose();
}

// Example longOperation - a cancellable task
Future<String> longOperation(CancellationToken token) async {
  print('🚀 Starting long operation...');
  
  // Step 1: Connect to server
  print('📡 Connecting to server...');
  await Future.delayed(Duration(seconds: 2));
  token.throwIfCancellationRequested(); // Check if cancelled
  
  // Step 2: Authenticate
  print('🔐 Authenticating...');
  await Future.delayed(Duration(seconds: 3));
  token.throwIfCancellationRequested(); // Check again
  
  // Step 3: Load data
  print('📥 Loading data...');
  await Future.delayed(Duration(seconds: 5));
  token.throwIfCancellationRequested(); // Check again
  
  // Step 4: Process data
  print('🔄 Processing...');
  await Future.delayed(Duration(seconds: 2));
  token.throwIfCancellationRequested(); // Final check
  
  return 'Data processed successfully!';
}
```

#### 💡 Detailed Explanation:

**1. Why pass `compositeSource.token`?**
```dart
// compositeSource.token contains information from ALL token sources
final result = await longOperation(compositeSource.token);
```

**2. How is the token processed inside longOperation?**
```dart
Future<String> longOperation(CancellationToken token) async {
  // At each important checkpoint, check if cancelled
  token.throwIfCancellationRequested();
  
  // If ANY source (user, timeout, network) is cancelled
  // then token.throwIfCancellationRequested() throws OperationCanceledException
}
```

**3. Flow of operation:**
```
User presses Cancel → userCancelSource.cancel() 
                   ↓
                 compositeSource.token is cancelled
                   ↓  
                 longOperation checks token
                   ↓
                 Throws OperationCanceledException
                   ↓
                 Catch block handles and cleanup
```

**4. Real-world HTTP request example:**
```dart
Future<Map<String, dynamic>> fetchUserProfile(int userId, CancellationToken token) async {
  // Step 1: Validate input
  token.throwIfCancellationRequested();
  
  // Step 2: Make HTTP request  
  final response = await http.get(
    Uri.parse('https://api.example.com/users/$userId'),
    headers: {'Authorization': 'Bearer $token'},
  );
  token.throwIfCancellationRequested(); // Check after request
  
  // Step 3: Parse response
  if (response.statusCode != 200) {
    throw HttpException('Failed to fetch user: ${response.statusCode}');
  }
  token.throwIfCancellationRequested(); // Check before parsing
  
  // Step 4: Return parsed data
  return jsonDecode(response.body);
}
```

### Custom Retry Strategies

```dart
// Retry with detailed configuration
final result = await withRetryConfig(
  () => apiCall(),
  RetryConfig(
    maxAttempts: 5,
    backoff: (attempt) => Duration(milliseconds: 100 * attempt * attempt), // Quadratic backoff
    retryIf: (exception) => exception is SocketException, // Only retry network errors
    jitter: true, // Add randomness to avoid thundering herd
    maxDelay: Duration(seconds: 30), // Maximum delay limit
  ),
);
```

### Enhanced Cancellation Detection

```dart
// Clear distinction between cancellation and timeout
final reason = await token.whenCancelledOrTimeout(Duration(seconds: 30));
switch (reason) {
  case CancellationCompletionReason.cancelled:
    print('User cancelled operation');
    break;
  case CancellationCompletionReason.timeout:
    print('Operation timed out');
    break;
}
```

### Parallel with Callbacks

```dart
final tasks = List.generate(10, (i) => () => downloadFile('file$i.zip'));

await runLimitedParallelWithCallback(
  tasks,
  maxParallel: 3,
  onResult: (index, result) {
    print('File $index downloaded: $result');
    updateProgress(index + 1, tasks.length);
  },
  onError: (index, error) {
    print('File $index failed: $error');
  },
);
```

### Global Manager Control

```dart
// Use custom keys to avoid conflicts
final result1 = await throttle(
  () => operation1(),
  Duration(seconds: 1),
  key: 'operation1', // Custom key
);

final result2 = await throttle(
  () => operation2(),
  Duration(seconds: 1),
  key: 'operation2', // Different key
);

// Clean up all global managers (useful for testing)
clearGlobalManagers();
```

## 📋 API Reference

### Core Classes

| Class | Description |
|-------|-------------|
| `CancellationToken` | Token for cancelling operations |
| `CancellationTokenSource` | Creates and manages cancellation tokens |
| `ThrottleManager<T>` | Manages throttled operations |
| `DebounceManager<T>` | Manages debounced operations |
| `RetryConfig` | Configuration for retry strategies |

### Key Functions

| Function | Description |
|----------|-------------|
| `withTimeout<T>()` | Execute with timeout |
| `withTimeoutOrNull<T>()` | Timeout returns null |
| `withTimeoutOrDefault<T>()` | Timeout with default value |
| `withExponentialBackoff<T>()` | Retry with exponential backoff |
| `withLinearBackoff<T>()` | Retry with linear backoff |
| `withFixedDelay<T>()` | Retry with fixed delay |
| `runLimitedParallel<T>()` | Parallel with limit (ordered) |
| `runLimitedParallelUnordered<T>()` | Parallel with limit (unordered) |
| `throttle<T>()` | Global throttle function |
| `debounce<T>()` | Global debounce function |

### Enums

| Enum | Values | Description |
|------|--------|-------------|
| `CancellationCompletionReason` | `cancelled`, `timeout` | Completion reason |

## 📖 Examples and Testing

### Run Examples

```bash
# Comprehensive example showcasing all features
dart run example/example.dart

# Detailed throttle/debounce examples  
dart run example/throttle_debounce_example.dart
```

### Run Tests

```bash
dart test
```

**148 tests passing** ✅ with full coverage for all features.

## 🔄 Migration from Legacy APIs

```dart
// Old (still works but deprecated)
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

## 💡 Tips and Best Practices

### 1. Dispose Managers
```dart
// ✅ Always dispose managers when done
final manager = ThrottleManager<String>(Duration(seconds: 1));
// ... use manager
manager.dispose();
```

### 2. Error Handling
```dart
// ✅ Handle both timeout and cancellation
try {
  final result = await withTimeout(operation(), Duration(seconds: 5));
} on TimeoutException {
  // Handle timeout
} on OperationCanceledException {
  // Handle cancellation
}
```

### 3. Parallel Operations
```dart
// ✅ Use parallel for I/O operations
final futures = urls.map((url) => () => http.get(Uri.parse(url))).toList();
final responses = await runLimitedParallel(futures, maxParallel: 5);
```

### 4. Search Implementation
```dart
// ✅ Debounce for search, throttle for API calls
class SearchService {
  final _debounceManager = DebounceManager<List<String>>(Duration(milliseconds: 300));
  final _throttleManager = ThrottleManager<List<String>>(Duration(seconds: 1));
  
  // Debounce user input
  Future<List<String>> search(String query) => 
    _debounceManager.debounce(() => _performSearch(query));
    
  // Throttle expensive operations  
  Future<List<String>> getSuggestions() =>
    _throttleManager.throttle(() => _fetchSuggestions());
}
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add some amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Create Pull Request

## 📞 Support

- **GitHub Issues**: [Report bugs or request features](https://github.com/duymainek/async_toolkit/issues)
- **Pub.dev**: [Package page](https://pub.dev/packages/async_toolkit)
- **Documentation**: [API documentation](https://pub.dev/documentation/async_toolkit/latest/)

## 📄 License

MIT License - see [LICENSE](LICENSE) file.

---

**Made with ❤️ for the Dart/Flutter community**