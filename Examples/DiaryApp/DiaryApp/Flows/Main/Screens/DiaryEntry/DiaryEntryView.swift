import SwiftUI
import Chiui

struct DiaryEntryView: ContextualView {
  @State var viewModel: DiaryEntryViewModel
  @FocusState private var focusedField: Field?

  enum Field: Equatable {
    case title
    case content
  }

  init(_ context: DiaryContext) {
    _viewModel = .init(initialValue: .init(context))
  }

  var body: some View {
    ZStack {
      Form {
        Section(header: Text("Date")) {
          Button {
            focusedField = nil
            send(.openDateSelection)
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
            send(.openMoodSelection)
          } label: {
            HStack {
              Text("Mood")
              Spacer()
              Text(state.selectedMood.title)
                .foregroundStyle(.secondary)
            }
          }
        }

        Section(header: Text("Location")) {
          Button {
            focusedField = nil
            send(.openLocationSelection)
          } label: {
            HStack {
              Text("Location")
              Spacer()
              Text(state.selectedLocation.isEmpty ? "No location" : state.selectedLocation)
                .foregroundStyle(.secondary)
            }
          }
        }

        Section(header: Text("Title")) {
          TextField("Enter title", text: bindTo(\.title) { .titleChanged($0) })
          .focused($focusedField, equals: .title)
          .onChange(of: focusedField) { _, newValue in
            if newValue == .title {
              send(.startEditing)
            }
          }
        }

        Section(header: Text("Content")) {
          TextEditor(text: bindTo(\.content) { .contentChanged($0) })
          .frame(minHeight: 200)
          .focused($focusedField, equals: .content)
          .onChange(of: focusedField) { _, newValue in
            if newValue == .content {
              send(.startEditing)
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
              send(.finishRequested(save: false))
            }
          }

          ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") {
              focusedField = nil
              send(.finishRequested(save: true))
            }
            .disabled(state.isSavingDisabled)
          }
        }
      }
      .navigationDestination(
        isPresented: Binding(get: { state.isDateSelectionPresented }, set: { _ in })
      ) {
        DiaryEntryDateSelectionView(viewModel.context)
      }
      .sheet(isPresented: Binding(get: { state.isMoodSelectionPresented }, set: { _ in })) {
        DiaryEntryMoodSelectionView(viewModel.context)
      }
      .sheet(isPresented: Binding(get: { state.isLocationSelectionPresented }, set: { _ in })) {
        NavigationStack {
          DiaryEntryLocationSelectionView(viewModel.context)
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
