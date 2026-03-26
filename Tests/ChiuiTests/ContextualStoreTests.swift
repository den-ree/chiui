import Foundation
import Testing
@testable import Chiui

@Suite("Chiui ContextualStore Tests")
struct ContextualStoreTests {
  struct TestState: ContextualStoreState {
    var count: Int
    var isEnabled: Bool

    init(count: Int = 0, isEnabled: Bool = false) {
      self.count = count
      self.isEnabled = isEnabled
    }
  }

  @Test("Subscribe immediately emits initial state")
  func testSubscribeSendsInitialState() async throws {
    let store = ContextualStore(TestState(count: 5, isEnabled: true))
    let collector = OrderedUpdateCollector()

    let subscription = await store.subscribe { old, new in
      collector.receive(old: old, new: new)
    }

    #expect(await TestUtils.waitUntil(timeout: .seconds(1)) { await collector.count() == 1 })

    let updates = await collector.snapshot()
    #expect(updates.count == 1)
    #expect(updates[0].old == nil)
    #expect(updates[0].new.count == 5)
    #expect(updates[0].new.isEnabled == true)

    subscription.cancel()
    await collector.finish()
  }

  @Test("Store only notifies on Equatable state changes")
  func testUpdateSendsOnlyWhenChanged() async throws {
    let store = ContextualStore(TestState(count: 1, isEnabled: false))
    let collector = OrderedUpdateCollector()

    let subscription = await store.subscribe { old, new in
      collector.receive(old: old, new: new)
    }

    #expect(await TestUtils.waitUntil(timeout: .seconds(1)) { await collector.count() == 1 })
    let initial = (await collector.snapshot())[0].new

    // No-op mutation (same value -> should not emit).
    await store.update { state in
      state.count = initial.count
      state.isEnabled = initial.isEnabled
    }

    // Wait briefly for possible (incorrect) emission.
    try? await Task.sleep(for: .milliseconds(50))
    #expect(await collector.count() == 1)

    // Real change should emit exactly once.
    await store.update { state in
      state.count = 2
      state.isEnabled = true
    }

    #expect(await TestUtils.waitUntil(timeout: .seconds(1)) { await collector.count() == 2 })
    let updates = await collector.snapshot()

    #expect(updates[1].old?.count == 1)
    #expect(updates[1].new.count == 2)
    #expect(updates[1].new.isEnabled == true)

    subscription.cancel()
    await collector.finish()
  }

  @Test("Sequential updates preserve notification order")
  func testSequentialUpdateOrder() async throws {
    let store = ContextualStore(TestState(count: 0, isEnabled: false))
    let collector = OrderedUpdateCollector()

    let subscription = await store.subscribe { old, new in
      collector.receive(old: old, new: new)
    }

    let updateCount = 5
    for index in 1...updateCount {
      await store.update { state in
        state.count = index
      }
    }

    #expect(await TestUtils.waitUntil(timeout: .seconds(1)) { await collector.count() == updateCount + 1 })
    let updates = await collector.snapshot()

    let newCounts = updates.map { $0.new.count }
    #expect(newCounts == [0, 1, 2, 3, 4, 5])

    subscription.cancel()
    await collector.finish()
  }

  @Test("Cancelling a subscription stops further notifications")
  func testSubscriptionCancellationStopsNotifications() async throws {
    let store = ContextualStore(TestState(count: 0))
    let collector = OrderedUpdateCollector()

    let subscription = await store.subscribe { old, new in
      collector.receive(old: old, new: new)
    }

    #expect(await TestUtils.waitUntil(timeout: .seconds(1)) { await collector.count() == 1 })

    subscription.cancel()

    await store.update { state in
      state.count = 1
    }

    try? await Task.sleep(for: .milliseconds(50))
    #expect(await collector.count() == 1)
    await collector.finish()
  }

  @Test("Concurrent updates are safe and all notifications are delivered")
  func testConcurrentUpdatesDelivery() async throws {
    let store = ContextualStore(TestState(count: 0, isEnabled: false))
    let collector = OrderedUpdateCollector()

    let subscription = await store.subscribe { old, new in
      collector.receive(old: old, new: new)
    }

    let updateCount = 100

    // Each update uses a unique value, so every update should result in a notification.
    for index in 0..<updateCount {
      Task {
        await store.update { state in
          state.count = index
          state.isEnabled = (index % 2 == 0)
        }
      }
    }

    #expect(await TestUtils.waitUntil(timeout: .seconds(3)) { await collector.count() == updateCount + 1 })
    let updates = await collector.snapshot()

    let newCounts = updates.dropFirst().map { $0.new.count }
    #expect(Set(newCounts) == Set((0..<updateCount).map { $0 }))

    // Quick sanity: no nil old states beyond initial emission.
    for update in updates.dropFirst() {
      #expect(update.old != nil)
    }

    subscription.cancel()
    await collector.finish()
  }
}

private actor UpdateCollector {
  typealias Update = (old: ContextualStoreTests.TestState?, new: ContextualStoreTests.TestState)
  private var updates: [Update] = []

  func append(old: ContextualStoreTests.TestState?, new: ContextualStoreTests.TestState) {
    updates.append((old: old, new: new))
  }

  func snapshot() -> [Update] {
    updates
  }

  func count() -> Int {
    updates.count
  }
}

private final class OrderedUpdateCollector: @unchecked Sendable {
  typealias Update = UpdateCollector.Update

  private let continuation: AsyncStream<Update>.Continuation
  private let consumerTask: Task<Void, Never>
  private let collector: UpdateCollector

  init() {
    let collector = UpdateCollector()
    self.collector = collector

    var localContinuation: AsyncStream<Update>.Continuation?
    let stream = AsyncStream<Update> { continuation in
      localContinuation = continuation
    }
    guard let continuation = localContinuation else {
      fatalError("Failed to initialize update stream continuation")
    }
    self.continuation = continuation

    consumerTask = Task {
      for await update in stream {
        await collector.append(old: update.old, new: update.new)
      }
    }
  }

  func receive(old: ContextualStoreTests.TestState?, new: ContextualStoreTests.TestState) {
    continuation.yield((old: old, new: new))
  }

  func count() async -> Int {
    await collector.count()
  }

  func snapshot() async -> [Update] {
    await collector.snapshot()
  }

  func finish() async {
    continuation.finish()
    _ = await consumerTask.result
  }
}
