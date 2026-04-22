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
final class ImmediateMapViewModel: ContextViewModel<
  ChiuiTestContext,
  ChiuiTestViewState,
  ImmediateMapViewModel.Action,
  Never
> {
  enum Action: Equatable, ContextualAction {
    case storeChanged(ChiuiTestStoreState)
    case localSet(Int)
  }

  override class func respond(to action: Action, state: inout ChiuiTestViewState) -> Never? {
    switch action {
    case .storeChanged(let storeState):
      state.value = storeState.value
    case .localSet(let value):
      state.value = value
    }
    return nil
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
final class SlowCoalescingMapViewModel: ContextViewModel<
  ChiuiTestContext,
  ChiuiTestViewState,
  SlowCoalescingMapViewModel.Action,
  SlowCoalescingMapViewModel.Effect
> {
  private let log: ThreadAndValueLog

  init(_ context: ChiuiTestContext, log: ThreadAndValueLog) {
    self.log = log
    super.init(context)
  }

  enum Action: Equatable, ContextualAction {
    case storeChanged(ChiuiTestStoreState)
  }

  enum Effect: Equatable {
    case recordApplied(Int)
  }

  override class func respond(to action: Action, state: inout ChiuiTestViewState) -> Effect? {
    switch action {
    case .storeChanged(let storeState):
      state.value = storeState.value
      return .recordApplied(storeState.value)
    }
  }

  override func handle(_ effect: Effect) async {
    switch effect {
    case .recordApplied(let value):
      // Simulate expensive follow-up work that should be cancellable.
      try? await Task.sleep(for: .milliseconds(80))
      guard !Task.isCancelled else { return }
      await log.applied(value: value)
    }
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
      await viewModel.state.value == 42
    })
  }

  @Test("updateStore mutates the actor store")
  func testUpdateStore() async throws {
    let context = ChiuiTestContext(initialState: .init(value: 1))
    let viewModel = ImmediateMapViewModel(context)

    // Wait for initial mapping (keeps the test from racing the connectTask).
    #expect(await TestUtils.waitUntil(timeout: .seconds(1)) {
      await viewModel.state.value == 1
    })

    await viewModel.updateStore { storeState in
      storeState.value = 123
    }

    let storeState = await context.store.state
    #expect(storeState.value == 123)
  }

  @Test("updateState does not update view state when values are unchanged")
  func testUpdateStateSkipWhenNoChange() async throws {
    let context = ChiuiTestContext(initialState: .init(value: 0))
    let viewModel = ImmediateMapViewModel(context)

    #expect(await TestUtils.waitUntil(timeout: .seconds(1)) {
      await viewModel.state.value == 0
    })

    // viewState is already 0; setting it to 0 should be treated as a no-op.
    let captured = viewModel.updateState { $0.value = 0 }

    #expect(captured.hasChanged == false)
    #expect(viewModel.state.value == 0)
  }

  @Test("scopeState snapshots derived values at call time")
  func testScopeStateSnapshots() async throws {
    let context = ChiuiTestContext(initialState: .init(value: 0))
    let viewModel = ImmediateMapViewModel(context)

    #expect(await TestUtils.waitUntil(timeout: .seconds(1)) {
      await viewModel.state.value == 0
    })

    let box = IntBox()
    let captureSignal = SnapshotCaptured()
    let gate = ReleaseGate()

    // Start scopeState work, then mutate the view state after the snapshot is captured
    // but before we allow the async block to publish the snapshot.
    let task = Task {
      await viewModel.scopeState({ $0.value }, { snapshot in
        await captureSignal.set(snapshot)
        await gate.wait()
        await box.set(snapshot)
      })
    }

    #expect(await TestUtils.waitUntil(timeout: .seconds(5)) {
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
      await viewModel.state.value == -1
    })

    // Let the initial `.storeChanged(-1)` effect finish (`handle` sleeps) before flooding updates,
    // so coalescing tests stale intermediate snapshots — not cancellation of the first mapping.
    try? await Task.sleep(for: .milliseconds(120))

    for index in 1...5 {
      await context.store.update { state in
        state.value = index
      }
    }

    #expect(await TestUtils.waitUntil(timeout: .seconds(2)) {
      await viewModel.state.value == 5
    })

    // `handle` logs after an async delay; wait for the final log entry.
    #expect(await TestUtils.waitUntil(timeout: .seconds(2)) {
      await log.snapshotApplied().last == 5
    })

    // Only initial mapping + latest mapping should commit.
    let applied = await log.snapshotApplied()
    #expect(applied.contains(-1))
    #expect(applied.last == 5)
    #expect(applied.filter { $0 != -1 && $0 != 5 }.isEmpty)
  }

  @Test("Reducer stays pure and deterministic")
  func testReducerPureFunction() {
    var state = ChiuiTestViewState(value: 1)
    let effect: Never? = ImmediateMapViewModel.respond(to: .localSet(7), state: &state)
    #expect(effect == nil)
    #expect(state.value == 7)
  }

  @Test("Store snapshot action maps through reducer")
  func testReducerStoreChangedAction() {
    var state = ChiuiTestViewState(value: 0)
    let effect: Never? = ImmediateMapViewModel.respond(
      to: .storeChanged(ChiuiTestStoreState(value: 99)),
      state: &state
    )
    #expect(effect == nil)
    #expect(state.value == 99)
  }

  // Note: main-actor responsiveness under store churn is covered in the dedicated
  // performance test via a main-actor heartbeat.
}
