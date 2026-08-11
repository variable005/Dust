import Foundation
import Combine
import SwiftUI

@MainActor
public final class NoteStore: ObservableObject {
    @Published public private(set) var notes: [Note] = []
    @Published public var selectedNoteId: UUID?
    @Published public var searchQuery: String = ""
    @Published public var selectedTag: String?
    @Published public var selectedFolder: String?
    @Published public var selectedFilter: SidebarFilter = .allNotes
    @Published public var sortOption: SortOption = .modifiedDateDescending
    
    public let rootFolderURL: URL
    private nonisolated(unsafe) var folderMonitorSource: DispatchSourceFileSystemObject?
    private nonisolated(unsafe) var folderFileDescriptor: Int32 = -1
    
    public enum SidebarFilter: String, CaseIterable, Identifiable {
        case allNotes = "All Notes"
        case favorites = "Favorites"
        case pinned = "Pinned"
        case trash = "Trash"
        
        public var id: String { rawValue }
        public var iconName: String {
            switch self {
            case .allNotes: return "tray.full.fill"
            case .favorites: return "star.fill"
            case .pinned: return "pin.fill"
            case .trash: return "trash.fill"
            }
        }
    }
    
    public enum SortOption: String, CaseIterable, Identifiable {
        case modifiedDateDescending = "Date Modified (Newest)"
        case modifiedDateAscending = "Date Modified (Oldest)"
        case createdDateDescending = "Date Created (Newest)"
        case titleAscending = "Title (A-Z)"
        
        public var id: String { rawValue }
    }
    
    public init(rootFolderURL: URL? = nil) {
        if let customURL = rootFolderURL {
            self.rootFolderURL = customURL
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.rootFolderURL = docs.appendingPathComponent("Dust", isDirectory: true)
        }
        
        setupFolder()
        loadNotes()
        startFolderMonitor()
    }
    
    deinit {
        stopFolderMonitor()
    }
    
    // MARK: - Directory Setup & Seed
    
    private func setupFolder() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: rootFolderURL.path) {
            try? fm.createDirectory(at: rootFolderURL, withIntermediateDirectories: true)
            seedDefaultWelcomeNotes()
        }
        ensureAssetsFolderExists()
    }
    
    // MARK: - Asset & Image Management
    
    public var assetsFolderURL: URL {
        rootFolderURL.appendingPathComponent("assets", isDirectory: true)
    }
    
    public func ensureAssetsFolderExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: assetsFolderURL.path) {
            try? fm.createDirectory(at: assetsFolderURL, withIntermediateDirectories: true)
        }
    }
    
    public func saveImageAsset(data: Data, extension ext: String = "png") -> String? {
        ensureAssetsFolderExists()
        let filename = "img_\(UUID().uuidString.prefix(8)).\(ext)"
        let fileURL = assetsFolderURL.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
            return "assets/\(filename)"
        } catch {
            print("Failed to save image asset: \(error)")
            return nil
        }
    }
    
    public func resolveImagePath(_ relativePath: String) -> URL {
        if relativePath.hasPrefix("/") || relativePath.hasPrefix("file://") || relativePath.hasPrefix("http") {
            return URL(string: relativePath) ?? URL(fileURLWithPath: relativePath)
        }
        return rootFolderURL.appendingPathComponent(relativePath)
    }
    
    private func seedDefaultWelcomeNotes() {
        let welcomeContent = """
        # Welcome to Dust 🚀
        
        Dust is a **lightning-fast, 100% offline Markdown note app** built natively for macOS in Swift.
        
        ## Features Included:
        - **Plain Text Storage**: All your notes live as standard `.md` files in `~/Documents/Dust/`.
        - **Nestable Tags**: Organize using tags like #ideas, #swift/macos, or #work.
        - **Bi-Directional Wiki Links**: Link between notes using `[[Welcome to Dust]]` syntax.
        - **Graph View**: See your connected knowledge graph in real-time.
        - **Global Quick Launcher**: Open a floating scratchpad instantly.
        
        Try creating a new note with `Cmd + N` or typing `[[Architecture Overview]]` below!
        """
        
        let archContent = """
        # Architecture Overview
        
        This note is linked from [[Welcome to Dust]].
        
        ## Tech Stack:
        - **UI**: SwiftUI & AppKit
        - **Parser**: Swift Regular Expressions for #tags & [[wiki-links]]
        - **Storage**: Direct macOS File System (`.md`)
        - **Offline**: Zero network dependencies.
        
        Tag: #dev/architecture #swift
        """
        
        let welcomeURL = rootFolderURL.appendingPathComponent("Welcome to Dust.md")
        let archURL = rootFolderURL.appendingPathComponent("Architecture Overview.md")
        
        try? welcomeContent.write(to: welcomeURL, atomically: true, encoding: .utf8)
        try? archContent.write(to: archURL, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Loading & File Synchronization
    
    public func loadNotes() {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: rootFolderURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        var loadedNotes: [Note] = []
        
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "md" else { continue }
            
            let relativePath = fileURL.path.replacingOccurrences(of: rootFolderURL.path + "/", with: "")
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            
            let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
            let modifiedDate = resourceValues?.contentModificationDate ?? Date()
            let createdDate = resourceValues?.creationDate ?? Date()
            
            // Preserve existing pinned/favorite state if previously loaded
            let existing = notes.first { $0.relativePath == relativePath }
            let isPinned = existing?.isPinned ?? false
            let isFavorite = existing?.isFavorite ?? false
            
            let note = Note(
                id: existing?.id ?? UUID(),
                relativePath: relativePath,
                content: content,
                createdAt: createdDate,
                modifiedAt: modifiedDate,
                isPinned: isPinned,
                isFavorite: isFavorite
            )
            loadedNotes.append(note)
        }
        
        self.notes = loadedNotes
        
        // Select first note if none selected
        if selectedNoteId == nil, let first = filteredNotes.first {
            selectedNoteId = first.id
        }
    }
    
    // MARK: - Filtering & Search Logic
    
    public var filteredNotes: [Note] {
        var list = notes
        
        // 1. Sidebar filter
        switch selectedFilter {
        case .allNotes: list = list.filter { !$0.isTrashed }
        case .favorites: list = list.filter { !$0.isTrashed && $0.isFavorite }
        case .pinned: list = list.filter { !$0.isTrashed && $0.isPinned }
        case .trash: list = list.filter { $0.isTrashed }
        }
        
        // 2. Tag filter
        if let tag = selectedTag {
            list = list.filter { !$0.isTrashed && $0.tags.contains(tag) }
        }
        
        // 3. Folder filter
        if let folder = selectedFolder, !folder.isEmpty {
            list = list.filter { !$0.isTrashed && $0.folderPath == folder }
        }
        
        // 4. Search query
        if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = searchQuery.lowercased()
            list = list.filter {
                $0.title.lowercased().contains(q) ||
                $0.content.lowercased().contains(q) ||
                $0.tags.contains { $0.contains(q) }
            }
        }
        
        // 5. Sorting
        return list.sorted { n1, n2 in
            if n1.isPinned != n2.isPinned {
                return n1.isPinned && !n2.isPinned
            }
            switch sortOption {
            case .modifiedDateDescending: return n1.modifiedAt > n2.modifiedAt
            case .modifiedDateAscending: return n1.modifiedAt < n2.modifiedAt
            case .createdDateDescending: return n1.createdAt > n2.createdAt
            case .titleAscending: return n1.title.localizedCaseInsensitiveCompare(n2.title) == .orderedAscending
            }
        }
    }
    
    /// Unique extracted `#tags` across all notes with count
    public var tagCounts: [(tag: String, count: Int)] {
        var dict: [String: Int] = [:]
        for note in notes {
            for tag in note.tags {
                dict[tag, default: 0] += 1
            }
        }
        return dict.map { (tag: $0.key, count: $0.value) }.sorted { $0.tag < $1.tag }
    }
    
    /// Unique folder paths
    public var folderPaths: [String] {
        let paths = Set(notes.map { $0.folderPath }.filter { !$0.isEmpty })
        return Array(paths).sorted()
    }
    
    /// Find incoming backlinks pointing to target note title
    public func backlinks(for noteTitle: String) -> [Note] {
        let target = noteTitle.lowercased()
        return notes.filter { note in
            note.wikiLinks.contains { $0.lowercased() == target }
        }
    }
    
    // MARK: - Note Operations
    
    public func createNote(title: String = "Untitled Note", folder: String = "", content: String = "") -> Note {
        let sanitizedTitle = title.trimmingCharacters(in: .whitespaces)
        let filename = sanitizedTitle.isEmpty ? "Untitled Note.md" : "\(sanitizedTitle).md"
        let relativePath = folder.isEmpty ? filename : "\(folder)/\(filename)"
        
        let fileURL = rootFolderURL.appendingPathComponent(relativePath)
        let initialContent = content.isEmpty ? "# \(sanitizedTitle)\n\n" : content
        
        // Ensure parent folder exists
        let parentDir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        
        try? initialContent.write(to: fileURL, atomically: true, encoding: .utf8)
        
        let newNote = Note(
            relativePath: relativePath,
            content: initialContent,
            createdAt: Date(),
            modifiedAt: Date()
        )
        
        notes.insert(newNote, at: 0)
        selectedNoteId = newNote.id
        return newNote
    }
    
    public func updateNoteContent(id: UUID, newContent: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        
        var updated = notes[index]
        updated.content = newContent
        updated.modifiedAt = Date()
        notes[index] = updated
        
        // Write to disk asynchronously
        let fileURL = rootFolderURL.appendingPathComponent(updated.relativePath)
        Task.detached(priority: .background) {
            try? newContent.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
    
    public func togglePin(id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isPinned.toggle()
    }
    
    public func toggleFavorite(id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isFavorite.toggle()
    }
    
    public func deleteNote(id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isTrashed = true
        if selectedNoteId == id {
            selectedNoteId = filteredNotes.first?.id
        }
    }
    
    public func restoreNote(id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isTrashed = false
    }
    
    public func permanentlyDeleteNote(id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        let note = notes[index]
        let fileURL = rootFolderURL.appendingPathComponent(note.relativePath)
        try? FileManager.default.removeItem(at: fileURL)
        notes.remove(at: index)
        if selectedNoteId == id {
            selectedNoteId = filteredNotes.first?.id
        }
    }
    
    public func emptyTrash() {
        let trashed = notes.filter { $0.isTrashed }
        for note in trashed {
            let fileURL = rootFolderURL.appendingPathComponent(note.relativePath)
            try? FileManager.default.removeItem(at: fileURL)
        }
        notes.removeAll { $0.isTrashed }
        if selectedNoteId == nil || !filteredNotes.contains(where: { $0.id == selectedNoteId }) {
            selectedNoteId = filteredNotes.first?.id
        }
    }
    
    // MARK: - File System Observer (FSEvents Dispatch Source)
    
    private func startFolderMonitor() {
        folderFileDescriptor = open(rootFolderURL.path, O_EVTONLY)
        guard folderFileDescriptor != -1 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: folderFileDescriptor,
            eventMask: [.write, .extend, .delete, .rename],
            queue: DispatchQueue.global(qos: .utility)
        )
        
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.loadNotes()
            }
        }
        
        source.setCancelHandler { [weak self] in
            if let fd = self?.folderFileDescriptor, fd != -1 {
                close(fd)
            }
        }
        
        self.folderMonitorSource = source
        source.resume()
    }
    
    private nonisolated func stopFolderMonitor() {
        folderMonitorSource?.cancel()
    }
}
