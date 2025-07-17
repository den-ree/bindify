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
    .package(url: "https://github.com/den-ree/Bindify", branch: "main")
]
```

## Usage

Bindify enables a clean separation of local (view) state and global (store) state, with support for side effects. Here are the recommended patterns:

### 1. Update Local View State

Use `updateState` to update only the view's local state:

```swift
@MainActor
func updateTitle(_ title: String) {
    updateState { state in
        state.title = title
    }
}
```

### 2. Update the Store

Use `updateStore` to mutate the global store state:

```swift
@MainActor
func selectEntry(_ entry: Entry) {
    updateStore { storeState in
        storeState.selectedEntry = entry
    }
}
```

### 3. Combine State Update and Store Update with Side Effects

Chain `.sideEffect` after `updateState` to perform async work or update the store in response to a local state change:

```swift
@MainActor
func finishEditing(save: Bool) {
    guard save else {
        updateState { state in
            state.isEditing = false
        }.sideEffect { [weak self] _ in
            self?.updateStore { $0.selectedEntry = nil }
        }
        return
    }

    updateState { state in
        state.savingStatus = .saving
    }.sideEffect { [weak self] change in
        guard let self, change.hasChanged else { return }
        // Simulate async save
        try? await Task.sleep(for: .seconds(2))
        self.updateStore { $0.selectedEntry = nil }
    }
}
```

### 4. Get State for Store Update

Use `sideEffect` to access the latest local state and then update the store. This is useful when you need to synchronize the store with the most recent view state, for example after a user action or form submission.

```swift
@MainActor
func finishEditing(save: Bool) {
   sideEffect { [weak self] state in 
        self.updateStore { $0.selectedEntry = state.entry }
    }
}
```

### 5. Use in SwiftUI Views

BindifyView provides helpers for binding state and dispatching actions:

```swift
struct EntryView: BindifyView {
    @StateObject var viewModel: EntryViewModel
    // ...
    var body: some View {
        TextField("Title", text: bindTo(\.title) { viewModel.updateTitle($0) })
        Button("Save") { viewModel.finishEditing(save: true) }
    }
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
