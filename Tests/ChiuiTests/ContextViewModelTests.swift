import Foundation
import Testing
@testable import Chiui

struct ChiuiTestStoreState: ContextualStoreState {
  var value: Int
}

struct ChiuiTestViewState: ContextualViewState {
  var value: Int = 0
}

struct ChiuiTestContext: StoreContext {
  typealias StoreState = ChiuiTestStoreState
  let store: ContextualStore<ChiuiTestStoreState>

  init(initialState: ChiuiTestStoreState) {
    self.store = ContextualStore(initialState)
  }
}

@MainActor
final class ImmediateMapViewModel: ContextViewModel<ChiuiTestContext, ChiuiTestViewState> {
  nonisolated override func didStoreUpdate(_ storeState: ChiuiTestStoreState) async {
    await updateState { $0.value = storeState.value }
  }
}

actor ThreadAndValueLog {
  private(set) var appliedValues: [Int] = []

  func applied(value: Int) {
    appliedValues.append(value)
  }

  func snapshotApplied() -> [Int] { appliedValues }
}

@MainActor
final class SlowCoalescingMapViewModel: ContextViewModel<ChiuiTestContext, ChiuiTestViewState> {
  private let log: ThreadAndValueLog

  init(_ context: ChiuiTestContext, log: ThreadAndValueLog) {
    self.log = log
    super.init(context)
  }

  nonisolated override func didStoreUpdate(_ storeState: ChiuiTestStoreState) async {
    // Simulate expensive mapping work that should be cancellable.
    // Task.sleep() is cancellation-aware; we also check Task.isCancelled after waking.
    try? await Task.sleep(for: .milliseconds(80))
    guard !Task.isCancelled else { return }

    await updateState { $0.value = storeState.value }
    await log.applied(value: storeState.value)
  }
}

actor IntBox {
  private var value: Int = -1
  func set(_ value: Int) { self.value = value }
  func get() -> Int { value }
}

actor SnapshotCaptured {
  private var snapshot: Int?
  func set(_ snapshot: Int) { self.snapshot = snapshot }
  func get() -> Int? { snapshot }
}

actor ReleaseGate {
  private var released = false
  func wait() async {
    while !released {
      try? await Task.sleep(for: .milliseconds(1))
    }
  }

  func release() { released = true }
}

@MainActor
@Suite("Chiui ContextViewModel Tests")
struct ContextViewModelTests {
  @Test("Initial store state is mapped into view state")
  func testInitialMapping() async throws {
    let context = ChiuiTestContext(initialState: .init(value: 42))
    let viewModel = ImmediateMapViewModel(context)

    #expect(await TestUtils.waitUntil(timeout: .seconds(1)) {
      await MainActor.run { viewModel.viewState.value == 42 }
    })
  }

  @Test("updateStore mutates the actor store")
  func testUpdateStore() async throws {
    let context = ChiuiTestContext(initialState: .init(value: 1))
    let viewModel = ImmediateMapViewModel(context)

    // Wait for initial mapping (keeps the test from racing the connectTask).
    #expect(await TestUtils.waitUntil(timeout: .seconds(1)) {
      await MainActor.run { viewModel.viewState.value == 1 }
    })

    let task = viewModel.updateStore { storeState in
      storeState.value = 123
    }
    await task.value

    let storeState = await context.store.state
    #expect(storeState.value == 123)
  }

  @Test("updateState does not update view state when values are unchanged")
  func testUpdateStateSkipWhenNoChange() async throws {
    let context = ChiuiTestContext(initialState: .init(value: 0))
    let viewModel = ImmediateMapViewModel(context)

    #expect(await TestUtils.waitUntil(timeout: .seconds(1)) {
      await MainActor.run { viewModel.viewState.value == 0 }
    })

    // viewState is already 0; setting it to 0 should be treated as a no-op.
    var captured: ContextualStateChange<ChiuiTestViewState>?
    let sideEffect = viewModel.updateState { $0.value = 0 }
    await sideEffect.then { change in
      captured = change
    }

    #expect(captured?.hasChanged == false)
    #expect(viewModel.viewState.value == 0)
  }

  @Test("scopeState snapshots derived values at call time")
  func testScopeStateSnapshots() async throws {
    let context = ChiuiTestContext(initialState: .init(value: 0))
    let viewModel = ImmediateMapViewModel(context)

    #expect(await TestUtils.waitUntil(timeout: .seconds(1)) {
      await MainActor.run { viewModel.viewState.value == 0 }
    })

    let box = IntBox()
    let captureSignal = SnapshotCaptured()
    let gate = ReleaseGate()

    // Start scopeState work, then mutate the view state after the snapshot is captured
    // but before we allow the async block to publish the snapshot.
    let task = Task {
      await viewModel.scopeState({ $0.value }) { snapshot in
        await captureSignal.set(snapshot)
        await gate.wait()
        await box.set(snapshot)
      }
    }

    #expect(await TestUtils.waitUntil(timeout: .seconds(1)) {
      await captureSignal.get() != nil
    })

    viewModel.updateState { $0.value = 99 }
    await gate.release()
    await task.value

    #expect(await box.get() == 0)
  }

  @Test("Rapid store updates coalesce: only the latest mapping should apply")
  func testRapidStoreUpdateCoalescing() async throws {
    let log = ThreadAndValueLog()
    let context = ChiuiTestContext(initialState: .init(value: -1))
    let viewModel = SlowCoalescingMapViewModel(context, log: log)

    // Wait until initial value is applied.
    #expect(await TestUtils.waitUntil(timeout: .seconds(2)) {
      await MainActor.run { viewModel.viewState.value == -1 }
    })

    for i in 1...5 {
      await context.store.update { state in
        state.value = i
      }
    }

    #expect(await TestUtils.waitUntil(timeout: .seconds(2)) {
      await MainActor.run { viewModel.viewState.value == 5 }
    })

    // Only initial mapping + latest mapping should commit.
    let applied = await log.snapshotApplied()
    #expect(applied.contains(-1))
    #expect(applied.last == 5)
    #expect(applied.filter { $0 != -1 && $0 != 5 }.isEmpty)
  }

  // Note: "didStoreUpdate doesn't block UI" is covered in the dedicated
  // performance test via a main-actor heartbeat.
}
