import 'dart:async';

/// Represents the reason why a cancellation-related operation completed.
enum CancellationCompletionReason {
  /// The operation completed because cancellation was requested.
  cancelled,

  /// The operation completed because the timeout duration elapsed.
  timeout,
}

/// Exception thrown when an operation is cancelled.
class OperationCanceledException implements Exception {
  final String message;

  const OperationCanceledException([this.message = 'Operation was cancelled']);

  @override
  String toString() => 'OperationCanceledException: $message';
}

/// A token that can be used to cancel operations.
class CancellationToken {
  final Stream<void> _cancellationStream;
  bool _isCancellationRequested = false;

  CancellationToken.internal(this._cancellationStream);

  /// Whether cancellation has been requested.
  bool get isCancellationRequested => _isCancellationRequested;

  /// Stream that emits when cancellation is requested.
  Stream<void> get cancellationStream => _cancellationStream;

  /// Throws [OperationCanceledException] if cancellation has been requested.
  void throwIfCancellationRequested() {
    if (_isCancellationRequested) {
      throw const OperationCanceledException();
    }
  }

  /// Registers a callback to be called when cancellation is requested.
  void registerCallback(void Function() callback) {
    _cancellationStream.listen((_) => callback());
  }

  /// Creates a future that completes when cancellation is requested.
  Future<void> whenCancelled() {
    if (_isCancellationRequested) {
      return Future.value();
    }
    return _cancellationStream.first;
  }

  /// Creates a future that completes when cancellation is requested or after a timeout.
  /// Returns the reason for completion (cancelled or timeout).
  Future<CancellationCompletionReason> whenCancelledOrTimeout(
      Duration timeout) {
    if (_isCancellationRequested) {
      return Future.value(CancellationCompletionReason.cancelled);
    }

    return Future.any([
      _cancellationStream.first
          .then((_) => CancellationCompletionReason.cancelled),
      Future.delayed(timeout).then((_) => CancellationCompletionReason.timeout),
    ]);
  }

  /// Creates a future that completes when cancellation is requested or after a timeout.
  /// Throws [TimeoutException] on timeout, completes normally on cancellation.
  /// This method is provided for backward compatibility.
  @Deprecated(
      'Use whenCancelledOrTimeout() which returns completion reason instead')
  Future<void> whenCancelledOrTimeoutLegacy(Duration timeout) {
    if (_isCancellationRequested) {
      return Future.value();
    }
    return _cancellationStream.first.timeout(timeout);
  }

  /// Sets the cancellation requested flag. This is package-private and should only be called by CancellationTokenSource.
  void setCancellationRequested() {
    _isCancellationRequested = true;
  }
}
