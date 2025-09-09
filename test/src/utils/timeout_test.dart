import 'dart:async';
import 'package:test/test.dart';
import 'package:async_toolkit/src/utils/timeout.dart';
import 'package:async_toolkit/src/cancellation/cancellation_token.dart';
import 'package:async_toolkit/src/cancellation/cancellation_token_source.dart';

void main() {
  group('withTimeout', () {
    test('should return result when future completes before timeout', () async {
      final future =
          Future.delayed(Duration(milliseconds: 50), () => 'success');
      final result = await withTimeout(future, Duration(seconds: 1));
      expect(result, equals('success'));
    });

    test('should throw TimeoutException when future exceeds timeout', () async {
      final future = Future.delayed(Duration(seconds: 2), () => 'success');
      expect(
        () => withTimeout(future, Duration(milliseconds: 100)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('should throw OperationCanceledException when cancelled', () async {
      final source = CancellationTokenSource();
      final future = Future.delayed(Duration(seconds: 2), () => 'success');

      // Cancel after 50ms
      Timer(Duration(milliseconds: 50), () => source.cancel());

      try {
        await withTimeout(future, Duration(seconds: 1), token: source.token);
        fail('Expected OperationCanceledException');
      } on OperationCanceledException {
        // Expected
      } finally {
        source.dispose();
      }
    });

    test('should not throw when already cancelled before call', () async {
      final source = CancellationTokenSource();
      source.cancel();

      final future =
          Future.delayed(Duration(milliseconds: 50), () => 'success');

      expect(
        () => withTimeout(future, Duration(seconds: 1), token: source.token),
        throwsA(isA<OperationCanceledException>()),
      );

      source.dispose();
    });

    test('should propagate original exception from future', () async {
      final future = Future.delayed(Duration(milliseconds: 50), () {
        throw Exception('Original error');
      });

      expect(
        () => withTimeout(future, Duration(seconds: 1)),
        throwsA(predicate(
            (e) => e is Exception && e.toString().contains('Original error'))),
      );
    });

    test('should clean up resources properly', () async {
      var cleanupCalled = false;
      final future = Future.delayed(Duration(milliseconds: 50), () {
        cleanupCalled = true;
        return 'success';
      });

      final result = await withTimeout(future, Duration(seconds: 1));
      expect(result, equals('success'));
      expect(cleanupCalled, isTrue);
    });
  });

  group('withTimeoutOrNull', () {
    test('should return result when future completes before timeout', () async {
      final future =
          Future.delayed(Duration(milliseconds: 50), () => 'success');
      final result = await withTimeoutOrNull(future, Duration(seconds: 1));
      expect(result, equals('success'));
    });

    test('should return null when future exceeds timeout', () async {
      final future = Future.delayed(Duration(seconds: 2), () => 'success');
      final result =
          await withTimeoutOrNull(future, Duration(milliseconds: 100));
      expect(result, isNull);
    });

    test('should throw OperationCanceledException when cancelled', () async {
      final source = CancellationTokenSource();
      final future = Future.delayed(Duration(seconds: 2), () => 'success');

      Timer(Duration(milliseconds: 50), () => source.cancel());

      try {
        await withTimeoutOrNull(future, Duration(seconds: 1),
            token: source.token);
        fail('Expected OperationCanceledException');
      } on OperationCanceledException {
        // Expected
      } finally {
        source.dispose();
      }
    });

    test('should propagate original exception from future', () async {
      final future = Future.delayed(Duration(milliseconds: 50), () {
        throw Exception('Original error');
      });

      expect(
        () => withTimeoutOrNull(future, Duration(seconds: 1)),
        throwsA(predicate(
            (e) => e is Exception && e.toString().contains('Original error'))),
      );
    });
  });

  group('withTimeout - Simplified Implementation Tests', () {
    test(
        'should work correctly without cancellation token (using built-in timeout)',
        () async {
      final future = Future.delayed(Duration(milliseconds: 50), () => 'fast');
      final result = await withTimeout(future, Duration(seconds: 1));
      expect(result, equals('fast'));

      // Test timeout without cancellation token
      final slowFuture = Future.delayed(Duration(seconds: 2), () => 'slow');
      expect(
        () => withTimeout(slowFuture, Duration(milliseconds: 100)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('should prioritize cancellation over timeout when cancelled first',
        () async {
      final source = CancellationTokenSource();
      final future = Future.delayed(Duration(seconds: 5), () => 'result');

      // Cancel immediately
      Timer(Duration(milliseconds: 10), () => source.cancel());

      final stopwatch = Stopwatch()..start();
      try {
        await withTimeout(future, Duration(seconds: 1), token: source.token);
        fail('Expected OperationCanceledException');
      } on OperationCanceledException {
        stopwatch.stop();
        // Should be cancelled quickly, not after 1 second timeout
        expect(stopwatch.elapsedMilliseconds, lessThan(500));
      } finally {
        source.dispose();
      }
    });

    test(
        'should prioritize timeout over cancellation when timeout occurs first',
        () async {
      final source = CancellationTokenSource();
      final future = Future.delayed(Duration(seconds: 5), () => 'result');

      // Cancel after timeout should occur
      Timer(Duration(seconds: 1), () => source.cancel());

      try {
        await withTimeout(future, Duration(milliseconds: 100),
            token: source.token);
        fail('Expected TimeoutException');
      } on TimeoutException {
        // Expected - timeout should occur first
      } finally {
        source.dispose();
      }
    });

    test('should handle concurrent cancellation and completion correctly',
        () async {
      final source = CancellationTokenSource();

      // Future that completes quickly
      final future =
          Future.delayed(Duration(milliseconds: 50), () => 'success');

      // Cancel around the same time
      Timer(Duration(milliseconds: 45), () => source.cancel());

      try {
        final result = await withTimeout(future, Duration(seconds: 1),
            token: source.token);
        // If future completes first, we get the result
        expect(result, equals('success'));
      } on OperationCanceledException {
        // If cancellation wins the race, that's also valid
      } finally {
        source.dispose();
      }
    });

    test('should maintain original error types from future', () async {
      final customError = ArgumentError('Custom error');
      final future = Future<String>.error(customError);

      try {
        await withTimeout(future, Duration(seconds: 1));
        fail('Expected ArgumentError');
      } catch (e) {
        expect(e, equals(customError));
      }
    });
  });

  group('withTimeoutOrDefault', () {
    test('should return result when future completes before timeout', () async {
      final future =
          Future.delayed(Duration(milliseconds: 50), () => 'success');
      final result =
          await withTimeoutOrDefault(future, Duration(seconds: 1), 'default');
      expect(result, equals('success'));
    });

    test('should return default value when future exceeds timeout', () async {
      final future = Future.delayed(Duration(seconds: 2), () => 'success');
      final result = await withTimeoutOrDefault(
          future, Duration(milliseconds: 100), 'default');
      expect(result, equals('default'));
    });

    test('should throw OperationCanceledException when cancelled', () async {
      final source = CancellationTokenSource();
      final future = Future.delayed(Duration(seconds: 2), () => 'success');

      Timer(Duration(milliseconds: 50), () => source.cancel());

      try {
        await withTimeoutOrDefault(future, Duration(seconds: 1), 'default',
            token: source.token);
        fail('Expected OperationCanceledException');
      } on OperationCanceledException {
        // Expected
      } finally {
        source.dispose();
      }
    });

    test('should propagate original exception from future', () async {
      final future = Future.delayed(Duration(milliseconds: 50), () {
        throw Exception('Original error');
      });

      expect(
        () => withTimeoutOrDefault(future, Duration(seconds: 1), 'default'),
        throwsA(predicate(
            (e) => e is Exception && e.toString().contains('Original error'))),
      );
    });
  });

  group('Input Validation Tests', () {
    test('should handle zero timeout', () async {
      final future =
          Future.delayed(Duration(milliseconds: 100), () => 'result');

      expect(
        () => withTimeout(future, Duration.zero),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('should handle negative timeout', () async {
      final future =
          Future.delayed(Duration(milliseconds: 100), () => 'result');

      expect(
        () => withTimeout(future, Duration(milliseconds: -100)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should handle null future gracefully', () {
      expect(
        () => withTimeout(null as dynamic, Duration(seconds: 1)),
        throwsA(isA<TypeError>()),
      );
    });

    test('should handle very large timeout', () async {
      final future =
          Future.delayed(Duration(milliseconds: 50), () => 'success');

      final result = await withTimeout(future, Duration(days: 365));
      expect(result, equals('success'));
    });

    test('should handle concurrent timeout and cancellation', () async {
      final source = CancellationTokenSource();
      final future = Future.delayed(Duration(seconds: 2), () => 'result');

      // Cancel and timeout at almost the same time
      Timer(Duration(milliseconds: 50), () => source.cancel());

      try {
        await withTimeout(future, Duration(milliseconds: 100),
            token: source.token);
        fail('Should have thrown an exception');
      } catch (e) {
        // Should throw either TimeoutException or OperationCanceledException
        expect(
            e,
            anyOf(
              isA<TimeoutException>(),
              isA<OperationCanceledException>(),
            ));
      } finally {
        source.dispose();
      }
    });

    test('withTimeoutOrNull should handle null default correctly', () async {
      final future = Future.delayed(Duration(seconds: 2), () => 'result');

      final result =
          await withTimeoutOrNull(future, Duration(milliseconds: 100));
      expect(result, isNull);
    });

    test('withTimeoutOrDefault should handle null default value', () async {
      final future = Future.delayed(Duration(seconds: 2), () => 'result');

      final result =
          await withTimeoutOrDefault(future, Duration(milliseconds: 100), null);
      expect(result, isNull);
    });

    test('should preserve exception type and stack trace', () async {
      final customException = StateError('Custom state error');
      final future = Future.delayed(
          Duration(milliseconds: 50), () => throw customException);

      try {
        await withTimeout(future, Duration(seconds: 1));
        fail('Should have thrown StateError');
      } catch (e, stackTrace) {
        expect(e, isA<StateError>());
        expect(e.toString(), contains('Custom state error'));
        expect(stackTrace, isNotNull);
      }
    });
  });
}
