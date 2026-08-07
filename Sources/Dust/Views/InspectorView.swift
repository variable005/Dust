import SwiftUI

struct InspectorView: View {
    let note: Note
    @ObservedObject var store: NoteStore
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // MARK: - Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title)
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "doc.plaintext.fill")
                            .foregroundColor(.blue)
                        Text(note.relativePath)
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                )
                
                // MARK: - Incoming Backlinks
                let incoming = store.backlinks(for: note.title)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Backlinks", systemImage: "link.badge.plus")
                            .font(.system(size: 13, weight: .bold))
                        Spacer()
                        Text("\(incoming.count)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.blue.opacity(0.15)))
                            .foregroundColor(.blue)
                    }
                    
                    if incoming.isEmpty {
                        Text("No other notes link to this note.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(incoming) { linkingNote in
                            Button(action: {
                                store.selectedNoteId = linkingNote.id
                            }) {
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundColor(.blue)
                                    Text(linkingNote.title)
                                        .font(.system(size: 12, weight: .medium))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.ultraThinMaterial)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                )
                
                // MARK: - Outgoing WikiLinks
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Outgoing Links", systemImage: "arrow.up.right.square.fill")
                            .font(.system(size: 13, weight: .bold))
                        Spacer()
                        Text("\(note.wikiLinks.count)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.purple.opacity(0.15)))
                            .foregroundColor(.purple)
                    }
                    
                    if note.wikiLinks.isEmpty {
                        Text("No [[WikiLinks]] in this note.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
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
                                HStack {
                                    Image(systemName: targetNote != nil ? "link" : "plus.circle.fill")
                                        .foregroundColor(targetNote != nil ? .purple : .green)
                                    Text(linkTarget)
                                        .font(.system(size: 12, weight: .medium))
                                    Spacer()
                                    Text(targetNote != nil ? "Open" : "Create")
                                        .font(.caption2.bold())
                                        .foregroundColor(targetNote != nil ? .purple : .green)
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.ultraThinMaterial)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                )
                
                // MARK: - Document Statistics
                VStack(alignment: .leading, spacing: 10) {
                    Label("Statistics", systemImage: "chart.bar.fill")
                        .font(.system(size: 13, weight: .bold))
                    
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                        GridRow {
                            Text("Words:").foregroundColor(.secondary)
                            Text("\(note.wordCount)").bold()
                        }
                        GridRow {
                            Text("Characters:").foregroundColor(.secondary)
                            Text("\(note.characterCount)").bold()
                        }
                        GridRow {
                            Text("Reading Time:").foregroundColor(.secondary)
                            Text("\(note.readingTimeMinutes) min").bold()
                        }
                        GridRow {
                            Text("Created:").foregroundColor(.secondary)
                            Text(note.createdAt.formatted(date: .numeric, time: .omitted))
                        }
                        GridRow {
                            Text("Modified:").foregroundColor(.secondary)
                            Text(note.modifiedAt.formatted(date: .numeric, time: .omitted))
                        }
                    }
                    .font(.caption)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            .padding(14)
        }
        .background(.ultraThinMaterial)
    }
}

