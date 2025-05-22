# ``Bindify``

A modern state management solution for Swift applications.

## Overview

Bindify is a lightweight, type-safe state management library that provides a simple and efficient way to manage application state in Swift applications. It combines the power of Swift's actor model with Combine to deliver a robust state management solution.

## Core Components

### State Management

- ``BindifyStore`` - The central store that manages application state
- ``BindifyState`` - Protocol for defining state types
- ``BindifyStoreState`` - Protocol for store-compatible state types

### View Integration

- ``BindifyView`` - SwiftUI view wrapper for Bindify integration
- ``BindifyViewModel`` - View model for managing view-specific state
- ``BindifyContext`` - Environment object for accessing the store

## Usage

Here's a simple example of how to use Bindify in your application:

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

## Requirements

- iOS 16.0+
- macOS 13.0+
- Swift 5.9+ 