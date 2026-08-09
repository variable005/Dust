import Foundation

public struct Note: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var relativePath: String // e.g. "Work/ProjectPlan.md" or "Untitled.md"
    public var content: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var isPinned: Bool
    public var isFavorite: Bool
    public var isTrashed: Bool
    
    public init(
        id: UUID = UUID(),
        relativePath: String,
        content: String,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        isPinned: Bool = false,
        isFavorite: Bool = false,
        isTrashed: Bool = false
    ) {
        self.id = id
        self.relativePath = relativePath
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.isTrashed = isTrashed
    }
    
    // MARK: - Derived Properties
    
    /// File basename without extension (e.g., "ProjectPlan")
    public var title: String {
        let name = (relativePath as NSString).lastPathComponent
        let rawName = (name as NSString).deletingPathExtension
        
        // If content starts with a Markdown H1 header (`# My Title`), use that if present
        if let firstLine = content.components(separatedBy: .newlines).first,
           firstLine.hasPrefix("# ") {
            let headerTitle = firstLine.dropFirst(2).trimmingCharacters(in: .whitespaces)
            if !headerTitle.isEmpty {
                return headerTitle
            }
        }
        return rawName.isEmpty ? "Untitled Note" : rawName
    }
    
    /// Subfolder folder path (e.g., "Work/Projects")
    public var folderPath: String {
        let parent = (relativePath as NSString).deletingLastPathComponent
        return parent == "." ? "" : parent
    }
    
    /// Clean snippet preview without Markdown symbols
    public var snippet: String {
        let lines = content.components(separatedBy: .newlines)
            .map { line -> String in
                var l = line.trimmingCharacters(in: .whitespaces)
                if l.hasPrefix("#") { l = l.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression) }
                if l.hasPrefix("* ") || l.hasPrefix("- ") { l = l.replacingOccurrences(of: "^[*\\-]\\s*", with: "", options: .regularExpression) }
                return l
            }
            .filter { !$0.isEmpty }
        
        // Skip title line if it matched H1
        let bodyLines = lines.dropFirst(content.hasPrefix("# ") ? 1 : 0)
        return bodyLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
    
    /// Extracted `#tags` (e.g., ["swift", "work/ideas"])
    public var tags: Set<String> {
        let pattern = "(?<=^|\\s)#([a-zA-Z0-9_/-]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsString = content as NSString
        let results = regex.matches(in: content, range: NSRange(location: 0, length: nsString.length))
        
        let tagArray = results.compactMap { result -> String? in
            guard result.numberOfRanges > 1 else { return nil }
            return nsString.substring(with: result.range(at: 1)).lowercased()
        }
        return Set(tagArray)
    }
    
    /// Extracted `[[WikiLinks]]` targets (e.g., ["Project Plan", "Meeting Notes"])
    public var wikiLinks: Set<String> {
        let pattern = "\\[\\[([^\\]]+)\\]\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsString = content as NSString
        let results = regex.matches(in: content, range: NSRange(location: 0, length: nsString.length))
        
        let links = results.compactMap { result -> String? in
            guard result.numberOfRanges > 1 else { return nil }
            let link = nsString.substring(with: result.range(at: 1)).trimmingCharacters(in: .whitespaces)
            return link.isEmpty ? nil : link
        }
        return Set(links)
    }
    
    /// Total word count
    public var wordCount: Int {
        let words = content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return words.count
    }
    
    /// Total character count
    public var characterCount: Int {
        return content.count
    }
    
    /// Estimated reading time in minutes (assuming 200 WPM)
    public var readingTimeMinutes: Int {
        let wpm = 200
        return max(1, Int(ceil(Double(wordCount) / Double(wpm))))
    }
}
