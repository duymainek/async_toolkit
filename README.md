# Async Toolkit

[![Pub Version](https://img.shields.io/pub/v/async_toolkit.svg)](https://pub.dev/packages/async_toolkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Stars](https://img.shields.io/github/stars/duymainek/async_toolkit.svg)](https://github.com/duymainek/async_toolkit)

Một package Dart mạnh mẽ cung cấp các tiện ích cho lập trình bất đồng bộ: timeout, retry, throttle/debounce, parallel execution và cancellation tokens.

## 📦 Cài đặt

```yaml
dependencies:
  async_toolkit: ^1.0.0
```

```bash
dart pub get
```

## 🎯 Các tính năng chính

- **⏱️ Timeout** - Đặt thời gian chờ cho operations
- **🔄 Retry** - Thử lại khi operation thất bại  
- **🚦 Throttle/Debounce** - Kiểm soát tần suất thực thi
- **⚡ Parallel** - Chạy nhiều operations song song với giới hạn
- **❌ Cancellation** - Hủy operations đang chạy

## 🚀 Sử dụng cơ bản

### 1. Timeout - Đặt thời gian chờ

```dart
import 'package:async_toolkit/async_toolkit.dart';

// Timeout đơn giản - ném exception nếu quá thời gian
try {
  final result = await withTimeout(
    callSlowAPI(),
    Duration(seconds: 5),
  );
  print('Kết quả: $result');
} on TimeoutException {
  print('API call quá lâu!');
}

// Timeout với giá trị mặc định - không ném exception
final result = await withTimeoutOrDefault(
  callSlowAPI(),
  Duration(seconds: 5),
  'Mặc định khi timeout',
);

// Timeout trả về null thay vì exception
final result = await withTimeoutOrNull(
  callSlowAPI(),
  Duration(seconds: 5),
);
if (result == null) {
  print('Timeout xảy ra');
}
```

### 2. Retry - Thử lại khi thất bại

```dart
// Retry đơn giản với exponential backoff
final result = await withExponentialBackoff(
  () => callUnstableAPI(),
  maxAttempts: 3,
  baseDelay: Duration(milliseconds: 100), // 100ms, 200ms, 400ms
);

// Retry với fixed delay
final result = await withFixedDelay(
  () => callUnstableAPI(),
  maxAttempts: 5,
  delay: Duration(seconds: 1), // Mỗi lần retry cách nhau 1 giây
);

// Retry với linear backoff  
final result = await withLinearBackoff(
  () => callUnstableAPI(),
  maxAttempts: 3,
  baseDelay: Duration(milliseconds: 100), // 100ms, 200ms, 300ms
);
```

### 3. Throttle - Giới hạn tần suất thực thi

```dart
// Throttle đơn giản - chỉ thực thi 1 lần trong 1 giây
final result = await throttle(
  () => expensiveOperation(),
  Duration(seconds: 1),
);

// Sử dụng ThrottleManager cho nhiều lần gọi
final manager = ThrottleManager<String>(Duration(seconds: 1));

// Gọi nhiều lần nhưng chỉ thực thi 1 lần, cache kết quả
final result1 = await manager.throttle(() => expensiveOperation());
final result2 = await manager.throttle(() => expensiveOperation()); // Dùng cache
final result3 = await manager.throttle(() => expensiveOperation()); // Dùng cache

manager.dispose(); // Nhớ dispose khi xong
```

### 4. Debounce - Trì hoãn thực thi

```dart
// Debounce đơn giản - chỉ thực thi sau khi ngừng gọi 300ms
final result = await debounce(
  () => searchAPI(query),
  Duration(milliseconds: 300),
);

// Sử dụng DebounceManager cho search realtime
final searchManager = DebounceManager<List<String>>(Duration(milliseconds: 300));

void onSearchChanged(String query) async {
  try {
    final results = await searchManager.debounce(() => searchAPI(query));
    updateUI(results);
  } catch (e) {
    print('Search error: $e');
  }
}

// Dispose khi không dùng nữa
searchManager.dispose();
```

### 5. Parallel - Chạy song song với giới hạn

```dart
// Tạo danh sách các tasks
final tasks = List.generate(10, (i) => 
  () => Future.delayed(Duration(seconds: 1), () => 'Task $i')
);

// Chạy tối đa 3 tasks cùng lúc, kết quả theo thứ tự
final results = await runLimitedParallel(
  tasks,
  maxParallel: 3,
);
print(results); // ['Task 0', 'Task 1', ..., 'Task 9']

// Chạy song song, kết quả theo thứ tự hoàn thành
final results = await runLimitedParallelUnordered(
  tasks,
  maxParallel: 3,
);
```

### 6. Cancellation - Hủy operations

```dart
// Tạo cancellation source
final source = CancellationTokenSource();

// Hủy sau 5 giây
Timer(Duration(seconds: 5), () => source.cancel());

try {
  final result = await longRunningTask(source.token);
  print('Hoàn thành: $result');
} on OperationCanceledException {
  print('Đã bị hủy');
} finally {
  source.dispose(); // Nhớ dispose
}

Future<String> longRunningTask(CancellationToken token) async {
  for (int i = 0; i < 10; i++) {
    // Kiểm tra có bị hủy không
    token.throwIfCancellationRequested();
    
    await Future.delayed(Duration(seconds: 1));
    print('Bước ${i + 1}/10');
  }
  return 'Xong!';
}
```

## 📱 Ví dụ thực tế

### Search với Debounce

```dart
class SearchController {
  final _debounceManager = DebounceManager<List<String>>(Duration(milliseconds: 300));
  
  void onTextChanged(String query) async {
    if (query.isEmpty) return;
    
    try {
      final results = await _debounceManager.debounce(() => searchAPI(query));
      updateSearchResults(results);
    } on OperationCanceledException {
      // Search bị hủy bởi search mới
    }
  }
  
  void dispose() => _debounceManager.dispose();
}
```

### API Call với Timeout và Retry

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

### Download files song song

```dart
Future<void> downloadFiles(List<String> urls) async {
  final downloadTasks = urls.map((url) => () => downloadFile(url)).toList();
  
  // Download tối đa 3 files cùng lúc
  final results = await runLimitedParallel(
    downloadTasks,
    maxParallel: 3,
  );
  
  print('Downloaded ${results.length} files');
}
```

### Button click với Throttle

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

### Composite Cancellation - Kết hợp nhiều nguồn hủy

**Composite Cancellation cho phép bạn kết hợp nhiều nguồn hủy khác nhau thành một token duy nhất. Khi BẤT KỲ nguồn nào bị hủy, composite token cũng sẽ bị hủy.**

#### 🎯 Tại sao cần Composite Cancellation?

Trong thực tế, một operation có thể bị hủy vì nhiều lý do:
- **User hủy** (nhấn nút Cancel)
- **Timeout** (quá thời gian cho phép)  
- **Network error** (mất kết nối)
- **App lifecycle** (app bị minimize)

Thay vì phải check từng token riêng biệt, bạn chỉ cần check một composite token duy nhất.

```dart
// Tạo các token sources khác nhau
final userCancelSource = CancellationTokenSource();
final timeoutSource = CancellationTokenSource.withTimeout(Duration(seconds: 30));
final networkSource = CancellationTokenSource();

// Tạo composite token - hủy khi BẤT KỲ token nào bị hủy
final compositeSource = CancellationTokenSource.any([
  userCancelSource.token,
  timeoutSource.token,
  networkSource.token,
]);

// User có thể hủy bằng button
onCancelButtonPressed() => userCancelSource.cancel();

// Network error có thể trigger cancel
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
  // Cleanup tất cả resources
  userCancelSource.dispose();
  timeoutSource.dispose();
  networkSource.dispose();
  compositeSource.dispose();
}

// Ví dụ longOperation - một tác vụ có thể bị hủy
Future<String> longOperation(CancellationToken token) async {
  print('🚀 Bắt đầu long operation...');
  
  // Bước 1: Kết nối server
  print('📡 Đang kết nối server...');
  await Future.delayed(Duration(seconds: 2));
  token.throwIfCancellationRequested(); // Kiểm tra có bị hủy không
  
  // Bước 2: Xác thực
  print('🔐 Đang xác thực...');
  await Future.delayed(Duration(seconds: 3));
  token.throwIfCancellationRequested(); // Kiểm tra lại
  
  // Bước 3: Tải dữ liệu
  print('📥 Đang tải dữ liệu...');
  await Future.delayed(Duration(seconds: 5));
  token.throwIfCancellationRequested(); // Kiểm tra lại
  
  // Bước 4: Xử lý dữ liệu
  print('🔄 Đang xử lý...');
  await Future.delayed(Duration(seconds: 2));
  token.throwIfCancellationRequested(); // Kiểm tra cuối cùng
  
  return 'Dữ liệu đã xử lý thành công!';
}
```

#### 💡 Giải thích chi tiết:

**1. Tại sao truyền `compositeSource.token`?**
```dart
// compositeSource.token chứa thông tin từ TẤT CẢ các token sources
final result = await longOperation(compositeSource.token);
```

**2. Bên trong longOperation, token được xử lý như thế nào?**
```dart
Future<String> longOperation(CancellationToken token) async {
  // Tại mỗi checkpoint quan trọng, check xem có bị hủy không
  token.throwIfCancellationRequested();
  
  // Nếu BẤT KỲ source nào (user, timeout, network) bị hủy
  // thì token.throwIfCancellationRequested() sẽ ném OperationCanceledException
}
```

**3. Flow hoạt động:**
```
User nhấn Cancel → userCancelSource.cancel() 
                ↓
              compositeSource.token bị cancel
                ↓  
              longOperation check token
                ↓
              Ném OperationCanceledException
                ↓
              Catch block xử lý và cleanup
```

**4. Ví dụ thực tế với HTTP request:**
```dart
Future<Map<String, dynamic>> fetchUserProfile(int userId, CancellationToken token) async {
  // Step 1: Validate input
  token.throwIfCancellationRequested();
  
  // Step 2: Make HTTP request  
  final response = await http.get(
    Uri.parse('https://api.example.com/users/$userId'),
    headers: {'Authorization': 'Bearer $token'},
  );
  token.throwIfCancellationRequested(); // Check sau khi request
  
  // Step 3: Parse response
  if (response.statusCode != 200) {
    throw HttpException('Failed to fetch user: ${response.statusCode}');
  }
  token.throwIfCancellationRequested(); // Check trước khi parse
  
  // Step 4: Return parsed data
  return jsonDecode(response.body);
}
```

### Custom Retry Strategies - Chiến lược retry tùy chỉnh

```dart
// Retry với config chi tiết
final result = await withRetryConfig(
  () => apiCall(),
  RetryConfig(
    maxAttempts: 5,
    backoff: (attempt) => Duration(milliseconds: 100 * attempt * attempt), // Quadratic backoff
    retryIf: (exception) => exception is SocketException, // Chỉ retry lỗi network
    jitter: true, // Thêm random để tránh thundering herd
    maxDelay: Duration(seconds: 30), // Giới hạn delay tối đa
  ),
);
```

### Enhanced Cancellation Detection - Phân biệt cancel và timeout

```dart
// Phân biệt rõ ràng giữa cancel và timeout
final reason = await token.whenCancelledOrTimeout(Duration(seconds: 30));
switch (reason) {
  case CancellationCompletionReason.cancelled:
    print('User đã hủy operation');
    break;
  case CancellationCompletionReason.timeout:
    print('Operation bị timeout');
    break;
}
```

### Parallel với Callback - Xử lý kết quả ngay khi có

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

### Global Manager Control - Quản lý global managers

```dart
// Sử dụng custom key để tránh xung đột
final result1 = await throttle(
  () => operation1(),
  Duration(seconds: 1),
  key: 'operation1', // Key tùy chỉnh
);

final result2 = await throttle(
  () => operation2(),
  Duration(seconds: 1),
  key: 'operation2', // Key khác
);

// Dọn dẹp tất cả global managers (hữu ích cho testing)
clearGlobalManagers();
```

## 📋 API Reference

### Core Classes

| Class | Mô tả |
|-------|-------|
| `CancellationToken` | Token để hủy operations |
| `CancellationTokenSource` | Tạo và quản lý cancellation tokens |
| `ThrottleManager<T>` | Quản lý throttled operations |
| `DebounceManager<T>` | Quản lý debounced operations |
| `RetryConfig` | Cấu hình cho retry strategies |

### Key Functions

| Function | Mô tả |
|----------|-------|
| `withTimeout<T>()` | Thực thi với timeout |
| `withTimeoutOrNull<T>()` | Timeout trả về null |
| `withTimeoutOrDefault<T>()` | Timeout với giá trị mặc định |
| `withExponentialBackoff<T>()` | Retry với exponential backoff |
| `withLinearBackoff<T>()` | Retry với linear backoff |
| `withFixedDelay<T>()` | Retry với fixed delay |
| `runLimitedParallel<T>()` | Parallel với giới hạn (ordered) |
| `runLimitedParallelUnordered<T>()` | Parallel với giới hạn (unordered) |
| `throttle<T>()` | Global throttle function |
| `debounce<T>()` | Global debounce function |

### Enums

| Enum | Values | Mô tả |
|------|--------|-------|
| `CancellationCompletionReason` | `cancelled`, `timeout` | Lý do completion |

## 📖 Examples và Testing

### Chạy examples

```bash
# Example tổng hợp tất cả features
dart run example/example.dart

# Example chi tiết về throttle/debounce  
dart run example/throttle_debounce_example.dart
```

### Chạy tests

```bash
dart test
```

**148 tests passing** ✅ với coverage đầy đủ cho tất cả features.

## 🔄 Migration từ APIs cũ

```dart
// Cũ (vẫn hoạt động nhưng deprecated)
try {
  await token.whenCancelledOrTimeoutLegacy(duration);
} on TimeoutException {
  // Xử lý timeout
}

// Mới (khuyên dùng)
final reason = await token.whenCancelledOrTimeout(duration);
switch (reason) {
  case CancellationCompletionReason.cancelled:
    // Xử lý cancellation
  case CancellationCompletionReason.timeout:  
    // Xử lý timeout
}
```

## 💡 Tips và Best Practices

### 1. Dispose Managers
```dart
// ✅ Luôn dispose managers khi không dùng nữa
final manager = ThrottleManager<String>(Duration(seconds: 1));
// ... sử dụng manager
manager.dispose();
```

### 2. Error Handling
```dart
// ✅ Handle cả timeout và cancellation
try {
  final result = await withTimeout(operation(), Duration(seconds: 5));
} on TimeoutException {
  // Xử lý timeout
} on OperationCanceledException {
  // Xử lý cancellation
}
```

### 3. Parallel Operations
```dart
// ✅ Sử dụng parallel cho I/O operations
final futures = urls.map((url) => () => http.get(Uri.parse(url))).toList();
final responses = await runLimitedParallel(futures, maxParallel: 5);
```

### 4. Search Implementation
```dart
// ✅ Debounce cho search, throttle cho API calls
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

Contributions are welcome! Vui lòng:

1. Fork repository
2. Tạo feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add some amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Tạo Pull Request

## 📞 Support

- **GitHub Issues**: [Report bugs hoặc request features](https://github.com/duymainek/async_toolkit/issues)
- **Pub.dev**: [Package page](https://pub.dev/packages/async_toolkit)
- **Documentation**: [API documentation](https://pub.dev/documentation/async_toolkit/latest/)

## 📄 License

MIT License - xem [LICENSE](LICENSE) file.

---

**Made with ❤️ for the Dart/Flutter community**