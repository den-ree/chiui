import SwiftUI
import Chiui

struct DiaryEntryDateSelectionView: ContextualView {
  @StateObject var viewModel: DiaryEntryDateSelectionViewModel

  init(_ context: DiaryContext) {
    _viewModel = .init(wrappedValue: .init(context))
  }

  var body: some View {
    Form {
      DatePicker(
        "Entry Date",
        selection: bindTo(\.selectedDate) { viewModel.updateSelectedDate($0) },
        displayedComponents: [.date]
      )
      .datePickerStyle(.graphical)
    }
    .navigationTitle("Select Date")
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button("Cancel") {
          viewModel.cancelSelection()
        }
      }

      ToolbarItem(placement: .navigationBarTrailing) {
        Button("Done") {
          viewModel.confirmSelection()
        }
      }
    }
  }
}
