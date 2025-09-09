import 'dart:async';
import 'cancellation_token.dart';

/// A source for creating and controlling cancellation tokens.
class CancellationTokenSource {
  final StreamController<void> _controller = StreamController<void>.broadcast();
  late final CancellationToken _token;
  bool _isDisposed = false;
  List<StreamSubscription<void>>? _subscriptions;

  CancellationTokenSource() {
    _token = CancellationToken.internal(_controller.stream);
  }

  /// The cancellation token associated with this source.
  CancellationToken get token => _token;

  /// Whether cancellation has been requested.
  bool get isCancellationRequested => _token.isCancellationRequested;

  /// Whether this source has been disposed.
  bool get isDisposed => _isDisposed;

  /// Requests cancellation of all operations associated with this token.
  void cancel() {
    if (_isDisposed) {
      throw StateError('Cannot cancel a disposed CancellationTokenSource');
    }

    if (!_token.isCancellationRequested) {
      _token.setCancellationRequested();
      _controller.add(null);
    }
  }

  /// Creates a new CancellationTokenSource that will be cancelled after the specified duration.
  factory CancellationTokenSource.withTimeout(Duration duration) {
    if (duration.isNegative) {
      throw ArgumentError('duration cannot be negative, got $duration');
    }

    final source = CancellationTokenSource();
    Timer(duration, () {
      if (!source.isDisposed) {
        source.cancel();
      }
    });
    return source;
  }

  /// Creates a new CancellationTokenSource that will be cancelled when any of the provided tokens are cancelled.
  factory CancellationTokenSource.any(Iterable<CancellationToken> tokens) {
    final source = CancellationTokenSource();
    final subscriptions = <StreamSubscription<void>>[];

    for (final token in tokens) {
      // If any token is already cancelled, cancel immediately
      if (token.isCancellationRequested) {
        source.cancel();
        break;
      }

      // Subscribe to each token's cancellation stream
      final subscription = token.cancellationStream.listen((_) {
        if (!source.isDisposed && !source.isCancellationRequested) {
          source.cancel();
        }
      });
      subscriptions.add(subscription);
    }

    // Store subscriptions for cleanup on disposal
    source._subscriptions = subscriptions;

    return source;
  }

  /// Disposes this cancellation token source and releases all resources.
  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;

      // Cancel all subscriptions from CancellationTokenSource.any
      if (_subscriptions != null) {
        for (final subscription in _subscriptions!) {
          subscription.cancel();
        }
        _subscriptions = null;
      }

      _controller.close();
    }
  }
}
