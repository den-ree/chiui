import SwiftUI
import Chiui

/// View for displaying the list of diary entries
struct DiaryListView: ContextualView {
  /// View model for the diary list
  @StateObject var viewModel: DiaryListViewModel

  /// Creates a new diary list view
  /// - Parameter viewModel: View model to use
  init(_ context: DiaryContext) {
    _viewModel = .init(wrappedValue: .init(context))
  }

  var body: some View {
    NavigationStack {
      List {
        ForEach(state.entries) { entry in
          Button {
            viewModel.selectEntry(entry)
          } label: {
            VStack(alignment: .leading, spacing: 8) {
              Text(entry.title)
                .font(.headline)

              Text(entry.content)
                .font(.body)
                .lineLimit(2)

              Text(entry.createdAt, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
          }
          .buttonStyle(.plain)
        }
        .onDelete { indexSet in
          for index in indexSet {
            viewModel.removeEntry(at: index)
          }
        }
      }
      .navigationTitle("Diary")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            viewModel.startAddingNew()
          } label: {
            Image(systemName: "plus")
          }
        }
      }
      .navigationDestination(
        isPresented: Binding(
          get: { viewModel.isEntryDestinationPresented() },
          set: { viewModel.setEntryDestinationPresented($0) }
        )
      ) {
        DiaryEntryView(viewModel.context)
      }
      .navigationDestination(
        isPresented: bindTo(\.isAddingNew) { viewModel.setAddingNewDestinationPresented($0) }
      ) {
        DiaryEntryView(viewModel.context)
      }
    }
  }
}
