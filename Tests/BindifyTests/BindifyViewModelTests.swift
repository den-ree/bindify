import Testing
import Foundation
import Combine
@testable import Bindify

@Suite("BindifyViewModel Tests")
struct BindifyViewModelTests {
  // MARK: - Test Types

  struct TestStoreState: BindifyStoreState {
    var count: Int
    var isEnabled: Bool

    init(count: Int = 0, isEnabled: Bool = false) {
      self.count = count
      self.isEnabled = isEnabled
    }
  }

  struct TestViewState: BindifyViewState {
    init() {
      self.init(count: 0, isEnabled: false)
    }
    
    var count: Int = 0
    var isEnabled: Bool = false
    var derivedValue: String = ""

    init(count: Int = 0, isEnabled: Bool = false) {
      self.count = count
      self.isEnabled = isEnabled
      self.derivedValue = "Count: \(count)"
    }
  }

  enum TestAction: Equatable {
    case increment
    case toggle
    case updateCount(Int)
    case updateStore
  }

  class TestContext: BindifyContext {
    typealias StoreState = TestStoreState

    let store: BindifyStore<TestStoreState>

    init(initialState: TestStoreState = TestStoreState()) {
      self.store = BindifyStore(initialState)
    }
  }

  class TestViewModel: BindifyViewModel<TestContext, TestViewState, TestAction> {
    var willChangeCallCount = 0
    var didChangeCallCount = 0
    var lastWillChangeTrigger: BindifyStateChange<TestViewState>.Trigger?
    var lastDidChangeTrigger: BindifyStateChange<TestViewState>.Trigger?

    func resetCallCounts() {
      willChangeCallCount = 0
      didChangeCallCount = 0
    }

    override func scopeStateOnAction(
      _ action: TestAction,
      _ newState: inout TestViewState
    ) -> ((inout TestStoreState) -> Void)? {
      switch action {
      case .increment:
        newState.count += 1
        newState.derivedValue = "Count: \(newState.count)"
        return nil

      case .toggle:
        newState.isEnabled.toggle()
        return nil

      case .updateCount(let count):
        newState.count = count
        newState.derivedValue = "Count: \(count)"
        return nil

      case .updateStore:
        let newCount = newState.count
        let newIsEnabled = newState.isEnabled
        return { state in
          state.count = newCount
          state.isEnabled = newIsEnabled
        }
      }
    }

    override func scopeStateOnStoreChange(
      _ storeState: TestStoreState,
      _ newState: inout TestViewState
    ) {
      newState.count = storeState.count
      newState.isEnabled = storeState.isEnabled
      newState.derivedValue = "Count: \(storeState.count)"
    }

    override func onStateWillChange(_ change: BindifyStateChange<TestViewState>) {
      willChangeCallCount += 1
      lastWillChangeTrigger = change.trigger
    }

    override func onStateDidChange(_ change: BindifyStateChange<TestViewState>) async {
      didChangeCallCount += 1
      lastDidChangeTrigger = change.trigger
    }
  }

  // MARK: - Test Cases

  @Test("ViewModel initializes with correct initial state")
  func testViewModelInitialization() async {
    let context = TestContext()
    let viewModel = await TestViewModel(context)

    #expect(viewModel.viewState.count == 0)
    #expect(viewModel.viewState.isEnabled == false)
    #expect(viewModel.viewState.derivedValue == "Count: 0")
  }

  @Test("ViewModel handles local state updates")
  func testLocalStateUpdates() async {
    let context = TestContext()
    let viewModel = await TestViewModel(context)

    // Test increment action
    await viewModel.onAction(.increment)
    #expect(viewModel.viewState.count == 1)
    #expect(viewModel.viewState.derivedValue == "Count: 1")

    // Test toggle action
    await viewModel.onAction(.toggle)
    #expect(viewModel.viewState.isEnabled == true)

    // Test direct count update
    await viewModel.onAction(.updateCount(5))
    #expect(viewModel.viewState.count == 5)
    #expect(viewModel.viewState.derivedValue == "Count: 5")
  }

  @Test("ViewModel updates store state")
  func testStoreStateUpdates() async {
    let context = TestContext()
    let viewModel = await TestViewModel(context)

    // Update local state
    await viewModel.onAction(.updateCount(10))
    await viewModel.onAction(.toggle)

    // Update store
    await viewModel.onAction(.updateStore)

    try? await Task.sleep(for: .milliseconds(200))

    let storeState = await context.store.state
    #expect(storeState.count == 10)
    #expect(storeState.isEnabled == true)
  }

  @Test("ViewModel reflects store state changes")
  func testStoreStateReflection() async {
    let context = TestContext()
    let viewModel = await TestViewModel(context)

    // Update store directly
    await context.store.update { state in
      state.count = 15
      state.isEnabled = true
    }

    try? await Task.sleep(for: .milliseconds(200))

    #expect(viewModel.viewState.count == 15)
    #expect(viewModel.viewState.isEnabled == true)
    #expect(viewModel.viewState.derivedValue == "Count: 15")
  }

  @Test("ViewModel lifecycle hooks are called correctly")
  func testLifecycleHooks() async {
    let context = TestContext()
    let viewModel = await TestViewModel(context)

    try? await Task.sleep(for: .milliseconds(200))

    // initial updates
    #expect(viewModel.willChangeCallCount == 1)
    #expect(viewModel.didChangeCallCount == 1)

    // Test local state update
    await viewModel.onAction(.increment)

    try? await Task.sleep(for: .milliseconds(200))

    #expect(viewModel.willChangeCallCount == 2)
    #expect(viewModel.didChangeCallCount == 2)
    #expect(viewModel.lastWillChangeTrigger == .actionUpdate)
    #expect(viewModel.lastDidChangeTrigger == .actionUpdate)

    // Test store update
    await context.store.update { state in
      state.count = 20
    }

    try? await Task.sleep(for: .milliseconds(200))

    #expect(viewModel.willChangeCallCount == 3)
    #expect(viewModel.didChangeCallCount == 3)
    #expect(viewModel.lastWillChangeTrigger == .storeUpdate)
    #expect(viewModel.lastDidChangeTrigger == .storeUpdate)
  }

  @Test("ViewModel handles multiple rapid updates")
  func testRapidUpdates() async {
    let context = TestContext()
    let viewModel = await TestViewModel(context)

    try? await Task.sleep(for: .milliseconds(200))

    viewModel.resetCallCounts()

    // Perform rapid local updates
    for i in 1...5 {
      await viewModel.onAction(.updateCount(i))
    }

    try? await Task.sleep(for: .milliseconds(200))

    #expect(viewModel.viewState.count == 5)
    #expect(viewModel.willChangeCallCount == 5)
    #expect(viewModel.didChangeCallCount == 5)

    // Perform rapid store updates
    for i in 6...10 {
      await context.store.update { state in
        state.count = i
      }
    }

    try? await Task.sleep(for: .milliseconds(200))

    #expect(viewModel.viewState.count == 10)
    #expect(viewModel.willChangeCallCount == 10)
    #expect(viewModel.didChangeCallCount == 10)
  }

  @Test("ViewModel maintains state consistency during concurrent updates")
  func testConcurrentUpdates() async {
    let context = TestContext()
    let viewModel = await TestViewModel(context)

    // Perform concurrent local and store updates
    for i in 1...5 {
      Task {
        await viewModel.onAction(.updateCount(i))
      }

      Task {
        await context.store.update { state in
          state.count = i + 5
        }
      }
    }

    try? await Task.sleep(for: .milliseconds(500))

    let finalCount = viewModel.viewState.count
    #expect(finalCount >= 5 && finalCount <= 10)
    #expect(viewModel.willChangeCallCount > 0)
    #expect(viewModel.didChangeCallCount > 0)
  }

  @Test("ViewModel cleanup cancels subscriptions")
  func testCleanup() async {
    let context = TestContext()
    var viewModel: TestViewModel? = await TestViewModel(context)

    // Perform some updates
    await viewModel?.onAction(.updateCount(5))
    await context.store.update { state in
      state.count = 10
    }

    try? await Task.sleep(for: .milliseconds(200))

    // Deallocate view model
    viewModel = nil

    // Verify store updates don't cause crashes
    await context.store.update { state in
      state.count = 15
    }

    try? await Task.sleep(for: .milliseconds(200))
  }

  @Test("ViewModel handles state transitions gracefully")
  func testStateTransitions() async {
    let context = TestContext()
    let viewModel = await TestViewModel(context)

    try? await Task.sleep(for: .milliseconds(200))

    viewModel.resetCallCounts()

    // Test state transitions with various values
    await viewModel.onAction(.updateCount(-1))
    #expect(viewModel.viewState.count == -1)
    #expect(viewModel.viewState.derivedValue == "Count: -1")
    
    // Test rapid state changes
    for i in 0..<5 {
      await viewModel.onAction(.updateCount(i * -1))
    }
    #expect(viewModel.viewState.count == -4) // Last value in the loop
    #expect(viewModel.viewState.derivedValue == "Count: -4")
    
    // Test toggle state
    await viewModel.onAction(.toggle)
    #expect(viewModel.viewState.isEnabled == true)
    
    // Test store state update
    await viewModel.onAction(.updateStore)
    try? await Task.sleep(for: .milliseconds(200))
    let storeState = await context.store.state
    #expect(storeState.count == -4)
    #expect(storeState.isEnabled == true)
  }

  @Test("ViewModel maintains consistency with complex state structures")
  func testComplexStateStructures() async {
    struct ComplexViewState: BindifyViewState {
      var nestedData: [String: [String: Int]]
      var derivedValues: [String: String]
      
      init() {
        self.nestedData = [:]
        self.derivedValues = [:]
      }
    }
    
    class ComplexViewModel: BindifyViewModel<TestContext, ComplexViewState, TestAction> {
      override func scopeStateOnAction(
        _ action: TestAction,
        _ newState: inout ComplexViewState
      ) -> ((inout TestStoreState) -> Void)? {
        switch action {
        case .updateCount(let count):
          newState.nestedData["level1"] = ["level2": count]
          newState.derivedValues["computed"] = "Value: \(count)"
          return nil
        default:
          return nil
        }
      }
      
      override func scopeStateOnStoreChange(
        _ storeState: TestStoreState,
        _ newState: inout ComplexViewState
      ) {
        newState.nestedData["level1"] = ["level2": storeState.count]
        newState.derivedValues["computed"] = "Value: \(storeState.count)"
      }
    }
    
    let context = TestContext()
    let viewModel = await ComplexViewModel(context)
    
    // Test complex state updates
    for i in 0..<5 {
      await viewModel.onAction(.updateCount(i))
      #expect(viewModel.viewState.nestedData["level1"]?["level2"] == i)
      #expect(viewModel.viewState.derivedValues["computed"] == "Value: \(i)")
    }
  }

  @Test("ViewModel handles rapid state changes at limits")
  func testRapidStateChangesAtLimits() async {
    let context = TestContext()
    let viewModel = await TestViewModel(context)
    let updateCount = 100
    let startTime = Date()
    
    // Perform rapid updates
    for i in 0..<updateCount {
      await viewModel.onAction(.updateCount(i))
    }
    
    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)
    
    #expect(viewModel.viewState.count == updateCount - 1)
    #expect(duration < 1.0) // Should complete within 1 second
  }

  @Test("ViewModel maintains memory efficiency with long lifecycle")
  func testMemoryEfficiency() async {
    let context = TestContext()
    let viewModel = await TestViewModel(context)
    let iterationCount = 50

    // Perform many state changes
    for i in 0..<iterationCount {
      await viewModel.onAction(.updateCount(i))
      await viewModel.onAction(.toggle)
    }

    try? await Task.sleep(for: .milliseconds(200))

    // Verify state consistency
    #expect(viewModel.viewState.count == iterationCount - 1)
    #expect(viewModel.willChangeCallCount == iterationCount * 2)
    #expect(viewModel.didChangeCallCount == iterationCount * 2)
  }

  @Test("ViewModel handles resource cleanup under pressure")
  func testResourceCleanupUnderPressure() async {
    let context = TestContext()
    var viewModel: TestViewModel? = await TestViewModel(context)
    
    // Create many state changes
    for i in 0..<100 {
      await viewModel?.onAction(.updateCount(i))
      await viewModel?.onAction(.toggle)
    }
    
    // Deallocate view model under pressure
    viewModel = nil
    
    // Verify store updates don't cause crashes
    await context.store.update { state in
      state.count = 200
      state.isEnabled = true
    }
    
    try? await Task.sleep(for: .milliseconds(200))
  }

  @Test("ViewModel maintains consistency with nested state updates")
  func testNestedStateUpdates() async {
    let context = TestContext()
    let viewModel = await TestViewModel(context)
    
    // Perform nested state updates
    await viewModel.onAction(.updateCount(5))
    await viewModel.onAction(.toggle)
    await viewModel.onAction(.updateStore)
    
    try? await Task.sleep(for: .milliseconds(200))
    
    let storeState = await context.store.state
    #expect(viewModel.viewState.count == storeState.count)
    #expect(viewModel.viewState.isEnabled == storeState.isEnabled)
    #expect(viewModel.viewState.derivedValue == "Count: \(storeState.count)")
  }
}

