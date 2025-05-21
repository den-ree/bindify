import SwiftUI
import Bindify

/// View for adding a new diary entry
struct DiaryEntryView: BindifyStateView {
  /// View model for adding diary entries
  @StateObject var viewModel: DiaryEntryViewModel
  /// Environment presentation mode for dismissing the view
  @Environment(\.presentationMode) private var presentationMode
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
    NavigationView {
      ZStack {
        Form {
          Section(header: Text("Title")) {
            TextField("Enter title", text: bindTo(\.title, onSet: { newValue in
              viewModel.updateTitle(newValue)
              }))
              .focused($focusedField, equals: .title)
              .onChange(of: focusedField) { oldValue, newValue in
                if newValue == .title {
                  viewModel.startEditing()
                }
              }
          }

          Section(header: Text("Content")) {
              TextEditor(text: bindTo(\.content, onSet: { newValue in
                viewModel.updateContent(newValue)
              }))
              .frame(minHeight: 200)
              .focused($focusedField, equals: .content)
              .onChange(of: focusedField) { oldValue, newValue in
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
                viewModel.finishEditing(save: false)
                presentationMode.wrappedValue.dismiss()
              }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
              Button("Save") {
                focusedField = nil
                viewModel.finishEditing(save: true)
              }
              .disabled(state.isSavingDisabled)
            }
          }
        }
        .onChange(of: state.isSaved) { oldValue, newValue in
          if newValue {
            presentationMode.wrappedValue.dismiss()
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
}

