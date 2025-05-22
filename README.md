# Bindify

A modern state management solution for Swift applications.

## Features

- **State Management**: Simple and efficient state management using a store-based approach
- **View Models**: Built-in support for view models with state transformation
- **Type Safety**: Fully type-safe implementation
- **SwiftUI Integration**: Seamless integration with SwiftUI views
- **Testability**: Easy to test with clear separation of concerns

## Requirements

- iOS 16.0+ / macOS 13.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/Bindify.git", from: "1.0.0")
]
```

## Quick Start

```swift
// Define your state
struct AppState: BindifyStoreState {
    var count: Int = 0
    var isAuthenticated: Bool = false
}

// Create a store
let store = BindifyStore(AppState())

// Subscribe to changes
let subscription = await store.subscribe { old, new in
    print("State changed from \(old) to \(new)")
}

// Update state
await store.update { state in
    state.count += 1
    state.isAuthenticated = true
}
```

## Documentation

For detailed documentation, including:
- Complete API reference
- Architecture overview
- Best practices
- Testing guidelines
- Advanced usage examples

Please visit our [Documentation](Sources/Bindify/Bindify.docc/Documentation.md).

## License

This project is licensed under the MIT License - see the LICENSE file for details.
