import SwiftUI
import Bindify

/// View for displaying the list of diary entries
struct DiaryListView: BindifyView {
  /// View model for the diary list
  @StateObject var viewModel: DiaryListViewModel

  /// Creates a new diary list view
  /// - Parameter viewModel: View model to use
  init(_ context: DiaryContext) {
    _viewModel = .init(wrappedValue: .init(context))
  }

  var body: some View {
    NavigationView {
      List {
        ForEach(state.entries) { entry in
          NavigationLink(
            isActive: Binding(
              get: { state.selectedEntryId == entry.id },
              set: { isActive in
                if isActive {
                  onAction(.selectEntry(entry))
                } else {
                  onAction(.clearSelection)
                }
              }
            )
          ) {
            DiaryEntryView(viewModel.context)
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
        }
        .onDelete { indexSet in
          for index in indexSet {
            onAction(.removeEntry(at: index))
          }
        }
      }
      .navigationTitle("Diary")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          NavigationLink(
            isActive: bindTo(\.isAddingNew, action: { newValue in
              guard newValue else { return nil }
              return .startAddingNew
            })
          ) {
            DiaryEntryView(viewModel.context)
          } label: {
            Image(systemName: "plus")
          }
        }
      }
    }
  }
}

