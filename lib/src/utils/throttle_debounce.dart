import 'dart:async';
import '../cancellation/cancellation_token.dart'
    show OperationCanceledException;

/// A manager for throttling function executions.
///
/// Throttling ensures that a function is only executed once per specified duration.
/// The first call executes immediately, and subsequent calls within the duration
/// return the cached result from the first execution.
///
/// If an operation fails, the error is not cached and subsequent calls within
/// the throttle window will retry the operation.
class ThrottleManager<T> {
  final Duration _duration;
  DateTime? _lastExecutionTime;
  T? _cachedResult;
  Future<T>? _currentExecution;
  bool _disposed = false;

  /// Creates a new ThrottleManager with the specified duration.
  ThrottleManager(this._duration) {
    if (_duration.isNegative) {
      throw ArgumentError('duration cannot be negative, got $_duration');
    }
  }

  /// Throttles the execution of the given operation.
  ///
  /// If this is the first call or enough time has passed since the last execution,
  /// the operation will be executed immediately. Otherwise, returns the cached result.
  ///
  /// If an operation fails, the error is not cached and subsequent calls will retry.
  /// Throws [StateError] if the manager has been disposed.
  Future<T> throttle(Future<T> Function() operation) async {
    if (_disposed) {
      throw StateError('ThrottleManager has been disposed');
    }

    final now = DateTime.now();

    // If we have a cached result and we're still within the throttle duration
    if (_lastExecutionTime != null &&
        _cachedResult != null &&
        now.difference(_lastExecutionTime!) < _duration) {
      return _cachedResult as T;
    }

    // If there's already an execution in progress, wait for it
    final currentExecution = _currentExecution;
    if (currentExecution != null) {
      try {
        return await currentExecution;
      } catch (e) {
        // If the current execution fails, we don't cache the error
        // The next call will retry the operation
        rethrow;
      }
    }

    // Execute the operation
    _lastExecutionTime = now;
    _currentExecution = operation();

    try {
      final result = await _currentExecution!;

      // Only cache successful results
      if (!_disposed) {
        _cachedResult = result;
      }

      return result;
    } catch (e) {
      // Don't cache errors - reset cache and timing to allow immediate retry
      if (!_disposed) {
        _cachedResult = null;
        _lastExecutionTime = null;
      }
      rethrow;
    } finally {
      if (!_disposed) {
        _currentExecution = null;
      }
    }
  }

  /// Clears the cached result and resets the throttle state.
  /// Throws [StateError] if the manager has been disposed.
  void reset() {
    if (_disposed) {
      throw StateError('ThrottleManager has been disposed');
    }
    _lastExecutionTime = null;
    _cachedResult = null;
    _currentExecution = null;
  }

  /// Disposes this throttle manager and releases all resources.
  ///
  /// After calling dispose, this manager cannot be used anymore.
  /// Any ongoing operations will continue to run but their results won't be cached.
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _lastExecutionTime = null;
    _cachedResult = null;
    _currentExecution = null;
  }

  /// Whether this manager has been disposed.
  bool get isDisposed => _disposed;
}

/// A manager for debouncing function executions.
///
/// Debouncing waits for a pause in calls before executing the function.
/// Each new call cancels the previous one, and only the last call
/// will be executed after the specified duration.
class DebounceManager<T> {
  final Duration _duration;
  Timer? _timer;
  Completer<T>? _completer;
  bool _disposed = false;

  /// Creates a new DebounceManager with the specified duration.
  DebounceManager(this._duration) {
    if (_duration.isNegative) {
      throw ArgumentError('duration cannot be negative, got $_duration');
    }
  }

  /// Debounces the execution of the given operation.
  ///
  /// Each call to this method will cancel any previous pending execution
  /// and schedule a new one after the debounce duration.
  /// Throws [StateError] if the manager has been disposed.
  Future<T> debounce(Future<T> Function() operation) {
    if (_disposed) {
      throw StateError('DebounceManager has been disposed');
    }
    // Cancel any existing timer and completer
    _timer?.cancel();
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError(OperationCanceledException(
          'Debounced operation was cancelled by a new call'));
    }

    // Create a new completer for this execution
    _completer = Completer<T>();

    // Schedule the execution after the debounce duration
    _timer = Timer(_duration, () async {
      if (_completer != null && !_completer!.isCompleted) {
        try {
          final result = await operation();
          if (!_completer!.isCompleted) {
            _completer!.complete(result);
          }
        } catch (error) {
          if (!_completer!.isCompleted) {
            _completer!.completeError(error);
          }
        }
      }
    });

    return _completer!.future;
  }

  /// Cancels any pending debounced operation.
  /// Throws [StateError] if the manager has been disposed.
  void cancel() {
    if (_disposed) {
      throw StateError('DebounceManager has been disposed');
    }
    _timer?.cancel();
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError(
          OperationCanceledException('Debounced operation was cancelled'));
    }
    _timer = null;
    _completer = null;
  }

  /// Disposes of this debounce manager and cancels any pending operations.
  ///
  /// After calling dispose, this manager cannot be used anymore.
  /// Any ongoing operations will be cancelled.
  void dispose() {
    if (_disposed) return;

    // Cancel any pending operations before setting disposed flag
    _timer?.cancel();
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError(OperationCanceledException(
          'Debounced operation was cancelled due to disposal'));
    }

    _disposed = true;
    _timer = null;
    _completer = null;
  }

  /// Whether this manager has been disposed.
  bool get isDisposed => _disposed;
}

// Using OperationCanceledException from cancellation_token.dart

// Global throttle and debounce managers for one-off usage
final Map<String, ThrottleManager> _globalThrottleManagers = {};
final Map<String, DebounceManager> _globalDebounceManagers = {};

/// Internal utility function to get or create a manager from global registry.
///
/// This eliminates code duplication between throttle and debounce global functions.
T _getManager<T>(
  Map<String, T> registry,
  String? key,
  Duration duration,
  String typeString,
  Function operation,
  T Function(Duration) createManager,
) {
  // Validate duration parameter
  if (duration.isNegative) {
    throw ArgumentError('duration cannot be negative, got $duration');
  }

  final effectiveKey = key ??
      '${typeString}_${duration.inMilliseconds}_${operation.runtimeType}_${operation.hashCode}';

  return registry.putIfAbsent(effectiveKey, () => createManager(duration));
}

/// Global function to throttle an operation.
///
/// **Warning**: This function uses a global manager registry. Different operations
/// with the same return type and duration may share the same throttle state unless
/// you provide a unique [key].
///
/// This creates a temporary throttle manager for one-off usage.
/// For repeated use with the same duration, consider using [ThrottleManager] directly.
///
/// [operation] - The operation to throttle
/// [duration] - The throttle duration
/// [key] - Optional unique key to isolate this throttle from others.
///         If not provided, a key is generated from type and duration.
Future<T> throttle<T>(
  Future<T> Function() operation,
  Duration duration, {
  String? key,
}) {
  final manager = _getManager<ThrottleManager>(
    _globalThrottleManagers,
    key,
    duration,
    T.toString(),
    operation,
    (duration) => ThrottleManager<T>(duration),
  ) as ThrottleManager<T>;

  return manager.throttle(operation);
}

/// Global function to debounce an operation.
///
/// **Warning**: This function uses a global manager registry. Different operations
/// with the same return type and duration may share the same debounce state unless
/// you provide a unique [key].
///
/// This creates a temporary debounce manager for one-off usage.
/// For repeated use with the same duration, consider using [DebounceManager] directly.
///
/// [operation] - The operation to debounce
/// [duration] - The debounce duration
/// [key] - Optional unique key to isolate this debounce from others.
///         If not provided, a key is generated from type and duration.
Future<T> debounce<T>(
  Future<T> Function() operation,
  Duration duration, {
  String? key,
}) {
  final manager = _getManager<DebounceManager>(
    _globalDebounceManagers,
    key,
    duration,
    T.toString(),
    operation,
    (duration) => DebounceManager<T>(duration),
  ) as DebounceManager<T>;

  return manager.debounce(operation);
}

/// Clears all global throttle and debounce managers.
///
/// This properly disposes of all managers and clears their resources.
/// This is useful for cleaning up resources in tests or when
/// you want to reset all global throttle/debounce state.
void clearGlobalManagers() {
  // Dispose throttle managers
  for (final manager in _globalThrottleManagers.values) {
    manager.dispose();
  }

  // Dispose debounce managers
  for (final manager in _globalDebounceManagers.values) {
    manager.dispose();
  }

  _globalThrottleManagers.clear();
  _globalDebounceManagers.clear();
}
