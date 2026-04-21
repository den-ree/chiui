import SwiftUI
import Chiui

struct DiaryEntryMoodSelectionView: ContextualView {
  @StateObject var viewModel: DiaryEntryMoodSelectionViewModel

  init(_ context: DiaryContext) {
    _viewModel = .init(wrappedValue: .init(context))
  }

  var body: some View {
    NavigationStack {
      List {
        ForEach(DiaryEntryMood.allCases, id: \.self) { mood in
          moodRow(mood)
        }
      }
      .navigationTitle("Select Mood")
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

  @ViewBuilder
  private func moodRow(_ mood: DiaryEntryMood) -> some View {
    Button {
      viewModel.updateSelectedMood(mood)
    } label: {
      HStack {
        Text(mood.title)
        Spacer()
        if state.selectedMood == mood {
          Image(systemName: "checkmark")
            .foregroundStyle(Color.accentColor)
        }
      }
    }
    .buttonStyle(.plain)
  }
}
