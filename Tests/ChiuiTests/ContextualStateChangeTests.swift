import Testing
import Foundation
@testable import Chiui

private struct TestState: ContextualState {
  var value: Int
}

@Suite("Chiui ContextualStateChange Tests")
struct ContextualStateChangeTests {
  @Test("ContextualStateChange hasChanged detects equality")
  func testHasChanged() {
    let oldState = TestState(value: 1)
    let newState = TestState(value: 2)
    let change = ContextualStateChange<TestState>(oldState: oldState, newState: newState, isInitial: false)

    #expect(change.hasChanged == true)
    #expect(change.oldState.value == 1)
    #expect(change.newState.value == 2)
  }

  @Test("ContextualStateChange isInitial is carried through correctly")
  func testIsInitial() {
    let oldState = TestState(value: 1)
    let newState = TestState(value: 1)
    let change = ContextualStateChange<TestState>(oldState: oldState, newState: newState, isInitial: true)

    #expect(change.hasChanged == false)
    #expect(change.isInitial == true)
  }

  @Test("ContextualStateChange carries old/new values")
  func testChangeCarriesStateValues() {
    let change = ContextualStateChange<TestState>(
      oldState: TestState(value: 10),
      newState: TestState(value: 20),
      isInitial: false
    )
    #expect(change.hasChanged == true)
    #expect(change.oldState.value == 10)
    #expect(change.newState.value == 20)
    #expect(change.isInitial == false)
  }
}
