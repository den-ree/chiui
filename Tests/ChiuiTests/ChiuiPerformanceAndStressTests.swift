import Foundation
import Testing
@testable import Chiui

private struct LargeStoreState: ContextualStoreState {
  var rawValue: Int
  var payload: [Int]

  init(rawValue: Int = 0, payloadSize: Int = 1) {
    self.rawValue = rawValue
    self.payload = Array(repeating: rawValue, count: payloadSize)
  }
}

private struct LargeViewState: ContextualViewState {
  var derived: Int = 0
  init() {}
}

private struct LargeTestContext: StoreContext {
  typealias StoreState = LargeStoreState
  let store: ContextualStore<LargeStoreState>

  init(initialState: LargeStoreState) {
    self.store = ContextualStore(initialState)
  }
}

actor CommitLog {
  private(set) var commits: Int = 0
  func recordCommit() { commits += 1 }
  func snapshot() -> Int { commits }
}

@MainActor
private final class LargeCoalescingViewModel: ContextViewModel<LargeTestContext, LargeViewState> {
  private let commitLog: CommitLog

  init(_ context: LargeTestContext, commitLog: CommitLog) {
    self.commitLog = commitLog
    super.init(context)
  }

  nonisolated override func didStoreUpdate(_ storeState: LargeStoreState) async {
    // Make updates overlap so the view model coalescing has something to cancel.
    try? await Task.sleep(for: .milliseconds(2))
    guard !Task.isCancelled else { return }

    // Derive a value that changes rarely relative to rawValue churn.
    // For rawValue in 0...(updateCount-1) and updateCount=250, derived changes ~3 times.
    let derived = storeState.rawValue / 100

    // CPU-bound work to make "blocking UI/main actor" detectable via heartbeat.
    // This runs before hopping back to MainActor via updateState.
    var checksum = 0
    for _ in 0..<120 {
      for v in storeState.payload {
        checksum &+= v
      }
      if Task.isCancelled { return }
    }
    // Avoid unused warning (checksum is intentionally not used for correctness).
    _ = checksum

    let sideEffect = await updateState { $0.derived = derived }
    if sideEffect.change.hasChanged {
      await commitLog.recordCommit()
    }
  }
}

@Suite("Chiui Performance & Stress Tests")
struct ChiuiPerformanceAndStressTests {
  @Test("Large rapid store updates keep main-actor responsive (soft budget)")
  func testRapidLargeStoreUpdatesDoNotBlockMainActor() async throws {
    let payloadSize = 1500
    let updateCount = 250

    let initialStore = LargeStoreState(rawValue: 0, payloadSize: payloadSize)
    let context = LargeTestContext(initialState: initialStore)
    let commitLog = CommitLog()
    let viewModel = await MainActor.run {
      LargeCoalescingViewModel(context, commitLog: commitLog)
    }

    // Heartbeat on main actor: if didStoreUpdate (or updateState hops) block main, ticks will stall.
    var heartbeatTicks = 0
    let heartbeatTask = Task { @MainActor in
      while !Task.isCancelled {
        heartbeatTicks += 1
        try? await Task.sleep(for: .milliseconds(2))
      }
    }

    let start = Date()

    // Rapid store churn.
    for i in 0..<updateCount {
      await context.store.update { state in
        state.rawValue = i
        // Replace payload with a new value to force equality checks to do real work.
        state.payload = Array(repeating: i, count: payloadSize)
      }
    }

    let expectedDerived = (updateCount - 1) / 100
    let didFinish = await TestUtils.waitUntil(timeout: .seconds(6)) {
      await MainActor.run { viewModel.viewState.derived == expectedDerived }
    }

    // Stop heartbeat before assertions.
    heartbeatTask.cancel()
    _ = await heartbeatTask.result

    let duration = Date().timeIntervalSince(start)

    // Soft checks:
    // - the pipeline must finish;
    // - main actor should have continued ticking during churn;
    // - commits should be much fewer than updateCount (coalescing / skip).
    #expect(didFinish)
    #expect(duration < 8.0)
    #expect(heartbeatTicks >= 4)

    let commits = await commitLog.snapshot()
    #expect(commits <= 5) // derived = rawValue/1000 changes rarely + coalescing cancels most work
  }
}

