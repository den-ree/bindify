import Testing
import Combine
import Foundation

@testable import Bindify

@Suite("BindifyStore Tests")
struct BindifyStoreTests {
  // MARK: - Test State

  struct TestState: BindifyStoreState {
    var count: Int
    var isEnabled: Bool

    init(count: Int = 0, isEnabled: Bool = false) {
      self.count = count
      self.isEnabled = isEnabled
    }
  }

  // MARK: - Test Cases

  @Test("Store initializes with correct initial state")
  func testStoreInitialization() async {
    let initialState = TestState(count: 5, isEnabled: true)
    let store = BindifyStore(initialState)

    let currentState = await store.state
    #expect(currentState.count == 5)
    #expect(currentState.isEnabled == true)
  }

  @Test("Store updates state correctly")
  func testStoreUpdate() async {
    let store = BindifyStore(TestState())

    await store.update { state in
      state.count = 10
      state.isEnabled = true
    }

    let currentState = await store.state
    #expect(currentState.count == 10)
    #expect(currentState.isEnabled == true)
  }

  @Test("Store notifies subscribers of state changes")
  func testStoreSubscriptions() async throws {
    let store = BindifyStore(TestState())
    var receivedUpdates: [(old: TestState?, new: TestState)] = []

    let subscription = await store.subscribe { old, new in
      receivedUpdates.append((old: old, new: new))
    }

    await store.update { state in
      state.count = 20
    }

    try? await Task.sleep(for: .milliseconds(200))

    #expect(receivedUpdates.count == 2)
    #expect(receivedUpdates[0].old == nil) // Initial state
    #expect(receivedUpdates[0].new.count == 0)
    #expect(receivedUpdates[1].old?.count == 0)
    #expect(receivedUpdates[1].new.count == 20)

    subscription.cancel()
  }

  @Test("Store doesn't notify subscribers when state hasn't changed")
  func testNoNotificationOnUnchangedState() async throws {
    let store = BindifyStore(TestState())
    var updateCount = 0

    let subscription = await store.subscribe { _, _ in
      updateCount += 1
    }

    await store.update { state in
      // No changes to state
    }

    try? await Task.sleep(for: .milliseconds(200))

    #expect(updateCount == 1) // Only initial state notification

    subscription.cancel()
  }

  @Test("Store handles multiple subscribers correctly")
  func testMultipleSubscribers() async throws {
    let store = BindifyStore(TestState())
    var subscriber1Updates = 0
    var subscriber2Updates = 0

    let subscription1 = await store.subscribe { _, _ in
      subscriber1Updates += 1
    }

    let subscription2 = await store.subscribe { _, _ in
      subscriber2Updates += 1
    }

    await store.update { state in
      state.count = 30
    }

    try? await Task.sleep(for: .milliseconds(200))

    #expect(subscriber1Updates == 2)
    #expect(subscriber2Updates == 2)

    subscription1.cancel()
    subscription2.cancel()
  }

  @Test("Store maintains thread safety during concurrent updates")
  func testConcurrentUpdates() async throws {
    let store = BindifyStore(TestState())
    let updateCount = 100
    var completedUpdates = 0

    // Perform multiple concurrent updates
    for i in 0..<updateCount {
      Task {
        await store.update { state in
          state.count = i
        }
        completedUpdates += 1
      }
    }

    try? await Task.sleep(for: .seconds(1))

    let finalState = await store.state
    #expect(completedUpdates == updateCount)
    #expect(finalState.count >= 0 && finalState.count < updateCount)
  }

  @Test("Store handles multiple subscribers with concurrent updates")
  func testMultipleSubscribersConcurrentUpdates() async throws {
    let store = BindifyStore(TestState())
    let subscriberCount = 5
    var subscriberUpdates = Array(repeating: 0, count: subscriberCount)
    var subscriptions: [AnyCancellable] = []

    // Create multiple subscribers
    for i in 0..<subscriberCount {
      let subscription = await store.subscribe { _, _ in
        subscriberUpdates[i] += 1
      }
      subscriptions.append(subscription)
    }

    // Perform concurrent updates from different tasks
    let updateCount = 10
    for i in 0..<updateCount {
      Task {
        await store.update { state in
          state.count = i
          state.isEnabled.toggle()
        }
      }
    }

    try? await Task.sleep(for: .milliseconds(500))

    // Verify all subscribers received updates
    for updates in subscriberUpdates {
      #expect(updates == updateCount + 1) // Initial state + updates
    }

    // Cleanup
    subscriptions.forEach { $0.cancel() }
  }

  @Test("Store maintains consistency with rapid concurrent subscriptions and updates")
  func testRapidConcurrentSubscriptionsAndUpdates() async throws {
    let store = BindifyStore(TestState())
    var receivedStates: [TestState] = []
    var subscriptions: [AnyCancellable] = []

    // Create subscribers rapidly
    for _ in 0..<3 {
      let subscription = await store.subscribe { _, new in
        receivedStates.append(new)
      }
      subscriptions.append(subscription)

      // Immediately update state
      await store.update { state in
        state.count += 1
      }
    }

    try? await Task.sleep(for: .milliseconds(200))

    // Verify state consistency
    for state in receivedStates {
      #expect(state.count >= 0)
      #expect(state.count <= 3)
    }

    // Cleanup
    subscriptions.forEach { $0.cancel() }
  }

  @Test("Store handles subscriber cancellation during updates")
  func testSubscriberCancellationDuringUpdates() async throws {
    let store = BindifyStore(TestState(isEnabled: false))
    var activeSubscriberUpdates = 0
    var cancelledSubscriberUpdates = 0
    var intermidiateCancelledSubscriberUpdates = 0

    // Create two subscribers
    let activeSubscription = await store.subscribe { _, _ in
      print("entered")
      activeSubscriberUpdates += 1
    }

    let cancelledSubscription = await store.subscribe { _, _ in
      cancelledSubscriberUpdates += 1
    }

    let intermidiateSubscription = await store.subscribe { _, _ in
      intermidiateCancelledSubscriberUpdates += 1
    }

    // Cancel one subscription
    cancelledSubscription.cancel()

    // Perform updates
    for i in 0..<5 {
      await store.update { state in
        state.isEnabled = true // enabling to start counting
        state.count = i
      }
      if i == 2 {
        intermidiateSubscription.cancel()
      }
    }

    try? await Task.sleep(for: .milliseconds(400))

    // Verify only active subscriber received updates
    #expect(activeSubscriberUpdates == 6) // Initial + 5 updates
    #expect(cancelledSubscriberUpdates == 1) // Only initial state
    #expect(intermidiateCancelledSubscriberUpdates == 4) // Stop receiveing after few updates state

    activeSubscription.cancel()
  }

  @Test("Store maintains order of updates with multiple subscribers")
  func testUpdateOrderWithMultipleSubscribers() async throws {
    let store = BindifyStore(TestState())
    var subscriber1Values: [Int] = []
    var subscriber2Values: [Int] = []

    let subscription1 = await store.subscribe { _, new in
      subscriber1Values.append(new.count)
    }

    let subscription2 = await store.subscribe { _, new in
      subscriber2Values.append(new.count)
    }

    // Perform ordered updates
    for i in 1...5 {
      await store.update { state in
        state.count = i
      }
    }

    try? await Task.sleep(for: .milliseconds(200))

    // Verify update order
    #expect(subscriber1Values == [0, 1, 2, 3, 4, 5])
    #expect(subscriber2Values == [0, 1, 2, 3, 4, 5])

    subscription1.cancel()
    subscription2.cancel()
  }

  @Test("Store handles rapid subscription and unsubscription")
  func testRapidSubscriptionUnsubscription() async throws {
    let store = BindifyStore(TestState())
    var updateCount = 0

    // Create and cancel subscriptions rapidly
    for _ in 0..<10 {
      let subscription = await store.subscribe { _, _ in
        updateCount += 1
      }

      await store.update { state in
        state.count += 1
      }

      subscription.cancel()
    }

    try? await Task.sleep(for: .milliseconds(200))

    // Verify updates were received
    #expect(updateCount > 0)
    #expect(updateCount <= 20) // Each subscription gets initial state + update
  }

  @Test("Store handles invalid state updates gracefully")
  func testInvalidStateUpdates() async throws {
    let store = BindifyStore(TestState())

    // Test with invalid state updates
    for i in 0..<5 {
      await store.update { state in
        if i == 2 {
          // Simulate an invalid state by setting count to a negative value
          state.count = -1
        } else {
          state.count = i
        }
      }
    }
    
    let finalState = await store.state
    #expect(finalState.count >= 0) // State should never be invalid
  }

  @Test("Store maintains consistency after error recovery")
  func testErrorRecovery() async throws {
    let store = BindifyStore(TestState())
    var receivedStates: [TestState] = []
    
    let subscription = await store.subscribe { _, new in
      receivedStates.append(new)
    }
    
    // Simulate a series of updates with potential errors
    for i in 0..<5 {
      await store.update { state in
        state.count = i
        if i == 2 {
          // Simulate a temporary error condition
          state.isEnabled = false
        } else {
          state.isEnabled = true
        }
      }
    }
    
    try? await Task.sleep(for: .milliseconds(200))
    
    // Verify state consistency after errors
    #expect(receivedStates.count == 6) // Initial + 5 updates
    #expect(receivedStates.last?.count == 4)
    #expect(receivedStates.last?.isEnabled == true)
    
    subscription.cancel()
  }

  @Test("Store handles concurrent error conditions")
  func testConcurrentErrorHandling() async throws {
    let store = BindifyStore(TestState())
    let updateCount = 10

    // Perform concurrent updates with potential errors
    for i in 0..<updateCount {
      Task {
        await store.update { state in
          state.count = i
          if i % 3 == 0 {
            // Simulate error conditions every third update
            state.isEnabled = false
          } else {
            state.isEnabled = true
          }
        }
      }
    }
    
    try? await Task.sleep(for: .milliseconds(500))
    
    let finalState = await store.state
    #expect(finalState.count >= 0 && finalState.count < updateCount)
  }

  @Test("Store maintains consistency with large state objects")
  func testLargeStateObjects() async throws {
    struct LargeState: BindifyStoreState {
      var data: [String: [Int]]
      var metadata: [String: String]
      
      init() {
        self.data = [:]
        self.metadata = [:]
      }
    }
    
    let store = BindifyStore(LargeState())
    var receivedUpdates = 0
    
    let subscription = await store.subscribe { _, _ in
      receivedUpdates += 1
    }
    
    // Update with large state objects
    for i in 0..<5 {
      await store.update { state in
        state.data["key\(i)"] = Array(repeating: i, count: 1000)
        state.metadata["meta\(i)"] = String(repeating: "test", count: 100)
      }
    }
    
    try? await Task.sleep(for: .milliseconds(200))
    
    #expect(receivedUpdates == 6) // Initial + 5 updates
    let finalState = await store.state
    #expect(finalState.data.count == 5)
    #expect(finalState.metadata.count == 5)
    
    subscription.cancel()
  }

  @Test("Store handles rapid state changes at performance limits")
  func testRapidStateChangesAtLimits() async throws {
    let store = BindifyStore(TestState())
    let updateCount = 1000
    var receivedUpdates = 0
    let startTime = Date()
    
    let subscription = await store.subscribe { _, _ in
      receivedUpdates += 1
    }
    
    // Perform updates as fast as possible
    for i in 0..<updateCount {
      await store.update { state in
        state.count = i
        state.isEnabled.toggle()
      }
    }
    
    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)
    
    #expect(receivedUpdates > 0)
    #expect(duration < 2.0) // Should complete within 2 seconds
    #expect(receivedUpdates <= updateCount + 1) // Initial + updates
    
    subscription.cancel()
  }

  @Test("Store maintains memory efficiency with long-running subscriptions")
  func testMemoryEfficiency() async throws {
    let store = BindifyStore(TestState())
    var subscriptions: [AnyCancellable] = []
    var updateCounts = [Int](repeating: 0, count: 100)
    let subscriptionCount = 100
    
    // Create many subscriptions
    for i in 0..<subscriptionCount {
      let subscription = await store.subscribe(
        updates: { _, _ in
          updateCounts[i] += 1
        }
      )
      subscriptions.append(subscription)
    }
    
    // Perform updates to trigger memory usage
    for i in 0..<50 {
      await store.update { state in
        state.count = i
        state.isEnabled.toggle()
      }
    }

    try? await Task.sleep(for: .milliseconds(200))

    // Verify all subscriptions received updates
    for count in updateCounts {
      #expect(count == 51) // Initial state + 50 updates
    }

    #expect(updateCounts.count == subscriptionCount)

    // Cancel all subscriptions except the last one
    for i in 0..<subscriptionCount - 1 {
      subscriptions[i].cancel()
    }
    
    // Clear update counts for the remaining subscription
    updateCounts[subscriptionCount - 1] = 0
    
    // Perform more updates
    for i in 0..<20 {
      await store.update { state in
        state.count = i
        state.isEnabled.toggle()
      }
    }
    
    try? await Task.sleep(for: .milliseconds(200))
    
    // Verify only the last subscription received updates
    for i in 0..<subscriptionCount - 1 {
      #expect(updateCounts[i] == 51) // Should not have increased
    }
    #expect(updateCounts[subscriptionCount - 1] == 20) // No intial update

    // Cancel the last subscription
    subscriptions.last?.cancel()
    subscriptions.removeAll()
  }

  // MARK: - Performance Tests

  @Test("Store performance with large number of rapid updates")
  func testStorePerformanceRapidUpdates() async throws {
    let store = BindifyStore(TestState(isEnabled: false))
    let updateCount = 1000
    var receivedUpdates = 0
    let startTime = Date()

    let subscription = await store.subscribe { _, _ in
      receivedUpdates += 1
    }

    // Perform rapid updates
    for i in 0..<updateCount {
      await store.update { state in
        state.isEnabled = true
        state.count = i
      }
    }

    try? await Task.sleep(for: .milliseconds(500))
    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)

    #expect(receivedUpdates == updateCount + 1) // Initial + updates
    #expect(duration < 1.0) // Should complete within 1 second

    subscription.cancel()
  }

  @Test("Store performance with multiple concurrent subscribers")
  func testStorePerformanceMultipleSubscribers() async throws {
    let store = BindifyStore(TestState())
    let subscriberCount = 100
    let updateCount = 50
    var subscriberUpdates = Array(repeating: 0, count: subscriberCount)
    var subscriptions: [AnyCancellable] = []
    let startTime = Date()

    // Create multiple subscribers
    for i in 0..<subscriberCount {
      let subscription = await store.subscribe { _, _ in
        subscriberUpdates[i] += 1
      }
      subscriptions.append(subscription)
    }

    // Perform updates
    for i in 0..<updateCount {
      await store.update { state in
        state.isEnabled = true
        state.count = i
      }
    }

    try? await Task.sleep(for: .milliseconds(500))
    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)

    // Verify all subscribers received updates
    for updates in subscriberUpdates {
      #expect(updates == updateCount + 1) // Initial + updates
    }
    #expect(duration < 2.0) // Should complete within 2 seconds

    // Cleanup
    subscriptions.forEach { $0.cancel() }
  }

  @Test("Store performance with rapid subscription changes")
  func testStorePerformanceRapidSubscriptionChanges() async throws {
    let store = BindifyStore(TestState())
    let iterationCount = 500
    var totalUpdates = 0
    let startTime = Date()

    // Rapidly create and cancel subscriptions while updating
    for i in 0..<iterationCount {
      let subscription = await store.subscribe { _, _ in
        totalUpdates += 1
      }

      await store.update { state in
        state.isEnabled = true
        state.count = i
      }

      subscription.cancel()
    }

    try? await Task.sleep(for: .milliseconds(500))
    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)

    #expect(totalUpdates > 0)
    #expect(duration < 1.0) // Should complete within 1 second
  }

  @Test("Store performance with complex state updates")
  func testStorePerformanceComplexStateUpdates() async throws {
    let store = BindifyStore(TestState())
    let updateCount = 200
    var receivedUpdates = 0
    let startTime = Date()

    let subscription = await store.subscribe { _, _ in
      receivedUpdates += 1
    }

    // Perform complex state updates
    for i in 0..<updateCount {
      await store.update { state in
        state.count = i
        state.isEnabled.toggle()
        // Simulate complex state computation
        _ = String(repeating: "test", count: 100)
      }
    }

    try? await Task.sleep(for: .milliseconds(500))
    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)

    #expect(receivedUpdates == updateCount + 1) // Initial + updates
    #expect(duration < 1.0) // Should complete within 1 second

    subscription.cancel()
  }

  @Test("Store performance with mixed operations")
  func testStorePerformanceMixedOperations() async throws {
    let store = BindifyStore(TestState())
    let operationCount = 100
    var receivedUpdates = 0
    var subscriptions: [AnyCancellable] = []
    let startTime = Date()

    // Perform mixed operations (updates, subscriptions, cancellations)
    for i in 0..<operationCount {
      // Create new subscription every 10 operations
      if i % 10 == 0 {
        let subscription = await store.subscribe { _, _ in
          receivedUpdates += 1
        }
        subscriptions.append(subscription)
      }

      // Cancel old subscriptions every 20 operations
      if i % 20 == 0 && !subscriptions.isEmpty {
        subscriptions.removeLast().cancel()
      }

      // Update state
      await store.update { state in
        state.count = i
        state.isEnabled.toggle()
      }
    }

    try? await Task.sleep(for: .milliseconds(500))
    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)

    #expect(receivedUpdates > 0)
    #expect(duration < 1.0) // Should complete within 1 second

    // Cleanup remaining subscriptions
    subscriptions.forEach { $0.cancel() }
  }
}


