import SwiftUI
import Chiui

struct DiaryEntryView: ContextualView {
  @StateObject var viewModel: DiaryEntryViewModel
  @FocusState private var focusedField: Field?

  enum Field: Equatable {
    case title
    case content
  }

  init(_ context: DiaryContext) {
    _viewModel = .init(wrappedValue: .init(context))
  }

  var body: some View {
    ZStack {
      Form {
        Section(header: Text("Date")) {
          Button {
            focusedField = nil
            viewModel.openDateSelection()
          } label: {
            HStack {
              Text("Entry Date")
              Spacer()
              Text(state.selectedDate, style: .date)
                .foregroundStyle(.secondary)
            }
          }
        }

        Section(header: Text("Mood")) {
          Button {
            focusedField = nil
            viewModel.openMoodSelection()
          } label: {
            HStack {
              Text("Mood")
              Spacer()
              Text(state.selectedMood.title)
                .foregroundStyle(.secondary)
            }
          }
        }

        Section(header: Text("Title")) {
          TextField("Enter title", text: bindTo(\.title) { viewModel.updateTitle($0) })
          .focused($focusedField, equals: .title)
          .onChange(of: focusedField) { _, newValue in
            if newValue == .title {
              viewModel.startEditing()
            }
          }
        }

        Section(header: Text("Content")) {
          TextEditor(text: bindTo(\.content) { viewModel.updateContent($0) })
          .frame(minHeight: 200)
          .focused($focusedField, equals: .content)
          .onChange(of: focusedField) { _, newValue in
            if newValue == .content {
              viewModel.startEditing()
            }
          }
        }
      }
      .navigationTitle(state.entryTitle)
      .toolbar {
        if state.isEditing {
          ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
              focusedField = nil
              Task {
                await viewModel.finishEditing(save: false)
              }
            }
          }

          ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") {
              focusedField = nil
              Task {
                await viewModel.finishEditing(save: true)
              }
            }
            .disabled(state.isSavingDisabled)
          }
        }
      }
      .navigationDestination(
        isPresented: bindTo(\.isDateSelectionPresented) { _ in }
      ) {
        DiaryEntryDateSelectionView(viewModel.context)
      }
      .sheet(isPresented: bindTo(\.isMoodSelectionPresented) { _ in }) {
        DiaryEntryMoodSelectionView(viewModel.context)
      }

      if state.savingStatus == .saving {
        Color.black.opacity(0.2)
          .ignoresSafeArea()

        ProgressView()
          .scaleEffect(1.5)
          .progressViewStyle(CircularProgressViewStyle(tint: .white))
      }
    }
  }
}
