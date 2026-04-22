import SwiftUI
import Chiui

struct DiaryListView: ContextualView {
  @State var viewModel: DiaryListViewModel

  init(_ context: DiaryContext) {
    _viewModel = .init(initialValue: .init(context))
  }

  var body: some View {
    NavigationStack {
      List {
        ForEach(state.entries) { entry in
          Button {
            send(.selectEntry(entry))
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
            send(.removeEntryAt(index))
          }
        }
      }
      .navigationTitle("Diary")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            send(.startAddingNew)
          } label: {
            Image(systemName: "plus")
          }
        }
      }
      .navigationDestination(
        isPresented: Binding(
          get: { state.selectedEntryId != nil },
          set: { isPresented in
            send(.setEntryDestinationPresented(isPresented))
          }
        )
      ) {
        DiaryEntryView(viewModel.context)
      }
      .navigationDestination(
        isPresented: bindTo(\.isAddingNew) { .setAddingNewDestinationPresented($0) }
      ) {
        DiaryEntryView(viewModel.context)
      }
    }
  }
}
