import 'dart:async';
import 'package:async_toolkit/async_toolkit.dart';

void main() async {
  print('🚦 Throttle & Debounce Example\n');

  // Example 1: Throttle
  await throttleExample();

  // Example 2: Debounce
  await debounceExample();

  // Example 3: Real-world search example
  await searchExample();
}

/// Example demonstrating throttle functionality
Future<void> throttleExample() async {
  print('=== Throttle Example ===');

  var callCount = 0;
  Future<String> expensiveOperation() async {
    callCount++;
    print('  🔄 Executing expensive operation (call #$callCount)');
    await Future.delayed(Duration(milliseconds: 100));
    return 'Result $callCount';
  }

  final throttleManager = ThrottleManager<String>(Duration(milliseconds: 500));

  try {
    print('📞 Making rapid calls...');

    // First call - executes immediately
    final result1 = await throttleManager.throttle(expensiveOperation);
    print('✅ Result 1: $result1');

    // Second call within throttle period - returns cached result
    final result2 = await throttleManager.throttle(expensiveOperation);
    print('✅ Result 2: $result2 (cached)');

    // Third call within throttle period - returns cached result
    final result3 = await throttleManager.throttle(expensiveOperation);
    print('✅ Result 3: $result3 (cached)');

    print('⏱️  Waiting for throttle period to expire...');
    await Future.delayed(Duration(milliseconds: 600));

    // Fourth call after throttle period - executes new operation
    final result4 = await throttleManager.throttle(expensiveOperation);
    print('✅ Result 4: $result4 (new execution)');

    print('📊 Total expensive operations executed: $callCount');
  } finally {
    throttleManager.reset();
  }

  print('');
}

/// Example demonstrating debounce functionality
Future<void> debounceExample() async {
  print('=== Debounce Example ===');

  var callCount = 0;
  Future<String> searchOperation() async {
    callCount++;
    print('  🔍 Executing search operation (call #$callCount)');
    await Future.delayed(Duration(milliseconds: 100));
    return 'Search result $callCount';
  }

  final debounceManager = DebounceManager<String>(Duration(milliseconds: 300));

  try {
    print('📞 Making rapid calls (simulating fast typing)...');

    // Rapid calls - only the last one should execute
    final future1 = debounceManager
        .debounce(searchOperation)
        .catchError((e) => 'Cancelled');
    print('📝 Call 1 scheduled');

    await Future.delayed(Duration(milliseconds: 50));
    final future2 = debounceManager
        .debounce(searchOperation)
        .catchError((e) => 'Cancelled');
    print('📝 Call 2 scheduled (cancels call 1)');

    await Future.delayed(Duration(milliseconds: 50));
    final future3 = debounceManager
        .debounce(searchOperation)
        .catchError((e) => 'Cancelled');
    print('📝 Call 3 scheduled (cancels call 2)');

    await Future.delayed(Duration(milliseconds: 50));
    final future4 = debounceManager.debounce(searchOperation);
    print('📝 Call 4 scheduled (cancels call 3)');

    // Wait for all futures to complete
    final results = await Future.wait([future1, future2, future3, future4]);

    print('📊 Results:');
    for (int i = 0; i < results.length; i++) {
      print('  Result ${i + 1}: ${results[i]}');
    }

    print('📊 Total search operations executed: $callCount');
  } finally {
    debounceManager.dispose();
  }

  print('');
}

/// Real-world example: Search with debounce
Future<void> searchExample() async {
  print('=== Real-world Search Example ===');

  final searchController = SearchController();

  try {
    print('🔍 Simulating user typing in search box...');

    // Simulate rapid typing
    await searchController.onSearchChanged('a');
    print('👤 User typed: "a"');

    await Future.delayed(Duration(milliseconds: 50));
    await searchController.onSearchChanged('ap');
    print('👤 User typed: "ap"');

    await Future.delayed(Duration(milliseconds: 50));
    await searchController.onSearchChanged('app');
    print('👤 User typed: "app"');

    await Future.delayed(Duration(milliseconds: 50));
    await searchController.onSearchChanged('appl');
    print('👤 User typed: "appl"');

    await Future.delayed(Duration(milliseconds: 50));
    await searchController.onSearchChanged('apple');
    print('👤 User typed: "apple"');

    // Wait for debounce to complete
    print('⏳ Waiting for search to complete...');
    await Future.delayed(Duration(milliseconds: 500));

    print('✅ Search completed! Only the final search was executed.');
  } finally {
    searchController.dispose();
  }

  print('');
}

/// Example search controller using debounce
class SearchController {
  final _debounceManager =
      DebounceManager<List<String>>(Duration(milliseconds: 300));
  var _searchCount = 0;

  Future<void> onSearchChanged(String query) async {
    if (query.isEmpty) return;

    try {
      final results =
          await _debounceManager.debounce(() => _performSearch(query));
      _updateUI(results);
    } catch (e) {
      if (e is! OperationCanceledException) {
        _handleError(e);
      }
    }
  }

  Future<List<String>> _performSearch(String query) async {
    _searchCount++;
    print('  🔍 Performing search #$_searchCount for: "$query"');

    // Simulate API call
    await Future.delayed(Duration(milliseconds: 100));

    return ['$query - Result 1', '$query - Result 2', '$query - Result 3'];
  }

  void _updateUI(List<String> results) {
    print('  📱 UI updated with ${results.length} results:');
    for (final result in results) {
      print('    • $result');
    }
  }

  void _handleError(dynamic error) {
    print('  ❌ Search error: $error');
  }

  void dispose() {
    _debounceManager.dispose();
  }
}
