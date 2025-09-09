import 'dart:async';
import 'dart:math';
import '../cancellation/cancellation_token.dart';

/// Retry configuration for retry operations.
class RetryConfig {
  /// Maximum number of retry attempts (including the initial attempt).
  final int maxAttempts;

  /// Function to calculate delay between retries.
  final Duration Function(int attempt)? backoff;

  /// Function to determine if an exception should trigger a retry.
  final bool Function(Object error)? shouldRetry;

  /// Maximum delay between retries.
  final Duration? maxDelay;

  /// Jitter factor to add randomness to delays (0.0 to 1.0).
  final double jitter;

  RetryConfig({
    required this.maxAttempts,
    this.backoff,
    this.shouldRetry,
    this.maxDelay,
    this.jitter = 0.1,
  }) {
    if (maxAttempts < 1) {
      throw ArgumentError('maxAttempts must be at least 1, got $maxAttempts');
    }
    if (jitter < 0.0 || jitter > 1.0) {
      throw ArgumentError('jitter must be between 0.0 and 1.0, got $jitter');
    }
  }

  /// Creates a retry config with exponential backoff.
  factory RetryConfig.exponential({
    required int maxAttempts,
    Duration baseDelay = const Duration(milliseconds: 100),
    double multiplier = 2.0,
    Duration? maxDelay,
    double jitter = 0.1,
    bool Function(Object error)? shouldRetry,
  }) {
    return RetryConfig(
      maxAttempts: maxAttempts,
      backoff: (attempt) {
        final delay = Duration(
          milliseconds:
              (baseDelay.inMilliseconds * pow(multiplier, attempt - 1).round())
                  .round(),
        );
        return maxDelay != null && delay > maxDelay ? maxDelay : delay;
      },
      shouldRetry: shouldRetry,
      maxDelay: maxDelay,
      jitter: jitter,
    );
  }

  /// Creates a retry config with linear backoff.
  factory RetryConfig.linear({
    required int maxAttempts,
    Duration baseDelay = const Duration(milliseconds: 100),
    Duration? maxDelay,
    double jitter = 0.1,
    bool Function(Object error)? shouldRetry,
  }) {
    return RetryConfig(
      maxAttempts: maxAttempts,
      backoff: (attempt) {
        final delay = Duration(
            milliseconds: (baseDelay.inMilliseconds * attempt).round());
        return maxDelay != null && delay > maxDelay ? maxDelay : delay;
      },
      shouldRetry: shouldRetry,
      maxDelay: maxDelay,
      jitter: jitter,
    );
  }

  /// Creates a retry config with fixed delay.
  factory RetryConfig.fixed({
    required int maxAttempts,
    Duration delay = const Duration(milliseconds: 100),
    double jitter = 0.1,
    bool Function(Object error)? shouldRetry,
  }) {
    return RetryConfig(
      maxAttempts: maxAttempts,
      backoff: (_) => delay,
      shouldRetry: shouldRetry,
      jitter: jitter,
    );
  }
}

/// Retries an operation with configurable retry logic.
///
/// The operation will be retried up to [maxAttempts] times if it throws an exception.
/// If all attempts fail, the last exception is re-thrown.
///
/// The cancellation token, if provided, allows cancelling the retry operation
/// at any time, including during the delay between attempts.
///
/// [operation] - The async operation to retry
/// [maxAttempts] - Maximum number of attempts (including the initial attempt)
/// [backoff] - Function to calculate delay between retries
/// [shouldRetry] - Function to determine if an exception should trigger a retry
/// [maxDelay] - Maximum delay between retries
/// [jitter] - Jitter factor to add randomness to delays (0.0 to 1.0)
/// [token] - Optional cancellation token for cancelling retry operation
Future<T> withRetry<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration Function(int attempt)? backoff,
  bool Function(Object error)? shouldRetry,
  Duration? maxDelay,
  double jitter = 0.1,
  CancellationToken? token,
}) async {
  // Validate jitter parameter
  if (jitter < 0.0 || jitter > 1.0) {
    throw ArgumentError('jitter must be between 0.0 and 1.0, got $jitter');
  }

  return withRetryConfig(
    operation,
    RetryConfig(
      maxAttempts: maxAttempts,
      backoff: backoff,
      shouldRetry: shouldRetry,
      maxDelay: maxDelay,
      jitter: jitter,
    ),
    token: token,
  );
}

/// Retries an operation using a [RetryConfig].
///
/// The cancellation token, if provided, allows cancelling the retry operation
/// at any time, including during the delay between attempts.
Future<T> withRetryConfig<T>(
  Future<T> Function() operation,
  RetryConfig config, {
  CancellationToken? token,
}) async {
  if (config.maxAttempts < 1) {
    throw ArgumentError('maxAttempts must be at least 1');
  }

  for (int attempt = 1; attempt <= config.maxAttempts; attempt++) {
    // Check for cancellation before each attempt
    token?.throwIfCancellationRequested();

    try {
      return await operation();
    } catch (error) {
      // Check if we should retry this error
      if (config.shouldRetry != null && !config.shouldRetry!(error)) {
        rethrow;
      }

      // If this was the last attempt, rethrow the exception
      if (attempt >= config.maxAttempts) {
        rethrow;
      }

      // Calculate delay for next attempt
      Duration delay = Duration.zero;
      if (config.backoff != null) {
        delay = config.backoff!(attempt);

        // Apply jitter to add randomness
        if (config.jitter > 0) {
          final random = Random();
          final jitterAmount = delay.inMilliseconds *
              config.jitter *
              (random.nextDouble() * 2 - 1);
          var newDelayMs = (delay.inMilliseconds + jitterAmount).round();
          // Ensure delay is never negative
          if (newDelayMs < 0) newDelayMs = 0;
          delay = Duration(milliseconds: newDelayMs);
        }

        // Ensure delay is never negative (handle negative backoff functions)
        if (delay.isNegative) {
          delay = Duration.zero;
        }

        // Apply max delay limit
        if (config.maxDelay != null && delay > config.maxDelay!) {
          delay = config.maxDelay!;
        }
      }

      // Wait before next attempt, but allow cancellation during delay
      if (delay > Duration.zero) {
        if (token != null) {
          // Wait for either the delay or cancellation, whichever comes first
          await Future.any([
            Future.delayed(delay),
            token.whenCancelled(),
          ]);
          // Check if cancellation was requested during the delay
          token.throwIfCancellationRequested();
        } else {
          await Future.delayed(delay);
        }
      }
    }
  }

  // This should never be reached due to the rethrow in the loop
  throw Exception('Retry failed for unknown reason');
}

/// Retries an operation with exponential backoff.
Future<T> withExponentialBackoff<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration baseDelay = const Duration(milliseconds: 100),
  double multiplier = 2.0,
  Duration? maxDelay,
  double jitter = 0.1,
  bool Function(Object error)? shouldRetry,
  CancellationToken? token,
}) async {
  return withRetryConfig(
    operation,
    RetryConfig.exponential(
      maxAttempts: maxAttempts,
      baseDelay: baseDelay,
      multiplier: multiplier,
      maxDelay: maxDelay,
      jitter: jitter,
      shouldRetry: shouldRetry,
    ),
    token: token,
  );
}

/// Retries an operation with linear backoff.
Future<T> withLinearBackoff<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration baseDelay = const Duration(milliseconds: 100),
  Duration? maxDelay,
  double jitter = 0.1,
  bool Function(Object error)? shouldRetry,
  CancellationToken? token,
}) async {
  return withRetryConfig(
    operation,
    RetryConfig.linear(
      maxAttempts: maxAttempts,
      baseDelay: baseDelay,
      maxDelay: maxDelay,
      jitter: jitter,
      shouldRetry: shouldRetry,
    ),
    token: token,
  );
}

/// Retries an operation with fixed delay between attempts.
Future<T> withFixedDelay<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration delay = const Duration(milliseconds: 100),
  double jitter = 0.1,
  bool Function(Object error)? shouldRetry,
  CancellationToken? token,
}) async {
  return withRetryConfig(
    operation,
    RetryConfig.fixed(
      maxAttempts: maxAttempts,
      delay: delay,
      jitter: jitter,
      shouldRetry: shouldRetry,
    ),
    token: token,
  );
}
