import 'dart:async';
import '../cancellation/cancellation_token.dart';

/// Core function for running futures with limited parallelism.
///
/// This is the internal implementation that all public parallel functions use.
/// It handles the common logic of managing concurrent executions, cancellation,
/// and error handling.
Future<R> _runParallelCore<T, R>(
  List<Future<T>> futuresList,
  int maxParallel,
  CancellationToken? token,
  R Function() createResult,
  void Function(R result, T value, int index) onComplete,
  R Function(R result) finalizeResult,
) async {
  // Validate parameters
  if (maxParallel < 1) {
    throw ArgumentError('maxParallel must be at least 1');
  }

  if (futuresList.isEmpty) {
    return finalizeResult(createResult());
  }

  // Check for cancellation before starting
  token?.throwIfCancellationRequested();

  final result = createResult();
  int runningCount = 0;
  int nextIndex = 0;
  int completedCount = 0;

  final completer = Completer<R>();
  StreamSubscription? cancellationSubscription;

  // Set up cancellation listener
  if (token != null) {
    cancellationSubscription = token.cancellationStream.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          const OperationCanceledException('Parallel execution was cancelled'),
          StackTrace.current,
        );
      }
    });
  }

  void startNextFuture() {
    // Check for cancellation
    token?.throwIfCancellationRequested();

    if (nextIndex >= futuresList.length || runningCount >= maxParallel) {
      return; // No more futures to start or at max parallel
    }

    final currentIndex = nextIndex++;
    final future = futuresList[currentIndex];
    runningCount++;

    // Handle future completion and errors
    future.then((value) {
      runningCount--;
      completedCount++;

      // Process the result
      onComplete(result, value, currentIndex);

      if (completedCount == futuresList.length) {
        // All futures completed
        if (!completer.isCompleted) {
          cancellationSubscription?.cancel();
          completer.complete(finalizeResult(result));
        }
      } else {
        // Start next future if there are any waiting
        startNextFuture();
      }
    }).catchError((error, stackTrace) {
      // Future failed
      if (!completer.isCompleted) {
        cancellationSubscription?.cancel();
        completer.completeError(error, stackTrace);
      }
    });
  }

  void fillToMaxParallel() {
    // Start futures until we reach maxParallel or run out of futures
    while (runningCount < maxParallel && nextIndex < futuresList.length) {
      startNextFuture();
    }
  }

  // Start initial batch of futures
  fillToMaxParallel();

  try {
    return await completer.future;
  } finally {
    cancellationSubscription?.cancel();
  }
}

/// Runs futures with a limit on concurrent execution.
///
/// Only [maxParallel] futures will run concurrently. When a future completes,
/// the next one in the queue will start automatically.
///
/// Returns a list of results in the same order as the input futures.
/// If any future fails, the entire operation fails with that exception.
///
/// [futures] - The futures to execute
/// [maxParallel] - Maximum number of concurrent executions
/// [token] - Optional cancellation token
Future<List<T>> runLimitedParallel<T>(
  Iterable<Future<T>> futures, {
  int maxParallel = 3,
  CancellationToken? token,
}) async {
  final futuresList = futures.toList();

  return _runParallelCore<T, List<T>>(
    futuresList,
    maxParallel,
    token,
    // Create result: Initialize list with nulls (but cast to List<T>)
    () => List<T?>.filled(futuresList.length, null).cast<T>(),
    // On complete: Store result at correct index
    (results, value, index) => results[index] = value,
    // Finalize result: Return as-is (already List<T>)
    (results) => results,
  );
}

/// Runs futures with a limit on concurrent execution, collecting results as they complete.
///
/// Only [maxParallel] futures will run concurrently. Results are collected
/// in the order they complete, not the order of the input futures.
///
/// [futures] - The futures to execute
/// [maxParallel] - Maximum number of concurrent executions
/// [token] - Optional cancellation token
Future<List<T>> runLimitedParallelUnordered<T>(
  Iterable<Future<T>> futures, {
  int maxParallel = 3,
  CancellationToken? token,
}) async {
  final futuresList = futures.toList();

  return _runParallelCore<T, List<T>>(
    futuresList,
    maxParallel,
    token,
    // Create result: Empty list
    () => <T>[],
    // On complete: Add result to list (unordered)
    (results, value, index) => results.add(value),
    // Finalize result: Return as-is
    (results) => results,
  );
}

/// Runs futures with a limit on concurrent execution, processing results as they complete.
///
/// Only [maxParallel] futures will run concurrently. The [onResult] callback
/// is called for each result as it completes, in the order they complete.
///
/// [futures] - The futures to execute
/// [onResult] - Callback called for each completed result
/// [maxParallel] - Maximum number of concurrent executions
/// [token] - Optional cancellation token
Future<void> runLimitedParallelWithCallback<T>(
  Iterable<Future<T>> futures,
  void Function(T result) onResult, {
  int maxParallel = 3,
  CancellationToken? token,
}) async {
  final futuresList = futures.toList();

  await _runParallelCore<T, void>(
    futuresList,
    maxParallel,
    token,
    // Create result: Nothing to create for void
    () => null,
    // On complete: Call the user's callback
    (_, value, index) => onResult(value),
    // Finalize result: Return void
    (_) {},
  );
}
