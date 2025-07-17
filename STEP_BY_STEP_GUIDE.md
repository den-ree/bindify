# Agent Guide: Generating Screens with Bindify, Context, and Coordinator

This guide outlines the steps an agent should follow to generate new screens for an app using the Bindify architecture. Screens must connect to a context that provides access to a coordinator, which orchestrates navigation and flow.

## 1. Define the Context with Coordinator Access

- Create a context struct/class conforming to `BindifyContext`.
- Add a reference to the coordinator (e.g., `let coordinator: AppCoordinator`).
- Expose the store as required by Bindify.

```swift
final class FeatureContext: BindifyContext {
    let store: BindifyStore<FeatureStoreState>
    let coordinator: AppCoordinator

    init(initialState: FeatureStoreState = .init(), coordinator: AppCoordinator) {
        self.store = BindifyStore(initialState)
        self.coordinator = coordinator
    }
}
```

## 2. Create the ViewModel

- Subclass `BindifyViewModel<Context, ViewState>`.
- Implement `scopeStateOnStoreChange` to map store state to view state.
- Add methods for local state updates, store updates, and navigation via the coordinator.
- Use `sideEffect` for async work or to synchronize state/store.

```swift
final class FeatureViewModel: BindifyViewModel<FeatureContext, FeatureViewModel.State> {
    struct State: BindifyViewState {
        var value: String = ""
        init() {}
    }

    override func scopeStateOnStoreChange(_ storeState: FeatureStoreState) async {
        await updateState { state in
            state.value = storeState.value
        }
    }

    @MainActor
    func onNextTapped() {
        context.coordinator.navigateToNextScreen()
    }
}
```

## 3. Build the View

- Conform to `BindifyView`.
- Use `@StateObject var viewModel: FeatureViewModel`.
- Bind UI elements to view state using `bindTo`.
- Call view model methods for actions and navigation.

```swift
struct FeatureView: BindifyView {
    @StateObject var viewModel: FeatureViewModel
    init(_ context: FeatureContext) {
        _viewModel = .init(wrappedValue: .init(context))
    }
    var body: some View {
        VStack {
            TextField("Value", text: bindTo(\.value) { viewModel.updateValue($0) })
            Button("Next") { viewModel.onNextTapped() }
        }
    }
}
```

## 4. Integrate with the Coordinator

- The coordinator should own the navigation logic and create contexts for each screen.
- When navigating, instantiate the next screen with a context that includes the coordinator.

```swift
final class AppCoordinator {
    func navigateToNextScreen() {
        // e.g., push FeatureView(FeatureContext(..., coordinator: self))
    }
}
```

## 5. Best Practices

- Keep business logic in the view model, not the view.
- Use `sideEffect` for async work or when you need to access the latest state before updating the store or navigating.
- Always pass the coordinator through the context for navigation.
- Use `@MainActor` for all UI and state update methods.

---

## Why Context Should Keep the Coordinator

**The context should keep a reference to the coordinator, not the other way around.**

- The context is designed to provide dependencies (store, services, coordinator, etc.) to the view model.
- The coordinator is responsible for navigation and orchestration at the app or flow level.
- If the coordinator kept the context, it would create a circular dependency and make the architecture less modular and harder to test.

**Pattern:**
- Context owns coordinator: The context is injected with a reference to the coordinator when created.
- ViewModel gets coordinator via context: The view model accesses the coordinator through its context property.

**Example:**
```swift
final class FeatureContext: BindifyContext {
    let store: BindifyStore<FeatureStoreState>
    let coordinator: AppCoordinator
    init(initialState: FeatureStoreState = .init(), coordinator: AppCoordinator) {
        self.store = BindifyStore(initialState)
        self.coordinator = coordinator
    }
}

final class FeatureViewModel: BindifyViewModel<FeatureContext, FeatureViewModel.State> {
    @MainActor
    func onNextTapped() {
        context.coordinator.navigateToNextScreen()
    }
}
```

**Summary:**
- Context should keep the coordinator.
- ViewModel should access the coordinator via its context.
- This keeps dependencies clear, avoids cycles, and follows DI best practices.

---

This guide ensures generated screens are modular, testable, and follow the Bindify + Coordinator architecture for scalable navigation and state management. 