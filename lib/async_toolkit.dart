/// A powerful Dart/Flutter package providing advanced asynchronous utilities.
///
/// This package provides utilities for:
/// - Cancellation tokens for graceful operation cancellation
/// - Timeout control for async operations
/// - Retry logic with configurable backoff strategies
/// - Parallel execution with concurrency limits
/// - Throttle and debounce for controlling function execution frequency
///
/// ## Getting Started
///
/// ```dart
/// import 'package:async_toolkit/async_toolkit.dart';
///
/// // Use cancellation tokens
/// final source = CancellationTokenSource();
/// final token = source.token;
///
/// // Set timeouts
/// final result = await withTimeout(
///   someAsyncOperation(),
///   Duration(seconds: 10),
/// );
///
/// // Retry with exponential backoff
/// final result = await withExponentialBackoff(
///   () => unreliableOperation(),
///   maxAttempts: 3,
/// );
///
/// // Run operations in parallel with limits
/// final results = await runLimitedParallel(
///   [operation1(), operation2(), operation3()],
///   maxParallel: 2,
/// );
///
/// // Throttle function execution
/// final result = await throttle(
///   () => expensiveOperation(),
///   Duration(milliseconds: 500),
/// );
///
/// // Debounce function execution
/// final result = await debounce(
///   () => searchOperation(),
///   Duration(milliseconds: 300),
/// );
/// ```
library async_toolkit;

// Export cancellation utilities
export 'src/cancellation/cancellation_token.dart';
export 'src/cancellation/cancellation_token_source.dart';

// Export utility functions
export 'src/utils/timeout.dart';
export 'src/utils/retry.dart';
export 'src/utils/parallel.dart';
export 'src/utils/throttle_debounce.dart';
