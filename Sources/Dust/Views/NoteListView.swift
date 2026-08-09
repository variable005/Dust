import SwiftUI

struct NoteListView: View {
    @ObservedObject var store: NoteStore
    
    var body: some View {
        
        VStack(spacing: 0) {
            // Liquid Glass Search & Sort Toolbar
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("Search notes...", text: $store.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                    if !store.searchQuery.isEmpty {
                        Button(action: { store.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                )
                
                Menu {
                    Picker("Sort By", selection: $store.sortOption) {
                        ForEach(NoteStore.SortOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Circle().fill(.thinMaterial))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Sort Options")
                
                if store.selectedFilter == .trash && !store.filteredNotes.isEmpty {
                    Button(action: { store.emptyTrash() }) {
                        Image(systemName: "trash.slash.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(6)
                            .background(Circle().fill(.thinMaterial))
                    }
                    .buttonStyle(.plain)
                    .help("Empty Trash")
                } else {
                    Button(action: { _ = store.createNote() }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.blue)
                            .padding(6)
                            .background(Circle().fill(.thinMaterial))
                    }
                    .buttonStyle(.plain)
                    .help("Create New Note (Cmd + N)")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Note List
            if store.filteredNotes.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(.thinMaterial)
                            .frame(width: 70, height: 70)
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                    }
                    Text("No Notes Found")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Create a new note or adjust your search filter.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Button("Create New Note") {
                        _ = store.createNote()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    Spacer()
                }
            } else {
                List(store.filteredNotes, selection: $store.selectedNoteId) { note in
                    NoteRowView(note: note, store: store)
                        .tag(note.id)
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NoteRowView: View {
    let note: Note
    @ObservedObject var store: NoteStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                HStack(spacing: 4) {
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
                    }
                    if note.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                    }
                }
                
                Text(note.title)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                Spacer(minLength: 8)
                
                Text(note.modifiedAt.formatted(date: .numeric, time: .omitted))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            if !note.snippet.isEmpty {
                Text(note.snippet)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .lineSpacing(2)
            }
            
            if !note.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(note.tags).prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.accentColor.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color.accentColor.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
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

