import SwiftUI

struct InspectorView: View {
    let note: Note
    @ObservedObject var store: NoteStore
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Note Info")
                        .font(.system(size: 13, weight: .bold))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)
            
            Divider()
                .opacity(0.5)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header Details
                    VStack(alignment: .leading, spacing: 3) {
                        Text(note.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(note.relativePath)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                        .opacity(0.5)
                    
                    // Backlinks Section
                    let incoming = store.backlinks(for: note.title)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("BACKLINKS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(0.8)
                            Spacer()
                            if !incoming.isEmpty {
                                Text("\(incoming.count)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if incoming.isEmpty {
                            Text("No incoming links")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.7))
                        } else {
                            ForEach(incoming) { linkingNote in
                                Button(action: {
                                    store.selectedNoteId = linkingNote.id
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "link")
                                            .font(.system(size: 11))
                                            .foregroundColor(.accentColor)
                                        Text(linkingNote.title)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary.opacity(0.5))
                                    }
                                    .padding(.vertical, 3)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Divider()
                        .opacity(0.5)
                    
                    // Outgoing WikiLinks Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("OUTGOING LINKS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(0.8)
                            Spacer()
                            if !note.wikiLinks.isEmpty {
                                Text("\(note.wikiLinks.count)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if note.wikiLinks.isEmpty {
                            Text("No outgoing [[WikiLinks]]")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.7))
                        } else {
                            ForEach(Array(note.wikiLinks), id: \.self) { linkTarget in
                                let targetNote = store.notes.first { $0.title.lowercased() == linkTarget.lowercased() }
                                
                                Button(action: {
                                    if let target = targetNote {
                                        store.selectedNoteId = target.id
                                    } else {
                                        let newNote = store.createNote(title: linkTarget)
                                        store.selectedNoteId = newNote.id
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: targetNote != nil ? "arrow.up.right" : "plus")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(targetNote != nil ? .purple : .green)
                                        Text(linkTarget)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .padding(.vertical, 3)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Divider()
                        .opacity(0.5)
                    
                    // Document Statistics
                    VStack(alignment: .leading, spacing: 8) {
                        Text("STATISTICS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(0.8)
                        
                        VStack(spacing: 5) {
                            statRow(label: "Words", value: "\(note.wordCount)")
                            statRow(label: "Characters", value: "\(note.characterCount)")
                            statRow(label: "Reading Time", value: "\(note.readingTimeMinutes) min")
                            statRow(label: "Created", value: note.createdAt.formatted(date: .numeric, time: .omitted))
                            statRow(label: "Modified", value: note.modifiedAt.formatted(date: .numeric, time: .omitted))
                        }
                    }
                    
                    Divider()
                        .opacity(0.5)
                    
                    // Export Note Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EXPORT NOTE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(0.8)
                        
                        HStack(spacing: 6) {
                            Button("PDF") {
                                NoteExporter.exportToPDF(note: note, store: store)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            
                            Button("HTML") {
                                NoteExporter.exportToHTML(note: note, store: store)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button("Markdown") {
                                NoteExporter.exportToMarkdown(note: note)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button("Text") {
                                NoteExporter.exportToPlainText(note: note)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 290, height: 400)
        .background(.regularMaterial)
    }
    
    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}
