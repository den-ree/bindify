import Testing
@testable import Bindify

@Suite("BindifyStateChange Tests")
struct BindifyStateChangeTests {
  // MARK: - Test State

  struct TestState: BindifyState {
    var value: Int
  }

  // MARK: - Test Cases

  @Test("Initial state change has correct trigger")
  func testInitialStateChange() {
    let oldState = TestState(value: 0)
    let newState = TestState(value: 1)
    let change = BindifyStateChange(trigger: .storeConnection, oldState: oldState, newState: newState)

    #expect(change.trigger == .storeConnection)
    #expect(change.isInitial == true)
  }

  @Test("Store update has correct trigger")
  func testStoreUpdate() {
    let oldState = TestState(value: 0)
    let newState = TestState(value: 1)
    let change = BindifyStateChange(trigger: .storeUpdate, oldState: oldState, newState: newState)

    #expect(change.trigger == .storeUpdate)
    #expect(change.isInitial == false)
  }

  @Test("Action update has correct trigger")
  func testActionUpdate() {
    let oldState = TestState(value: 0)
    let newState = TestState(value: 1)
    let change = BindifyStateChange(trigger: .actionUpdate, oldState: oldState, newState: newState)

    #expect(change.trigger == .actionUpdate)
    #expect(change.isInitial == false)
  }

  @Test("State change detects value changes")
  func testStateChangeDetection() {
    let oldState = TestState(value: 0)
    let newState = TestState(value: 1)
    let change = BindifyStateChange(trigger: .storeUpdate, oldState: oldState, newState: newState)

    #expect(change.hasChanged == true)
    #expect(change.oldState.value == 0)
    #expect(change.newState.value == 1)
  }

  @Test("State change detects no changes")
  func testNoStateChange() {
    let state = TestState(value: 1)
    let change = BindifyStateChange(trigger: .storeUpdate, oldState: state, newState: state)

    #expect(change.hasChanged == false)
    #expect(change.oldState.value == change.newState.value)
  }

  @Test("State change preserves old and new state")
  func testStatePreservation() {
    let oldState = TestState(value: 0)
    let newState = TestState(value: 1)
    let change = BindifyStateChange(trigger: .storeUpdate, oldState: oldState, newState: newState)

    #expect(change.oldState.value == 0)
    #expect(change.newState.value == 1)
  }

  @Test("State change is equatable")
  func testStateChangeEquatable() {
    let oldState = TestState(value: 0)
    let newState = TestState(value: 1)

    let change1 = BindifyStateChange(trigger: .storeUpdate, oldState: oldState, newState: newState)
    let change2 = BindifyStateChange(trigger: .storeUpdate, oldState: oldState, newState: newState)
    let change3 = BindifyStateChange(trigger: .actionUpdate, oldState: oldState, newState: newState)

    #expect(change1 == change2)
    #expect(change1 != change3)
  }
}


