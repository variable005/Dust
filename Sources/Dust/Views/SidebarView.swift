import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: NoteStore
    @Binding var isGraphViewPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // App Branding Top Bar
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.indigo, .purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 26, height: 26)
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text("DUST")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, .primary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Spacer()
                
                Button(action: { _ = store.createNote() }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                        .padding(6)
                        .background(Circle().fill(.thinMaterial))
                }
                .buttonStyle(.plain)
                .help("New Note (Cmd + N)")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            Divider()
                .opacity(0.6)
            
            // Navigation List
            List {
                // MARK: - Library Quick Filters
                Section {
                    ForEach(NoteStore.SidebarFilter.allCases) { filter in
                        let isSelected = store.selectedFilter == filter && store.selectedTag == nil && store.selectedFolder == nil
                        Button(action: {
                            store.selectedFilter = filter
                            store.selectedTag = nil
                            store.selectedFolder = nil
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: filter.iconName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(width: 22, alignment: .center)
                                    .foregroundColor(isSelected ? .accentColor : .secondary)
                                Text(filter.rawValue)
                                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                    .foregroundColor(isSelected ? .primary : .secondary)
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: { isGraphViewPresented = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "circle.hexagonpath.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 22, alignment: .center)
                                .foregroundStyle(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                            Text("Graph Visualizer")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.purple)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.purple.opacity(0.7))
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Library")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(.secondary)
                }
                
                // MARK: - Folders
                if !store.folderPaths.isEmpty {
                    Section {
                        ForEach(store.folderPaths, id: \.self) { folder in
                            let isSelected = store.selectedFolder == folder
                            Button(action: {
                                store.selectedFolder = folder
                                store.selectedTag = nil
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 12))
                                        .frame(width: 22, alignment: .center)
                                        .foregroundColor(isSelected ? .accentColor : .secondary)
                                    Text(folder)
                                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                        .foregroundColor(isSelected ? .primary : .secondary)
                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Folders")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // MARK: - Tags Cloud
                if !store.tagCounts.isEmpty {
                    Section {
                        ForEach(store.tagCounts, id: \.tag) { item in
                            let isSelected = store.selectedTag == item.tag
                            Button(action: {
                                if store.selectedTag == item.tag {
                                    store.selectedTag = nil
                                } else {
                                    store.selectedTag = item.tag
                                    store.selectedFolder = nil
                                }
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "number")
                                        .font(.system(size: 11, weight: .bold))
                                        .frame(width: 22, alignment: .center)
                                        .foregroundColor(isSelected ? .blue : .secondary)
                                    Text(item.tag)
                                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                        .foregroundColor(isSelected ? .primary : .secondary)
                                    Spacer()
                                    Text("\(item.count)")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(isSelected ? Color.blue.opacity(0.2) : Color.primary.opacity(0.06))
                                        )
                                        .foregroundColor(isSelected ? .blue : .secondary)
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Tags")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }
}


