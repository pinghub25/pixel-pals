import SwiftUI

/// Write your own messages; they join the daily rotation ("My messages" or "Mix").
struct MyMessagesView: View {
    @EnvironmentObject private var model: PetModel
    @State private var draft = ""

    private var canAdd: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        List {
            Section {
                TextField("Write a message for future you", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                Button {
                    model.addCustomMessage(draft)
                    draft = ""
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .disabled(!canAdd)
            } footer: {
                Text("Your messages appear when Daily content is set to My messages or Mix.")
            }

            Section("Your messages") {
                if model.customMessages.isEmpty {
                    Text("No messages yet").foregroundStyle(.secondary)
                }
                ForEach(Array(model.customMessages.enumerated()), id: \.offset) { _, message in
                    Text(message)
                }
                .onDelete { model.removeCustomMessages(at: $0) }
            }
        }
        .navigationTitle("My messages")
        .navigationBarTitleDisplayMode(.inline)
    }
}
