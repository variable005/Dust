import SwiftUI

final class QuickNoteHUDState: ObservableObject {
    @Published var title: String = ""
    @Published var content: String = ""
}

struct QuickNoteHUDView: View {
    @ObservedObject var store: NoteStore
    var onDismiss: () -> Void
    
    @StateObject private var hudState = QuickNoteHUDState()
    
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.yellow)
                    Text("Quick Scratchpad")
                        .font(.title3.bold())
                }
                Spacer()
                Text("⌘ + Return to Save")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.thinMaterial))
                    .foregroundColor(.secondary)
            }
            
            TextField("Note Title...", text: $hudState.title)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                )
            
            TextEditor(text: $hudState.content)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                )
            
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Button("Save Quick Note") {
                    saveQuickNote()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .padding(18)
        .frame(width: 480, height: 330)
        .background(.regularMaterial)
    }
    
    private func saveQuickNote() {
        let noteTitle = hudState.title.trimmingCharacters(in: .whitespaces).isEmpty ? "Quick Note \(Date().formatted(date: .numeric, time: .shortened))" : hudState.title
        _ = store.createNote(title: noteTitle, content: hudState.content)
        onDismiss()
    }
}


