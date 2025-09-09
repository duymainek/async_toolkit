import 'dart:async';
import 'package:async_toolkit/async_toolkit.dart';

void main() async {
  print('🚀 Async Toolkit - Comprehensive Examples\n');

  // Core Features
  print('📋 CORE FEATURES:');

  // Example 1: Cancellation Tokens với API calls
  await cancellationExample();

  // Example 2: Real-world API example
  await realWorldAPIExample();

  // Example 3: Enhanced Cancellation Completion
  await enhancedCancellationExample();

  // Example 4: Timeout Control
  await timeoutExample();

  // Example 5: Retry Logic với Cancellation
  await retryExample();

  // Example 6: Parallel Execution
  await parallelExample();

  // Example 7: Throttle & Debounce Basic Usage
  await throttleDebounceBasicExample();

  print('\n🎯 All examples completed successfully!');
  print(
      '📚 For more detailed throttle/debounce examples, run: dart run example/throttle_debounce_example.dart');
}

/// Example demonstrating cancellation tokens with API calls
Future<void> cancellationExample() async {
  print('=== Cancellation Example - API Calls ===');

  // Tạo cancellation token source
  final source = CancellationTokenSource();
  final token = source.token;

  print('🚀 Bắt đầu gọi API...');

  // Simulate API call with progress updates
  final apiCall = _simulateAPICall(token);

  // Cancel after 3 seconds (simulate user cancelling)
  Timer(Duration(seconds: 3), () {
    print('❌ User đã hủy tác vụ!');
    source.cancel();
  });

  try {
    final result = await apiCall;
    print('✅ API call thành công: $result');
  } on OperationCanceledException {
    print('⚠️  API call đã bị hủy bởi user');
  } catch (e) {
    print('❌ Lỗi API: $e');
  } finally {
    source.dispose();
  }

  print('');
}

/// Simulate a real API call with progress updates
Future<String> _simulateAPICall(CancellationToken token) async {
  print('📡 Đang kết nối đến server...');
  await Future.delayed(Duration(milliseconds: 500));

  // Check for cancellation
  token.throwIfCancellationRequested();

  print('🔐 Đang xác thực...');
  await Future.delayed(Duration(milliseconds: 800));

  // Check for cancellation
  token.throwIfCancellationRequested();

  print('📥 Đang tải dữ liệu...');
  await Future.delayed(Duration(milliseconds: 1000));

  // Check for cancellation
  token.throwIfCancellationRequested();

  print('🔄 Đang xử lý dữ liệu...');
  await Future.delayed(Duration(milliseconds: 700));

  // Check for cancellation
  token.throwIfCancellationRequested();

  print('✅ Hoàn thành!');
  return 'Dữ liệu từ API: {users: 150, orders: 300}';
}

/// Real-world API example with cancellation
Future<void> realWorldAPIExample() async {
  print('=== Real-world API Example ===');

  // Tạo token source cho toàn bộ quá trình
  final tokenSource = CancellationTokenSource();
  final token = tokenSource.token;

  try {
    print('🔄 Bắt đầu tải dữ liệu người dùng...');

    // Simulate multiple API calls
    final userData = await _fetchUserData(token);
    print('👤 User data: $userData');

    final userPosts = await _fetchUserPosts(userData['id'], token);
    print('📝 User posts: ${userPosts.length} posts');

    final userFriends = await _fetchUserFriends(userData['id'], token);
    print('👥 User friends: ${userFriends.length} friends');

    print('✅ Hoàn thành tải tất cả dữ liệu!');
  } on OperationCanceledException {
    print('⚠️  Tác vụ bị hủy - dữ liệu đã tải một phần');
  } catch (e) {
    print('❌ Lỗi: $e');
  } finally {
    tokenSource.dispose();
  }

  print('');
}

/// Simulate fetching user data
Future<Map<String, dynamic>> _fetchUserData(CancellationToken token) async {
  print('  📡 Đang tải thông tin user...');
  await Future.delayed(Duration(milliseconds: 1200));

  token.throwIfCancellationRequested();

  return {
    'id': 123,
    'name': 'Nguyễn Văn A',
    'email': 'nguyenvana@example.com',
    'avatar': 'https://example.com/avatar.jpg'
  };
}

/// Simulate fetching user posts
Future<List<Map<String, dynamic>>> _fetchUserPosts(
    int userId, CancellationToken token) async {
  print('  📝 Đang tải bài viết của user $userId...');
  await Future.delayed(Duration(milliseconds: 800));

  token.throwIfCancellationRequested();

  return [
    {'id': 1, 'title': 'Bài viết 1', 'content': 'Nội dung bài viết 1'},
    {'id': 2, 'title': 'Bài viết 2', 'content': 'Nội dung bài viết 2'},
    {'id': 3, 'title': 'Bài viết 3', 'content': 'Nội dung bài viết 3'},
  ];
}

/// Simulate fetching user friends
Future<List<Map<String, dynamic>>> _fetchUserFriends(
    int userId, CancellationToken token) async {
  print('  👥 Đang tải danh sách bạn bè của user $userId...');
  await Future.delayed(Duration(milliseconds: 600));

  token.throwIfCancellationRequested();

  return [
    {'id': 456, 'name': 'Trần Thị B', 'status': 'online'},
    {'id': 789, 'name': 'Lê Văn C', 'status': 'offline'},
    {'id': 101, 'name': 'Phạm Thị D', 'status': 'online'},
  ];
}

/// Example demonstrating timeout control
Future<void> timeoutExample() async {
  print('=== Timeout Example ===');

  // Example 1: Successful operation
  try {
    final result = await withTimeout(
      Future.delayed(Duration(milliseconds: 100), () => 'Quick operation'),
      Duration(seconds: 1),
    );
    print('Quick operation result: $result');
  } on TimeoutException {
    print('Quick operation timed out');
  }

  // Example 2: Operation that times out
  try {
    await withTimeout(
      Future.delayed(Duration(seconds: 2), () => 'Slow operation'),
      Duration(milliseconds: 500),
    );
  } on TimeoutException {
    print('Slow operation timed out (as expected)');
  }

  // Example 3: Timeout with default value
  final result = await withTimeoutOrDefault(
    Future.delayed(Duration(seconds: 2), () => 'Slow operation'),
    Duration(milliseconds: 500),
    'Default value',
  );
  print('Timeout with default: $result');

  print('');
}

/// Example demonstrating retry logic
Future<void> retryExample() async {
  print('=== Retry Example ===');

  var attemptCount = 0;

  try {
    final result = await withRetry(
      () async {
        attemptCount++;
        print('Attempt $attemptCount');

        if (attemptCount < 3) {
          throw Exception('Temporary failure');
        }

        return 'Success after $attemptCount attempts';
      },
      maxAttempts: 3,
      backoff: (attempt) => Duration(milliseconds: 100 * attempt),
    );

    print('Retry result: $result');
  } catch (e) {
    print('Retry failed: $e');
  }

  // Example with exponential backoff
  attemptCount = 0;

  try {
    final result = await withExponentialBackoff(
      () async {
        attemptCount++;
        print('Exponential backoff attempt $attemptCount');

        if (attemptCount < 4) {
          throw Exception('Temporary failure');
        }

        return 'Success after $attemptCount attempts';
      },
      maxAttempts: 4,
      baseDelay: Duration(milliseconds: 50),
      multiplier: 2.0,
    );

    print('Exponential backoff result: $result');
  } catch (e) {
    print('Exponential backoff failed: $e');
  }

  print('');
}

/// Example demonstrating parallel execution
Future<void> parallelExample() async {
  print('=== Parallel Execution Example ===');

  // Create some async operations
  final operations = List.generate(10, (index) {
    return Future.delayed(
      Duration(milliseconds: 100 + (index * 50)),
      () => 'Operation $index completed',
    );
  });

  print('Running 10 operations with max 3 concurrent...');
  final stopwatch = Stopwatch()..start();

  final results = await runLimitedParallel(
    operations,
    maxParallel: 3,
  );

  stopwatch.stop();

  print(
      'Completed ${results.length} operations in ${stopwatch.elapsedMilliseconds}ms');
  print('Results: ${results.take(3).join(', ')}...');

  // Example with unordered results
  print('\nRunning with unordered results...');
  final stopwatch2 = Stopwatch()..start();

  final unorderedResults = await runLimitedParallelUnordered(
    operations,
    maxParallel: 3,
  );

  stopwatch2.stop();

  print(
      'Completed ${unorderedResults.length} operations in ${stopwatch2.elapsedMilliseconds}ms');
  print('First few results: ${unorderedResults.take(3).join(', ')}...');

  // Example with callback
  print('\nRunning with callback...');
  final resultsList = <String>[];

  await runLimitedParallelWithCallback(
    operations,
    (result) {
      resultsList.add(result);
      print('Received: $result');
    },
    maxParallel: 2,
  );

  print('Total results received: ${resultsList.length}');

  print('');
}

/// Example demonstrating enhanced cancellation completion detection
Future<void> enhancedCancellationExample() async {
  print('=== Enhanced Cancellation Completion ===');

  print('🔍 Testing new whenCancelledOrTimeout with completion reason...');

  // Test 1: Timeout scenario
  final source1 = CancellationTokenSource();

  print('⏱️  Testing timeout scenario (100ms timeout)...');
  final stopwatch1 = Stopwatch()..start();
  final reason1 =
      await source1.token.whenCancelledOrTimeout(Duration(milliseconds: 100));
  stopwatch1.stop();

  print('   Completion reason: $reason1');
  print('   Time elapsed: ${stopwatch1.elapsedMilliseconds}ms');
  print('   ✅ Clear timeout indication');

  source1.dispose();

  // Test 2: Cancellation scenario
  final source2 = CancellationTokenSource();

  print('\n🚫 Testing cancellation scenario...');
  Timer(Duration(milliseconds: 50), () {
    print('   Requesting cancellation...');
    source2.cancel();
  });

  final stopwatch2 = Stopwatch()..start();
  final reason2 =
      await source2.token.whenCancelledOrTimeout(Duration(milliseconds: 200));
  stopwatch2.stop();

  print('   Completion reason: $reason2');
  print('   Time elapsed: ${stopwatch2.elapsedMilliseconds}ms');
  print('   ✅ Clear cancellation indication');

  source2.dispose();

  // Test 3: Composite token example
  print('\n🔗 Testing composite cancellation token...');
  final sourceA = CancellationTokenSource();
  final sourceB = CancellationTokenSource();
  final sourceC = CancellationTokenSource();

  final compositeSource = CancellationTokenSource.any([
    sourceA.token,
    sourceB.token,
    sourceC.token,
  ]);

  // Cancel one of the source tokens
  Timer(Duration(milliseconds: 30), () {
    print('   Cancelling source B...');
    sourceB.cancel();
  });

  try {
    await compositeSource.token.whenCancelled();
    print('   ✅ Composite token cancelled when any source token cancelled');
  } catch (e) {
    print('   ❌ Composite token error: $e');
  } finally {
    sourceA.dispose();
    sourceB.dispose();
    sourceC.dispose();
    compositeSource.dispose();
  }

  print('');
}

/// Example demonstrating basic throttle and debounce usage
Future<void> throttleDebounceBasicExample() async {
  print('=== Throttle & Debounce Basic Usage ===');

  // Throttle example
  print('🚦 Throttle Example:');
  var throttleCallCount = 0;

  Future<String> expensiveOperation() async {
    throttleCallCount++;
    await Future.delayed(Duration(milliseconds: 50));
    return 'Expensive result $throttleCallCount';
  }

  final throttleManager = ThrottleManager<String>(Duration(milliseconds: 200));

  try {
    // Rapid calls - only first executes, others return cached result
    final result1 = await throttleManager.throttle(expensiveOperation);
    final result2 = await throttleManager.throttle(expensiveOperation);
    final result3 = await throttleManager.throttle(expensiveOperation);

    print('   First call: $result1');
    print('   Second call: $result2 (cached)');
    print('   Third call: $result3 (cached)');
    print('   Total executions: $throttleCallCount');
  } finally {
    throttleManager.dispose();
  }

  // Debounce example
  print('\n⏳ Debounce Example:');
  var debounceCallCount = 0;

  Future<String> searchOperation() async {
    debounceCallCount++;
    await Future.delayed(Duration(milliseconds: 50));
    return 'Search result $debounceCallCount';
  }

  final debounceManager = DebounceManager<String>(Duration(milliseconds: 150));

  try {
    // Rapid calls - only last one executes
    final future1 = debounceManager
        .debounce(searchOperation)
        .catchError((e) => 'Cancelled');
    await Future.delayed(Duration(milliseconds: 50));

    final future2 = debounceManager
        .debounce(searchOperation)
        .catchError((e) => 'Cancelled');
    await Future.delayed(Duration(milliseconds: 50));

    final future3 =
        debounceManager.debounce(searchOperation); // This one executes

    final results = await Future.wait([future1, future2, future3]);
    print('   Results: $results');
    print('   Total executions: $debounceCallCount');
  } finally {
    debounceManager.dispose();
  }

  // Global functions example
  print('\n🌐 Global Functions Example:');

  var globalCallCount = 0;
  Future<String> globalOperation() async {
    globalCallCount++;
    return 'Global result $globalCallCount';
  }

  // Using global throttle function
  final throttleResult1 =
      await throttle(globalOperation, Duration(milliseconds: 100));
  final throttleResult2 =
      await throttle(globalOperation, Duration(milliseconds: 100));

  print('   Global throttle results: $throttleResult1, $throttleResult2');
  print('   Global executions: $globalCallCount');

  // Clean up global managers
  clearGlobalManagers();

  print('');
}
