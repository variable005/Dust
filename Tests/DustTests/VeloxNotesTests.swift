import XCTest
@testable import VeloxNotes

final class VeloxNotesTests: XCTestCase {
    func testNoteParsingTagsAndWikiLinks() {
        let content = """
        # My Project Notes
        
        Working on #swift/macos and #ideas for the new release.
        Check out [[Welcome to Velox Notes]] and [[Architecture Overview]].
        """
        
        let note = Note(relativePath: "Work/Project.md", content: content)
        
        XCTAssertEqual(note.title, "My Project Notes")
        XCTAssertTrue(note.tags.contains("swift/macos"))
        XCTAssertTrue(note.tags.contains("ideas"))
        XCTAssertTrue(note.wikiLinks.contains("Welcome to Velox Notes"))
        XCTAssertTrue(note.wikiLinks.contains("Architecture Overview"))
        XCTAssertGreaterThan(note.wordCount, 10)
    }
    
    @MainActor
    func testNoteStoreCreationAndFiltering() {
        let tempFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = NoteStore(rootFolderURL: tempFolder)
        
        let newNote = store.createNote(title: "Test Note", content: "Content with #testtag and [[Other Note]]")
        XCTAssertEqual(store.notes.count, 1)
        XCTAssertEqual(store.filteredNotes.first?.id, newNote.id)
        
        store.searchQuery = "Test"
        XCTAssertEqual(store.filteredNotes.count, 1)
        
        store.searchQuery = "NonExistentQuery"
        XCTAssertEqual(store.filteredNotes.count, 0)
        
        // Clean up
        try? FileManager.default.removeItem(at: tempFolder)
    }
}
