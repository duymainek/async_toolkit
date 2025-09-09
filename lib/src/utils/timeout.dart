import 'dart:async';
import '../cancellation/cancellation_token.dart';

/// Runs a future with a timeout and optional cancellation support.
///
/// If the future completes before the timeout, returns its result.
/// If the timeout expires, throws a [TimeoutException].
/// If cancellation is requested, throws an [OperationCanceledException].
///
/// **Note**: The original future continues to run in the background even after
/// timeout or cancellation. This is a limitation of Dart's Future system where
/// futures cannot be truly cancelled once started.
Future<T> withTimeout<T>(
  Future<T> future,
  Duration duration, {
  CancellationToken? token,
}) async {
  // Validate duration parameter
  if (duration.isNegative) {
    throw ArgumentError('duration cannot be negative, got $duration');
  }

  // Check for cancellation before starting
  token?.throwIfCancellationRequested();

  // If no cancellation token, use the simple built-in timeout
  if (token == null) {
    return future.timeout(duration);
  }

  // With cancellation token, use Future.any to race between
  // the original future and the cancellation
  final futures = <Future<T>>[
    future,
    token.whenCancelled().then<T>((_) {
      throw const OperationCanceledException('Operation was cancelled');
    }),
  ];

  // Apply timeout to the race between future and cancellation
  return Future.any(futures).timeout(duration);
}

/// Runs a future with a timeout, returning null instead of throwing on timeout.
///
/// If the future completes before the timeout, returns its result.
/// If the timeout expires, returns null.
/// If cancellation is requested, throws an [OperationCanceledException].
Future<T?> withTimeoutOrNull<T>(
  Future<T> future,
  Duration duration, {
  CancellationToken? token,
}) async {
  try {
    return await withTimeout(future, duration, token: token);
  } on TimeoutException {
    return null;
  }
}

/// Runs a future with a timeout and a default value on timeout.
///
/// If the future completes before the timeout, returns its result.
/// If the timeout expires, returns the provided default value.
/// If cancellation is requested, throws an [OperationCanceledException].
Future<T> withTimeoutOrDefault<T>(
  Future<T> future,
  Duration duration,
  T defaultValue, {
  CancellationToken? token,
}) async {
  try {
    return await withTimeout(future, duration, token: token);
  } on TimeoutException {
    return defaultValue;
  }
}
