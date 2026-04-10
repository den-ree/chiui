import SwiftUI
import Chiui

/// View for adding a new diary entry
struct DiaryEntryView: ContextualView {
  /// View model for adding diary entries
  @StateObject var viewModel: DiaryEntryViewModel
  /// Focus state for tracking which field is being edited
  @FocusState private var focusedField: Field?

  enum Field: Equatable {
    case title
    case content
  }

  /// Creates a new add diary entry view
  /// - Parameter viewModel: View model to use
  init(_ context: DiaryContext) {
    _viewModel = .init(wrappedValue: .init(context))
  }

  var body: some View {
    ZStack {
      Form {
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
