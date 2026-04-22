import SwiftUI
import Chiui

struct DiaryEntryLocationSelectionView: ContextualView {
  @State var viewModel: DiaryEntryLocationSelectionViewModel

  init(_ context: DiaryContext) {
    _viewModel = .init(initialValue: .init(context))
  }

  var body: some View {
    Form {
      TextField(
        "Enter location",
        text: bindTo(\.location) { .locationChanged($0) }
      )
      .textInputAutocapitalization(.words)
      .autocorrectionDisabled(false)
    }
    .navigationTitle("Select Location")
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button("Cancel") {
          send(.cancelSelection)
        }
      }

      ToolbarItem(placement: .navigationBarTrailing) {
        Button("Done") {
          send(.confirmSelection)
        }
      }
    }
  }
}
