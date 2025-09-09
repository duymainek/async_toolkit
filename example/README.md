# Async Toolkit Examples

This directory contains comprehensive examples demonstrating all features of the Async Toolkit package.

## 📁 Files

### `example.dart` - Main Examples
The primary example file showcasing all core features:

- **Cancellation Tokens** - API calls with user cancellation
- **Real-world API Example** - Multiple sequential API calls
- **Enhanced Cancellation** - Timeout vs cancellation detection
- **Timeout Control** - Various timeout strategies
- **Retry Logic** - Exponential and linear backoff
- **Parallel Execution** - Limited concurrent operations
- **Throttle & Debounce** - Basic usage patterns

### `throttle_debounce_example.dart` - Specialized Examples
Detailed examples focused on rate limiting:

- **Throttle Manager** - Caching and frequency control
- **Debounce Manager** - Delayed execution patterns
- **Real-world Search** - Practical search implementation

## 🚀 Running Examples

```bash
# Run main comprehensive examples
dart run example/example.dart

# Run detailed throttle/debounce examples
dart run example/throttle_debounce_example.dart
```

## 📋 What You'll Learn

### Cancellation Patterns
- How to create and use cancellation tokens
- Composite cancellation from multiple sources
- Proper resource cleanup and disposal
- Distinguishing between timeout and user cancellation

### Timeout Strategies
- Simple timeout with exceptions
- Timeout with default values
- Timeout returning null instead of throwing

### Retry Mechanisms
- Exponential backoff with jitter
- Linear backoff strategies
- Fixed delay between attempts
- Custom backoff functions

### Parallel Execution
- Limiting concurrent operations
- Ordered vs unordered results
- Callback-based result processing
- Memory-efficient implementations

### Rate Limiting
- Throttling expensive operations
- Debouncing rapid user input
- Global vs manager-based approaches
- Proper cleanup and disposal

## 💡 Key Concepts Demonstrated

- **Resource Management** - Always dispose of managers and sources
- **Error Handling** - Proper exception handling patterns
- **Performance** - Efficient concurrent execution
- **User Experience** - Responsive cancellation and rate limiting
- **Best Practices** - Real-world usage patterns

## 🎯 Expected Output

When you run the examples, you'll see:
- Progress indicators for long-running operations
- Clear cancellation and timeout messages
- Execution timing and performance metrics
- Resource cleanup confirmations
- Practical usage scenarios

These examples are designed to be educational and demonstrate production-ready patterns you can use in your own applications.