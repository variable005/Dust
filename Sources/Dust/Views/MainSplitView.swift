import SwiftUI

final class MainViewState: ObservableObject {
    @Published var isInspectorPresented: Bool = true
    @Published var isGraphViewPresented: Bool = false
    @Published var isQuickNoteHUDPresented: Bool = false
    @Published var isFocusMode: Bool = false
}

struct MainSplitView: View {
    @StateObject private var store = NoteStore()
    @StateObject private var mainState = MainViewState()
    
    var body: some View {
        ZStack {
            NavigationSplitView {
                SidebarView(store: store, isGraphViewPresented: $mainState.isGraphViewPresented)
                    .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 280)
            } content: {
                NoteListView(store: store)
                    .navigationSplitViewColumnWidth(min: 260, ideal: 290, max: 360)
            } detail: {
                if let selectedId = store.selectedNoteId,
                   let noteIndex = store.notes.firstIndex(where: { $0.id == selectedId }) {
                    MarkdownEditorView(
                        note: store.notes[noteIndex],
                        store: store,
                        onContentChange: { newContent in
                            store.updateNoteContent(id: selectedId, newContent: newContent)
                        }
                    )
                    .inspector(isPresented: $mainState.isInspectorPresented) {
                        InspectorView(note: store.notes[noteIndex], store: store)
                            .inspectorColumnWidth(min: 240, ideal: 270, max: 320)
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    mainState.isFocusMode.toggle()
                                }
                            }) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                            }
                            .help("Full Screen Focus Mode (Cmd + Shift + F)")

                            Button(action: { mainState.isQuickNoteHUDPresented = true }) {
                                Label("Quick Scratchpad", systemImage: "bolt.fill")
                            }
                            .help("Global Quick Scratchpad (Cmd + Shift + N)")
                            
                            Button(action: {
                                store.toggleFavorite(id: selectedId)
                            }) {
                                Image(systemName: store.notes[noteIndex].isFavorite ? "star.fill" : "star")
                                    .foregroundColor(store.notes[noteIndex].isFavorite ? .yellow : .primary)
                            }
                            .help("Toggle Favorite")
                            
                            Button(action: {
                                store.togglePin(id: selectedId)
                            }) {
                                Image(systemName: store.notes[noteIndex].isPinned ? "pin.fill" : "pin")
                                    .foregroundColor(store.notes[noteIndex].isPinned ? .orange : .primary)
                            }
                            .help("Toggle Pin")
                            
                            Button(action: { mainState.isInspectorPresented.toggle() }) {
                                Image(systemName: "sidebar.right")
                            }
                            .help("Toggle Inspector Panel")
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 90, height: 90)
                            Image(systemName: "note.text")
                                .font(.system(size: 42, weight: .light))
                                .foregroundStyle(.linearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                        Text("Select or Create a Note")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        Text("Capture your thoughts in Markdown with native offline storage.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button("Create Note") {
                            _ = store.createNote()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                }
            }
            .sheet(isPresented: $mainState.isGraphViewPresented) {
                GraphView(store: store)
            }
            .sheet(isPresented: $mainState.isQuickNoteHUDPresented) {
                QuickNoteHUDView(store: store, onDismiss: { mainState.isQuickNoteHUDPresented = false })
            }

            // Full Screen Focus Mode Overlay
            if mainState.isFocusMode,
               let selectedId = store.selectedNoteId,
               let noteIndex = store.notes.firstIndex(where: { $0.id == selectedId }) {
                FullScreenFocusView(
                    note: store.notes[noteIndex],
                    store: store,
                    onDismiss: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            mainState.isFocusMode = false
                        }
                    }
                )
                .transition(.asymmetric(insertion: .scale(scale: 0.95).combined(with: .opacity), removal: .opacity))
                .zIndex(100)
            }
        }
        .keyboardShortcut("f", modifiers: [.command, .shift])
    }
}


