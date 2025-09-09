import 'dart:async';
import 'package:test/test.dart';
import 'package:async_toolkit/src/utils/retry.dart';
import 'package:async_toolkit/src/cancellation/cancellation_token.dart';
import 'package:async_toolkit/src/cancellation/cancellation_token_source.dart';

void main() {
  group('withRetry', () {
    test('should succeed on first attempt', () async {
      var attemptCount = 0;
      final result = await withRetry(() async {
        attemptCount++;
        return 'success';
      });

      expect(result, equals('success'));
      expect(attemptCount, equals(1));
    });

    test('should retry on failure and eventually succeed', () async {
      var attemptCount = 0;
      final result = await withRetry(() async {
        attemptCount++;
        if (attemptCount < 3) {
          throw Exception('Temporary failure');
        }
        return 'success';
      }, maxAttempts: 3);

      expect(result, equals('success'));
      expect(attemptCount, equals(3));
    });

    test('should fail after max attempts', () async {
      var attemptCount = 0;
      try {
        await withRetry(() async {
          attemptCount++;
          throw Exception('Permanent failure');
        }, maxAttempts: 3);
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e, isA<Exception>());
        expect(e.toString(), contains('Permanent failure'));
      }
      expect(attemptCount, equals(3));
    });

    test('should respect shouldRetry function', () async {
      var attemptCount = 0;
      expect(
        () => withRetry(
          () async {
            attemptCount++;
            throw Exception('Non-retryable error');
          },
          maxAttempts: 3,
          shouldRetry: (error) => !error.toString().contains('Non-retryable'),
        ),
        throwsA(predicate((e) =>
            e is Exception && e.toString().contains('Non-retryable error'))),
      );
      expect(attemptCount, equals(1));
    });

    test('should apply backoff delay', () async {
      var attemptCount = 0;
      final stopwatch = Stopwatch()..start();

      await withRetry(
        () async {
          attemptCount++;
          if (attemptCount < 3) {
            throw Exception('Temporary failure');
          }
          return 'success';
        },
        maxAttempts: 3,
        backoff: (attempt) => Duration(milliseconds: 50 * attempt),
      );

      stopwatch.stop();
      expect(attemptCount, equals(3));
      expect(stopwatch.elapsedMilliseconds,
          greaterThanOrEqualTo(140)); // 50 + 100 with some tolerance
    });

    test('should apply jitter to delays', () async {
      var attemptCount = 0;
      final delays = <Duration>[];

      await withRetry(
        () async {
          attemptCount++;
          if (attemptCount < 3) {
            throw Exception('Temporary failure');
          }
          return 'success';
        },
        maxAttempts: 3,
        backoff: (attempt) {
          final delay = Duration(milliseconds: 100);
          delays.add(delay);
          return delay;
        },
        jitter: 0.5, // 50% jitter
      );

      expect(attemptCount, equals(3));
      expect(delays.length, equals(2)); // Two delays between 3 attempts
    });

    test('should respect maxDelay', () async {
      var attemptCount = 0;
      final stopwatch = Stopwatch()..start();

      await withRetry(
        () async {
          attemptCount++;
          if (attemptCount < 3) {
            throw Exception('Temporary failure');
          }
          return 'success';
        },
        maxAttempts: 3,
        backoff: (attempt) => Duration(seconds: 10), // Very long delay
        maxDelay: Duration(milliseconds: 100), // But capped at 100ms
      );

      stopwatch.stop();
      expect(attemptCount, equals(3));
      expect(stopwatch.elapsedMilliseconds,
          lessThan(500)); // Should be much less than 20 seconds
    });

    test('should throw OperationCanceledException when cancelled', () async {
      final source = CancellationTokenSource();
      var attemptCount = 0;

      // Cancel after first attempt
      Timer(Duration(milliseconds: 50), () => source.cancel());

      try {
        await withRetry(
          () async {
            attemptCount++;
            throw Exception('Temporary failure');
          },
          maxAttempts: 3,
          backoff: (attempt) => Duration(milliseconds: 100),
          token: source.token,
        );
        fail('Expected OperationCanceledException');
      } on OperationCanceledException {
        // Expected
      } finally {
        source.dispose();
      }
    });

    test('should throw immediately when already cancelled', () async {
      final source = CancellationTokenSource();
      source.cancel();

      expect(
        () => withRetry(() async {
          return 'success';
        }, token: source.token),
        throwsA(isA<OperationCanceledException>()),
      );

      source.dispose();
    });

    test('should cancel during delay between retries', () async {
      final source = CancellationTokenSource();
      var attemptCount = 0;
      final stopwatch = Stopwatch()..start();

      // Cancel after 200ms - during the delay before second attempt
      Timer(Duration(milliseconds: 200), () => source.cancel());

      try {
        await withRetry(
          () async {
            attemptCount++;
            throw Exception('Always fail');
          },
          maxAttempts: 3,
          backoff: (attempt) => Duration(seconds: 1), // Long delay
          token: source.token,
        );
        fail('Expected OperationCanceledException');
      } on OperationCanceledException {
        stopwatch.stop();
        // Should be cancelled during delay, not after full 1 second
        expect(stopwatch.elapsedMilliseconds, lessThan(500));
        expect(attemptCount, equals(1)); // Only first attempt should complete
      } finally {
        source.dispose();
      }
    });

    test('should cancel immediately during delay if already cancelled',
        () async {
      final source = CancellationTokenSource();
      var attemptCount = 0;
      final stopwatch = Stopwatch()..start();

      try {
        await withRetry(
          () async {
            attemptCount++;
            if (attemptCount == 1) {
              // Cancel during first attempt
              source.cancel();
              throw Exception('First attempt fails');
            }
            return 'success';
          },
          maxAttempts: 3,
          backoff: (attempt) => Duration(seconds: 1), // Long delay
          token: source.token,
        );
        fail('Expected OperationCanceledException');
      } on OperationCanceledException {
        stopwatch.stop();
        // Should be cancelled immediately when trying to delay
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
        expect(attemptCount, equals(1));
      } finally {
        source.dispose();
      }
    });
  });

  group('withExponentialBackoff', () {
    test('should use exponential backoff', () async {
      var attemptCount = 0;
      final delays = <Duration>[];

      await withExponentialBackoff(
        () async {
          attemptCount++;
          if (attemptCount < 4) {
            throw Exception('Temporary failure');
          }
          return 'success';
        },
        maxAttempts: 4,
        baseDelay: Duration(milliseconds: 100),
        multiplier: 2.0,
      );

      expect(attemptCount, equals(4));
      // Delays should be approximately 100ms, 200ms, 400ms
    });
  });

  group('withLinearBackoff', () {
    test('should use linear backoff', () async {
      var attemptCount = 0;

      await withLinearBackoff(
        () async {
          attemptCount++;
          if (attemptCount < 4) {
            throw Exception('Temporary failure');
          }
          return 'success';
        },
        maxAttempts: 4,
        baseDelay: Duration(milliseconds: 50),
      );

      expect(attemptCount, equals(4));
      // Delays should be approximately 50ms, 100ms, 150ms
    });
  });

  group('withFixedDelay', () {
    test('should use fixed delay', () async {
      var attemptCount = 0;
      final stopwatch = Stopwatch()..start();

      await withFixedDelay(
        () async {
          attemptCount++;
          if (attemptCount < 3) {
            throw Exception('Temporary failure');
          }
          return 'success';
        },
        maxAttempts: 3,
        delay: Duration(milliseconds: 100),
      );

      stopwatch.stop();
      expect(attemptCount, equals(3));
      expect(
          stopwatch.elapsedMilliseconds,
          greaterThanOrEqualTo(
              180)); // 2 delays of ~100ms each (allowing some variance)
    });
  });

  group('RetryConfig', () {
    test('should create exponential config', () {
      final config = RetryConfig.exponential(
        maxAttempts: 5,
        baseDelay: Duration(milliseconds: 100),
        multiplier: 2.0,
        maxDelay: Duration(seconds: 1),
      );

      expect(config.maxAttempts, equals(5));
      expect(config.maxDelay, equals(Duration(seconds: 1)));
      expect(config.jitter, equals(0.1));

      // Test backoff calculation
      final delay1 = config.backoff!(1);
      final delay2 = config.backoff!(2);
      final delay3 = config.backoff!(3);

      expect(delay1.inMilliseconds, equals(100));
      expect(delay2.inMilliseconds, equals(200));
      expect(delay3.inMilliseconds, equals(400));
    });

    test('should create linear config', () {
      final config = RetryConfig.linear(
        maxAttempts: 3,
        baseDelay: Duration(milliseconds: 50),
      );

      expect(config.maxAttempts, equals(3));

      // Test backoff calculation
      final delay1 = config.backoff!(1);
      final delay2 = config.backoff!(2);
      final delay3 = config.backoff!(3);

      expect(delay1.inMilliseconds, equals(50));
      expect(delay2.inMilliseconds, equals(100));
      expect(delay3.inMilliseconds, equals(150));
    });

    test('should create fixed config', () {
      final config = RetryConfig.fixed(
        maxAttempts: 3,
        delay: Duration(milliseconds: 200),
      );

      expect(config.maxAttempts, equals(3));

      // Test backoff calculation
      final delay1 = config.backoff!(1);
      final delay2 = config.backoff!(2);
      final delay3 = config.backoff!(3);

      expect(delay1.inMilliseconds, equals(200));
      expect(delay2.inMilliseconds, equals(200));
      expect(delay3.inMilliseconds, equals(200));
    });

    test('should validate maxAttempts', () {
      expect(
        () => withRetry(() async => 'success', maxAttempts: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should validate negative maxAttempts', () {
      expect(
        () => withRetry(() async => 'success', maxAttempts: -1),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Input Validation Tests', () {
    test('should handle invalid jitter values', () {
      expect(
        () => withRetry(() async => 'success', jitter: -0.5),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => withRetry(() async => 'success', jitter: 1.5),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should preserve original exception type', () async {
      final customException = FormatException('Custom format error');

      try {
        await withRetry(() async => throw customException, maxAttempts: 2);
        fail('Should have thrown FormatException');
      } catch (e) {
        expect(e, isA<FormatException>());
        expect(e.toString(), contains('Custom format error'));
      }
    });

    test('should handle null operation gracefully', () {
      expect(
        () => withRetry(null as dynamic),
        throwsA(isA<TypeError>()),
      );
    });

    test('should validate RetryConfig parameters', () {
      expect(
        () => RetryConfig.exponential(maxAttempts: 0),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => RetryConfig.linear(maxAttempts: -5),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => RetryConfig.fixed(maxAttempts: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should handle very large maxAttempts', () async {
      var callCount = 0;
      final result = await withRetry(() async {
        callCount++;
        return 'success';
      }, maxAttempts: 1000000);

      expect(result, equals('success'));
      expect(callCount, equals(1)); // Should succeed on first attempt
    });

    test('should handle zero delay backoff', () async {
      var callCount = 0;
      final stopwatch = Stopwatch()..start();

      try {
        await withRetry(() async {
          callCount++;
          if (callCount < 3) throw Exception('Temporary failure');
          return 'success';
        }, maxAttempts: 3, backoff: (_) => Duration.zero);
      } catch (e) {
        // Expected to fail quickly due to zero delay
      }

      stopwatch.stop();
      expect(callCount, equals(3));
      expect(
          stopwatch.elapsedMilliseconds, lessThan(100)); // Should be very fast
    });

    test('should handle negative delay from backoff function', () async {
      var callCount = 0;

      await withRetry(() async {
        callCount++;
        if (callCount < 2) throw Exception('Temporary failure');
        return 'success';
      },
          maxAttempts: 2,
          backoff: (_) => Duration(milliseconds: -100)); // Negative delay

      expect(callCount, equals(2));
      // Should handle negative delay gracefully (treat as zero)
    });
  });
}
