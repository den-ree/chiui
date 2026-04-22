import SwiftUI
import Chiui

struct DiaryEntryMoodSelectionView: ContextualView {
  @State var viewModel: DiaryEntryMoodSelectionViewModel

  init(_ context: DiaryContext) {
    _viewModel = .init(initialValue: .init(context))
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

  @ViewBuilder
  private func moodRow(_ mood: DiaryEntryMood) -> some View {
    Button {
      send(.selectedMoodChanged(mood))
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
