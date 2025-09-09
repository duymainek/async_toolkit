import 'dart:async';
import 'package:test/test.dart';
import 'package:async_toolkit/async_toolkit.dart';

void main() {
  group('ThrottleManager', () {
    late ThrottleManager<String> throttleManager;

    setUp(() {
      throttleManager = ThrottleManager<String>(Duration(milliseconds: 100));
    });

    test('should execute first call immediately', () async {
      var callCount = 0;
      Future<String> operation() async {
        callCount++;
        return 'result$callCount';
      }

      final result = await throttleManager.throttle(operation);

      expect(result, equals('result1'));
      expect(callCount, equals(1));
    });

    test('should return cached result for subsequent calls within duration',
        () async {
      var callCount = 0;
      Future<String> operation() async {
        callCount++;
        await Future.delayed(Duration(milliseconds: 10));
        return 'result$callCount';
      }

      // First call
      final result1 = await throttleManager.throttle(operation);

      // Second call within throttle duration
      final result2 = await throttleManager.throttle(operation);

      expect(result1, equals('result1'));
      expect(result2, equals('result1')); // Same result, cached
      expect(callCount, equals(1)); // Operation called only once
    });

    test('should execute new call after throttle duration expires', () async {
      var callCount = 0;
      Future<String> operation() async {
        callCount++;
        return 'result$callCount';
      }

      // First call
      final result1 = await throttleManager.throttle(operation);

      // Wait for throttle duration to expire
      await Future.delayed(Duration(milliseconds: 150));

      // Second call after duration
      final result2 = await throttleManager.throttle(operation);

      expect(result1, equals('result1'));
      expect(result2, equals('result2')); // New result
      expect(callCount, equals(2)); // Operation called twice
    });

    test('should handle concurrent calls properly', () async {
      var callCount = 0;
      Future<String> operation() async {
        callCount++;
        await Future.delayed(Duration(milliseconds: 50));
        return 'result$callCount';
      }

      // Start multiple concurrent calls
      final futures =
          List.generate(5, (_) => throttleManager.throttle(operation));
      final results = await Future.wait(futures);

      // All should return the same result
      for (final result in results) {
        expect(result, equals('result1'));
      }
      expect(callCount, equals(1)); // Operation called only once
    });

    test('should reset state when reset is called', () async {
      var callCount = 0;
      Future<String> operation() async {
        callCount++;
        return 'result$callCount';
      }

      // First call
      await throttleManager.throttle(operation);

      // Reset
      throttleManager.reset();

      // Call again immediately after reset
      final result = await throttleManager.throttle(operation);

      expect(result, equals('result2'));
      expect(callCount, equals(2));
    });

    test('should handle errors properly', () async {
      Future<String> failingOperation() async {
        throw Exception('Test error');
      }

      expect(
        () => throttleManager.throttle(failingOperation),
        throwsA(isA<Exception>()),
      );
    });

    test('should not cache failed results and allow immediate retry', () async {
      var callCount = 0;
      Future<String> operation() async {
        callCount++;
        if (callCount == 1) {
          throw Exception('First call fails');
        }
        return 'success$callCount';
      }

      // First call should fail
      try {
        await throttleManager.throttle(operation);
        fail('Expected exception');
      } catch (e) {
        expect(e, isA<Exception>());
      }

      // Second call should execute immediately (not throttled) since first failed
      final result = await throttleManager.throttle(operation);
      expect(result, equals('success2'));
      expect(callCount, equals(2));
    });

    test('should handle dispose correctly', () async {
      var callCount = 0;
      Future<String> operation() async {
        callCount++;
        return 'result$callCount';
      }

      // Use the manager normally
      final result1 = await throttleManager.throttle(operation);
      expect(result1, equals('result1'));
      expect(throttleManager.isDisposed, isFalse);

      // Dispose the manager
      throttleManager.dispose();
      expect(throttleManager.isDisposed, isTrue);

      // Should throw when used after disposal
      expect(
        () => throttleManager.throttle(operation),
        throwsA(isA<StateError>()),
      );

      expect(
        () => throttleManager.reset(),
        throwsA(isA<StateError>()),
      );
    });

    test('should handle multiple dispose calls safely', () async {
      throttleManager.dispose();
      expect(throttleManager.isDisposed, isTrue);

      // Should be safe to dispose multiple times
      throttleManager.dispose();
      expect(throttleManager.isDisposed, isTrue);
    });

    test('should not cache results after disposal during execution', () async {
      var callCount = 0;
      Future<String> slowOperation() async {
        callCount++;
        await Future.delayed(Duration(milliseconds: 50));
        return 'result$callCount';
      }

      // Start operation
      final future = throttleManager.throttle(slowOperation);

      // Dispose while operation is running
      throttleManager.dispose();

      // Operation should complete but result shouldn't be cached
      final result = await future;
      expect(result, equals('result1'));
      expect(callCount, equals(1));
      expect(throttleManager.isDisposed, isTrue);
    });
  });

  group('DebounceManager', () {
    late DebounceManager<String> debounceManager;

    setUp(() {
      debounceManager = DebounceManager<String>(Duration(milliseconds: 100));
    });

    tearDown(() {
      debounceManager.dispose();
    });

    test('should execute operation after debounce duration', () async {
      var callCount = 0;
      Future<String> operation() async {
        callCount++;
        return 'result$callCount';
      }

      final future = debounceManager.debounce(operation);

      // Operation should not execute immediately
      expect(callCount, equals(0));

      // Wait for debounce duration
      final result = await future;

      expect(result, equals('result1'));
      expect(callCount, equals(1));
    });

    test('should cancel previous operation when new one is called', () async {
      var callCount = 0;
      Future<String> operation() async {
        callCount++;
        return 'result$callCount';
      }

      // First call
      final future1 = debounceManager.debounce(operation);

      // Second call before first completes (should cancel first)
      await Future.delayed(Duration(milliseconds: 50));
      final future2 = debounceManager.debounce(operation);

      // First should be cancelled
      expect(
        () => future1,
        throwsA(isA<OperationCanceledException>()),
      );

      // Second should complete
      final result = await future2;
      expect(result, equals('result1'));
      expect(callCount, equals(1)); // Only one operation executed
    });

    test('should handle multiple rapid calls correctly', () async {
      var callCount = 0;
      Future<String> operation() async {
        callCount++;
        return 'result$callCount';
      }

      // Make multiple rapid calls
      final futures = <Future<String>>[];
      for (int i = 0; i < 5; i++) {
        futures.add(
            debounceManager.debounce(operation).catchError((e) => 'cancelled'));
        await Future.delayed(
            Duration(milliseconds: 10)); // Small delay between calls
      }

      // Wait for all to complete or fail
      final results = await Future.wait(futures);

      // Only the last call should succeed
      final successCount = results.where((r) => r.startsWith('result')).length;
      final cancelledCount = results.where((r) => r == 'cancelled').length;

      expect(successCount, equals(1));
      expect(cancelledCount, equals(4));
      expect(callCount, equals(1)); // Only one operation executed
    });

    test('should cancel operation when cancel is called', () async {
      Future<String> operation() async {
        await Future.delayed(Duration(milliseconds: 200));
        return 'result';
      }

      final future = debounceManager.debounce(operation);

      // Cancel before completion
      debounceManager.cancel();

      expect(
        () => future,
        throwsA(isA<OperationCanceledException>()),
      );
    });

    test('should handle errors properly', () async {
      Future<String> failingOperation() async {
        throw Exception('Test error');
      }

      final future = debounceManager.debounce(failingOperation);

      expect(
        () => future,
        throwsA(isA<Exception>()),
      );
    });

    test('dispose should cancel pending operations', () async {
      Future<String> operation() async {
        await Future.delayed(Duration(milliseconds: 200));
        return 'result';
      }

      final future = debounceManager.debounce(operation);

      // Dispose before completion
      debounceManager.dispose();

      expect(
        () => future,
        throwsA(isA<OperationCanceledException>()),
      );
    });
  });

  group('Global throttle function', () {
    setUp(() {
      clearGlobalManagers();
    });

    test('should throttle operations correctly', () async {
      var callCount = 0;
      Future<String> operation() async {
        callCount++;
        return 'result$callCount';
      }

      // First call
      final result1 = await throttle(operation, Duration(milliseconds: 100));

      // Second call within duration
      final result2 = await throttle(operation, Duration(milliseconds: 100));

      expect(result1, equals('result1'));
      expect(result2, equals('result1')); // Same result, cached
      expect(callCount, equals(1)); // Operation called only once
    });

    test('should work with different types', () async {
      var callCount1 = 0;
      var callCount2 = 0;

      Future<String> operation1() async {
        callCount1++;
        return 'result1_$callCount1';
      }

      Future<int> operation2() async {
        callCount2++;
        return callCount2;
      }

      // Different return types should use different managers
      final result1 = await throttle(operation1, Duration(milliseconds: 100));
      final result2 = await throttle(operation2, Duration(milliseconds: 100));

      expect(result1, equals('result1_1'));
      expect(result2, equals(1));
      expect(callCount1, equals(1));
      expect(callCount2, equals(1));

      // Same type operations within throttle duration should return cached result
      final result1Again =
          await throttle(operation1, Duration(milliseconds: 100));
      expect(result1Again, equals('result1_1')); // Cached result
      expect(callCount1, equals(1)); // Still only called once
    });
  });

  group('Global debounce function', () {
    setUp(() {
      clearGlobalManagers();
    });

    test('should debounce operations correctly', () async {
      var callCount = 0;
      Future<String> operation() async {
        callCount++;
        return 'result$callCount';
      }

      // Multiple rapid calls
      final future1 = debounce(operation, Duration(milliseconds: 100));
      final future2 = debounce(operation, Duration(milliseconds: 100));

      // First should be cancelled
      expect(
        () => future1,
        throwsA(isA<OperationCanceledException>()),
      );

      // Second should complete
      final result = await future2;
      expect(result, equals('result1'));
      expect(callCount, equals(1)); // Only one operation executed
    });
  });

  group('Global Functions with Custom Keys', () {
    setUp(() {
      clearGlobalManagers();
    });

    test('throttle with custom key should isolate operations', () async {
      var count1 = 0;
      var count2 = 0;

      Future<String> operation1() async {
        count1++;
        return 'op1-$count1';
      }

      Future<String> operation2() async {
        count2++;
        return 'op2-$count2';
      }

      // Same duration but different custom keys should be isolated
      final result1 =
          await throttle(operation1, Duration(milliseconds: 100), key: 'key1');
      final result2 =
          await throttle(operation2, Duration(milliseconds: 100), key: 'key2');

      expect(result1, equals('op1-1'));
      expect(result2, equals('op2-1'));
      expect(count1, equals(1));
      expect(count2, equals(1));

      // Calling again with same keys should use cached results
      final result3 =
          await throttle(operation1, Duration(milliseconds: 100), key: 'key1');
      final result4 =
          await throttle(operation2, Duration(milliseconds: 100), key: 'key2');

      expect(result3, equals('op1-1')); // Cached
      expect(result4, equals('op2-1')); // Cached
      expect(count1, equals(1)); // No new call
      expect(count2, equals(1)); // No new call
    });

    test('debounce with custom key should isolate operations', () async {
      var count1 = 0;
      var count2 = 0;

      Future<String> operation1() async {
        count1++;
        return 'op1-$count1';
      }

      Future<String> operation2() async {
        count2++;
        return 'op2-$count2';
      }

      // Start debounced operations with different keys
      final future1 =
          debounce(operation1, Duration(milliseconds: 50), key: 'debounce1');
      final future2 =
          debounce(operation2, Duration(milliseconds: 50), key: 'debounce2');

      // Both should execute independently
      final result1 = await future1;
      final result2 = await future2;

      expect(result1, equals('op1-1'));
      expect(result2, equals('op2-1'));
      expect(count1, equals(1));
      expect(count2, equals(1));
    });

    test(
        'operations with same signature but different keys should not interfere',
        () async {
      var countA = 0;
      var countB = 0;

      // Same function signature but different implementations
      Future<String> operationA() async {
        countA++;
        return 'A-$countA';
      }

      Future<String> operationB() async {
        countB++;
        return 'B-$countB';
      }

      // Without custom keys, these might interfere due to same signature
      // With custom keys, they should be isolated
      final resultA = await throttle(operationA, Duration(milliseconds: 100),
          key: 'operationA');
      final resultB = await throttle(operationB, Duration(milliseconds: 100),
          key: 'operationB');

      expect(resultA, equals('A-1'));
      expect(resultB, equals('B-1'));
      expect(countA, equals(1));
      expect(countB, equals(1));
    });
  });

  group('clearGlobalManagers', () {
    setUp(() {
      clearGlobalManagers();
    });

    test('should clear all global managers', () async {
      var callCount = 0;
      Future<String> operation() async {
        callCount++;
        return 'result$callCount';
      }

      // Use global functions to create managers
      await throttle(operation, Duration(milliseconds: 100));
      final future = debounce(operation, Duration(milliseconds: 100));

      // Clear all managers
      clearGlobalManagers();

      // Pending debounce should be cancelled
      expect(
        () => future,
        throwsA(isA<OperationCanceledException>()),
      );

      // New calls should work (new managers created)
      final result = await throttle(operation, Duration(milliseconds: 100));
      expect(result, equals('result2')); // New execution (callCount is now 2)
    });
  });

  group('Integration tests', () {
    test('throttle and debounce should work together', () async {
      var throttleCallCount = 0;
      var debounceCallCount = 0;

      Future<String> throttleOperation() async {
        throttleCallCount++;
        return 'throttle$throttleCallCount';
      }

      Future<String> debounceOperation() async {
        debounceCallCount++;
        return 'debounce$debounceCallCount';
      }

      final throttleManager =
          ThrottleManager<String>(Duration(milliseconds: 100));
      final debounceManager =
          DebounceManager<String>(Duration(milliseconds: 100));

      try {
        // Test throttle
        final throttleResult1 =
            await throttleManager.throttle(throttleOperation);
        final throttleResult2 =
            await throttleManager.throttle(throttleOperation);

        // Test debounce
        final debounceResult =
            await debounceManager.debounce(debounceOperation);

        expect(throttleResult1, equals('throttle1'));
        expect(throttleResult2, equals('throttle1')); // Cached
        expect(debounceResult, equals('debounce1'));
        expect(throttleCallCount, equals(1));
        expect(debounceCallCount, equals(1));
      } finally {
        debounceManager.dispose();
      }
    });
  });

  group('Input Validation Tests', () {
    test('ThrottleManager should handle zero duration', () async {
      final manager = ThrottleManager<String>(Duration.zero);
      var callCount = 0;

      Future<String> operation() async {
        callCount++;
        return 'result$callCount';
      }

      final result1 = await manager.throttle(operation);
      final result2 = await manager.throttle(operation);

      // With zero duration, each call should execute
      expect(result1, equals('result1'));
      expect(result2, equals('result2'));
      expect(callCount, equals(2));
    });

    test('ThrottleManager should handle negative duration', () {
      expect(
        () => ThrottleManager<String>(Duration(milliseconds: -100)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('DebounceManager should handle zero duration', () async {
      final manager = DebounceManager<String>(Duration.zero);
      var callCount = 0;

      Future<String> operation() async {
        callCount++;
        return 'result$callCount';
      }

      final result = await manager.debounce(operation);
      expect(result, equals('result1'));
      expect(callCount, equals(1));
    });

    test('DebounceManager should handle negative duration', () {
      expect(
        () => DebounceManager<String>(Duration(milliseconds: -100)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should handle null operation gracefully', () {
      final throttleManager =
          ThrottleManager<String>(Duration(milliseconds: 100));
      final debounceManager =
          DebounceManager<String>(Duration(milliseconds: 100));

      expect(
        () => throttleManager.throttle(null as dynamic),
        throwsA(isA<TypeError>()),
      );

      expect(
        () => debounceManager.debounce(null as dynamic),
        throwsA(isA<TypeError>()),
      );

      debounceManager.dispose();
    });

    test('global throttle should handle invalid duration', () {
      Future<String> operation() async => 'result';

      expect(
        () => throttle(operation, Duration(milliseconds: -100)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('global debounce should handle invalid duration', () {
      Future<String> operation() async => 'result';

      expect(
        () => debounce(operation, Duration(milliseconds: -100)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should handle very large durations', () async {
      final throttleManager = ThrottleManager<String>(Duration(days: 365));
      var callCount = 0;

      Future<String> operation() async {
        callCount++;
        return 'result$callCount';
      }

      final result1 = await throttleManager.throttle(operation);
      final result2 = await throttleManager.throttle(operation);

      // Second call should return cached result due to very long duration
      expect(result1, equals('result1'));
      expect(result2, equals('result1')); // Same result, cached
      expect(callCount, equals(1));
    });

    test('should handle operation that returns null', () async {
      final throttleManager =
          ThrottleManager<String?>(Duration(milliseconds: 100));
      final debounceManager =
          DebounceManager<String?>(Duration(milliseconds: 100));

      Future<String?> nullOperation() async => null;

      final throttleResult = await throttleManager.throttle(nullOperation);
      final debounceResult = await debounceManager.debounce(nullOperation);

      expect(throttleResult, isNull);
      expect(debounceResult, isNull);

      debounceManager.dispose();
    });

    test('should preserve exception types', () async {
      final throttleManager =
          ThrottleManager<String>(Duration(milliseconds: 100));
      final debounceManager =
          DebounceManager<String>(Duration(milliseconds: 100));

      final customException = StateError('Custom state error');
      Future<String> failingOperation() async => throw customException;

      try {
        await throttleManager.throttle(failingOperation);
        fail('Should have thrown StateError');
      } catch (e) {
        expect(e, isA<StateError>());
        expect(e.toString(), contains('Custom state error'));
      }

      try {
        await debounceManager.debounce(failingOperation);
        fail('Should have thrown StateError');
      } catch (e) {
        expect(e, isA<StateError>());
        expect(e.toString(), contains('Custom state error'));
      }

      debounceManager.dispose();
    });

    test('DebounceManager should handle dispose correctly', () async {
      final debounceManager =
          DebounceManager<String>(Duration(milliseconds: 100));

      expect(debounceManager.isDisposed, isFalse);

      // Dispose the manager
      debounceManager.dispose();

      expect(debounceManager.isDisposed, isTrue);

      // Should throw StateError when trying to use after disposal
      expect(
        () => debounceManager.debounce(() async => 'test'),
        throwsA(isA<StateError>()),
      );

      expect(
        () => debounceManager.cancel(),
        throwsA(isA<StateError>()),
      );
    });

    test('DebounceManager should handle multiple dispose calls safely', () {
      final debounceManager =
          DebounceManager<String>(Duration(milliseconds: 100));

      expect(debounceManager.isDisposed, isFalse);

      // First dispose
      debounceManager.dispose();
      expect(debounceManager.isDisposed, isTrue);

      // Second dispose should not throw
      expect(() => debounceManager.dispose(), returnsNormally);
      expect(debounceManager.isDisposed, isTrue);
    });

    test('DebounceManager should cancel pending operations on dispose',
        () async {
      final debounceManager =
          DebounceManager<String>(Duration(milliseconds: 200));

      var operationExecuted = false;
      Future<String> operation() async {
        await Future.delayed(Duration(milliseconds: 50));
        operationExecuted = true;
        return 'result';
      }

      // Start a debounced operation
      final future = debounceManager.debounce(operation);

      // Dispose immediately (before the debounce delay completes)
      debounceManager.dispose();

      // The operation should be cancelled
      try {
        await future;
        fail('Should have thrown OperationCanceledException');
      } on OperationCanceledException {
        // Expected
      }

      // Wait a bit to ensure the operation doesn't execute
      await Future.delayed(Duration(milliseconds: 300));
      expect(operationExecuted, isFalse);
    });
  });
}
