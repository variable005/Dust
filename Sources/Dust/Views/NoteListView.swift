import SwiftUI

struct NoteListView: View {
    @ObservedObject var store: NoteStore
    
    var body: some View {
        VStack(spacing: 0) {
            // Minimal Search & Toolbar
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("Search notes...", text: $store.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !store.searchQuery.isEmpty {
                        Button(action: { store.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.ultraThinMaterial))
                
                Menu {
                    Picker("Sort By", selection: $store.sortOption) {
                        ForEach(NoteStore.SortOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(5)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Sort Options")
                
                if store.selectedFilter == .trash && !store.filteredNotes.isEmpty {
                    Button(action: { store.emptyTrash() }) {
                        Image(systemName: "trash.slash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red.opacity(0.85))
                            .padding(5)
                    }
                    .buttonStyle(.plain)
                    .help("Empty Trash")
                } else {
                    Button(action: { _ = store.createNote() }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.accentColor)
                            .padding(5)
                    }
                    .buttonStyle(.plain)
                    .help("Create New Note (Cmd + N)")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            
            Divider()
                .opacity(0.5)
            
            // Note List Feed
            if store.filteredNotes.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundColor(.secondary.opacity(0.7))
                    Text("No Notes")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Button("New Note") {
                        _ = store.createNote()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Spacer()
                }
            } else {
                List(store.filteredNotes, selection: $store.selectedNoteId) { note in
                    NoteRowView(note: note, store: store)
                        .tag(note.id)
                }
                .listStyle(.sidebar)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NoteRowView: View {
    let note: Note
    @ObservedObject var store: NoteStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 6) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                }
                if note.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.yellow)
                }
                
                Text(note.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                Spacer(minLength: 4)
                
                Text(note.modifiedAt.formatted(date: .numeric, time: .omitted))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            
            if !note.snippet.isEmpty {
                Text(note.snippet)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .lineSpacing(1.5)
            }
            
            if !note.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(note.tags).prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Color.primary.opacity(0.06)))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 1)
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            if note.isTrashed {
                Button("Restore Note") {
                    store.restoreNote(id: note.id)
                }
                Divider()
                Button("Delete Permanently", role: .destructive) {
                    store.permanentlyDeleteNote(id: note.id)
                }
            } else {
                Button(note.isPinned ? "Unpin Note" : "Pin Note") {
                    store.togglePin(id: note.id)
                }
                Button(note.isFavorite ? "Remove Favorite" : "Add Favorite") {
                    store.toggleFavorite(id: note.id)
                }
                Divider()
                Button("Move to Trash", role: .destructive) {
                    store.deleteNote(id: note.id)
                }
            }
        }
    }
}
