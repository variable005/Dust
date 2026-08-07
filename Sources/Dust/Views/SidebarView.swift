import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: NoteStore
    @Binding var isGraphViewPresented: Bool
    
    var body: some View {
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
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.secondary))
                            Text(filter.rawValue)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? .primary : .secondary)
                            Spacer()
                        }
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: { isGraphViewPresented = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "circle.hexagonpath.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.linearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Text("Graph Visualizer")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.purple)
                        Spacer()
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundColor(.purple.opacity(0.8))
                    }
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
            } header: {
                Text("Library")
                    .font(.caption.bold())
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
                                    .font(.system(size: 13))
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
                        .font(.caption.bold())
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
                            HStack(spacing: 8) {
                                Image(systemName: "number")
                                    .font(.caption.bold())
                                    .foregroundColor(isSelected ? .blue : .secondary)
                                Text(item.tag)
                                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                    .foregroundColor(isSelected ? .primary : .secondary)
                                Spacer()
                                Text("\(item.count)")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.12))
                                    )
                                    .foregroundColor(isSelected ? .blue : .secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Tags")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Dust")
    }
}

