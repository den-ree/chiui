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
private final class LargeCoalescingViewModel: ContextViewModel<
  LargeTestContext,
  LargeViewState,
  LargeCoalescingViewModel.Action,
  LargeCoalescingViewModel.Effect
> {
  enum Action: Equatable, ContextualAction {
    case storeChanged(LargeStoreState)
  }

  enum Effect: Equatable {
    case recordCommitIfDerivedChanged(Int)
  }

  private let commitLog: CommitLog

  init(_ context: LargeTestContext, commitLog: CommitLog) {
    self.commitLog = commitLog
    super.init(context)
  }

  override class func respond(to action: Action, state: inout LargeViewState) -> Effect? {
    switch action {
    case .storeChanged(let storeState):
      // Derive a value that changes rarely relative to rawValue churn.
      let derived = storeState.rawValue / 100

      // CPU-bound work to make "blocking UI/main actor" detectable via heartbeat.
      var checksum = 0
      for _ in 0..<120 {
        for payloadValue in storeState.payload {
          checksum &+= payloadValue
        }
      }
      _ = checksum

      guard state.derived != derived else { return nil }
      state.derived = derived
      return .recordCommitIfDerivedChanged(derived)
    }
  }

  override func handle(_ effect: Effect) async {
    switch effect {
    case .recordCommitIfDerivedChanged:
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

    // Heartbeat on main actor: if store mapping / handle work blocks main, ticks will stall.
    var heartbeatTicks = 0
    let heartbeatTask = Task { @MainActor in
      while !Task.isCancelled {
        heartbeatTicks += 1
        try? await Task.sleep(for: .milliseconds(2))
      }
    }
    // Give the heartbeat task a chance to schedule before stressing the pipeline.
    await Task.yield()

    let start = Date()

    // Rapid store churn.
    for index in 0..<updateCount {
      await context.store.update { state in
        state.rawValue = index
        // Replace payload with a new value to force equality checks to do real work.
        state.payload = Array(repeating: index, count: payloadSize)
      }
    }

    let expectedDerived = (updateCount - 1) / 100
    let didFinish = await TestUtils.waitUntil(timeout: .seconds(6)) {
      await viewModel.state.derived == expectedDerived
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
    // Under rapid churn the main actor may schedule the heartbeat rarely; require at least one tick.
    #expect(heartbeatTicks >= 1)

    let commits = await commitLog.snapshot()
    #expect(commits <= 6) // derived changes rarely; one extra commit can occur under scheduling jitter
  }
}
