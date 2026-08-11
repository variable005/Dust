import SwiftUI
import AppKit
import UniformTypeIdentifiers

public enum EditorFontFamily: String, CaseIterable, Identifiable {
    case mono = "mono"
    case sans = "sans"
    case serif = "serif"
    case rounded = "rounded"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .mono: return "Monospace"
        case .sans: return "Sans-Serif"
        case .serif: return "Serif"
        case .rounded: return "Rounded"
        }
    }
    
    public var nsFont: NSFont {
        switch self {
        case .mono:
            return NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        case .sans:
            return NSFont.systemFont(ofSize: 14, weight: .regular)
        case .serif:
            if let font = NSFont(name: "New York", size: 14) ?? NSFont(name: "Georgia", size: 14) {
                return font
            }
            return NSFont.systemFont(ofSize: 14, weight: .regular)
        case .rounded:
            if let descriptor = NSFont.systemFont(ofSize: 14, weight: .regular).fontDescriptor.withDesign(.rounded),
               let font = NSFont(descriptor: descriptor, size: 14) {
                return font
            }
            return NSFont.systemFont(ofSize: 14, weight: .regular)
        }
    }
    
    public var swiftUIFontDesign: Font.Design {
        switch self {
        case .mono: return .monospaced
        case .sans: return .default
        case .serif: return .serif
        case .rounded: return .rounded
        }
    }
}

final class EditorViewModel: ObservableObject {
    @Published var content: String = ""
    @Published var isPreviewMode: Bool = false
    private var currentNoteId: UUID?
    
    func sync(with note: Note) {
        if currentNoteId != note.id {
            currentNoteId = note.id
            content = note.bodyText
        }
    }
}

struct MarkdownEditorView: View {
    let note: Note
    @ObservedObject var store: NoteStore
    var onContentChange: (String) -> Void
    
    @AppStorage("isAutoCorrectEnabled") private var isAutoCorrectEnabled: Bool = true
    @AppStorage("editorFontFamily") private var rawFontFamily: String = EditorFontFamily.mono.rawValue
    @StateObject private var viewModel = EditorViewModel()
    @FocusState private var isFocused: Bool
    
    private var fontFamily: EditorFontFamily {
        EditorFontFamily(rawValue: rawFontFamily) ?? .mono
    }
    
    // MARK: - Autocomplete Computation
    
    private var wikiLinkQuery: String? {
        guard let range = viewModel.content.range(of: "\\[\\[[^\\]]*$", options: .regularExpression) else { return nil }
        let raw = String(viewModel.content[range])
        return String(raw.dropFirst(2))
    }
    
    private var tagQuery: String? {
        guard let range = viewModel.content.range(of: "#[A-Za-z0-9_/-]*$", options: .regularExpression) else { return nil }
        let raw = String(viewModel.content[range])
        return String(raw.dropFirst(1))
    }
    
    private var matchingWikiLinks: [String] {
        guard let query = wikiLinkQuery else { return [] }
        let titles = store.notes.map { $0.title }
        if query.isEmpty { return titles }
        return titles.filter { $0.localizedCaseInsensitiveContains(query) }
    }
    
    private var matchingTags: [String] {
        guard let query = tagQuery else { return [] }
        let tags = store.tagCounts.map { $0.tag }
        if query.isEmpty { return tags }
        return tags.filter { $0.localizedCaseInsensitiveContains(query) }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 500
            let horizontalMargin = max(24, min(geometry.size.width * 0.1, 64))
            
            ZStack(alignment: .bottom) {
                // Main Editor / Preview Canvas
                ZStack {
                    if viewModel.isPreviewMode {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 14) {
                                noteBannerHeader
                                MarkdownPreview(content: viewModel.content, store: store, fontFamily: fontFamily)
                            }
                            .padding(.horizontal, horizontalMargin)
                            .padding(.top, 20)
                            .padding(.bottom, 90)
                            .frame(maxWidth: 780, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    } else {
                        VStack(spacing: 0) {
                            noteBannerHeader
                            HStack {
                                Spacer(minLength: 0)
                                MacEditorView(
                                    text: $viewModel.content,
                                    isAutoCorrectEnabled: isAutoCorrectEnabled,
                                    fontFamily: fontFamily,
                                    onPasteImage: { data, ext in
                                        if let relativePath = store.saveImageAsset(data: data, extension: ext) {
                                            insertText("![Image](\(relativePath))\n")
                                        }
                                    },
                                    onDropImageFile: { url in
                                        if let data = try? Data(contentsOf: url),
                                           let relativePath = store.saveImageAsset(data: data, extension: url.pathExtension.lowercased()) {
                                            insertText("![Image](\(relativePath))\n")
                                        }
                                    },
                                    onInsertTable: { insertTableTemplate() },
                                    onInsertImage: { selectImageFile() },
                                    onInsertCodeBlock: { insertText("\n```swift\n// Code snippet\n```\n") },
                                    onInsertBold: { insertText("**", suffix: "**") },
                                    onInsertItalic: { insertText("*", suffix: "*") },
                                    onInsertH1: { insertText("# ") },
                                    onInsertH2: { insertText("## ") },
                                    onInsertWikiLink: { insertText("[[", suffix: "]]") },
                                    onExportPDF: { NoteExporter.exportToPDF(note: note, store: store) },
                                    onExportHTML: { NoteExporter.exportToHTML(note: note, store: store) },
                                    onExportMD: { NoteExporter.exportToMarkdown(note: note) },
                                    onExportTXT: { NoteExporter.exportToPlainText(note: note) }
                                )
                                .padding(.horizontal, horizontalMargin)
                                .padding(.top, 16)
                                .padding(.bottom, 90)
                                .frame(maxWidth: 820)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                
                VStack(spacing: 8) {
                    // Autocomplete Suggestions Box
                    if wikiLinkQuery != nil && !matchingWikiLinks.isEmpty {
                        autocompleteBox(title: "WIKILINK SUGGESTIONS", items: matchingWikiLinks, icon: "link") { selectedTitle in
                            if let range = viewModel.content.range(of: "\\[\\[[^\\]]*$", options: .regularExpression) {
                                viewModel.content.replaceSubrange(range, with: "[[\(selectedTitle)]]")
                            }
                        }
                    } else if tagQuery != nil && !matchingTags.isEmpty {
                        autocompleteBox(title: "TAG SUGGESTIONS", items: matchingTags, icon: "number") { selectedTag in
                            if let range = viewModel.content.range(of: "#[A-Za-z0-9_/-]*$", options: .regularExpression) {
                                viewModel.content.replaceSubrange(range, with: "#\(selectedTag) ")
                            }
                        }
                    }
                    
                    // Floating Liquid Glass Ornaments Bar
                    floatingOrnamentsBar(isCompact: isCompact)
                }
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            viewModel.sync(with: note)
            isFocused = true
        }
        .onChange(of: note.id) { _, _ in
            viewModel.sync(with: note)
            isFocused = true
        }
        .onChange(of: viewModel.content) { _, newText in
            let fullContent = constructFullContent(body: newText, banner: note.bannerStyle, icon: note.iconEmoji)
            if fullContent != note.content {
                onContentChange(fullContent)
            }
        }
    }
    
    private func constructFullContent(body: String, banner: String?, icon: String?) -> String {
        var frontLines: [String] = []
        if let b = banner, !b.isEmpty { frontLines.append("banner: \"\(b)\"") }
        if let i = icon, !i.isEmpty { frontLines.append("icon: \"\(i)\"") }
        
        if frontLines.isEmpty {
            return body
        } else {
            return "---\n" + frontLines.joined(separator: "\n") + "\n---\n\n" + body
        }
    }
    
    // MARK: - Minimal Floating Liquid Glass Pod
    
    private func floatingOrnamentsBar(isCompact: Bool) -> some View {
        HStack(spacing: 12) {
            // Mode Switcher
            Picker("View Mode", selection: $viewModel.isPreviewMode) {
                Image(systemName: "pencil").tag(false)
                Image(systemName: "eye").tag(true)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 70)
            
            Divider()
                .frame(height: 14)
            
            // Formatting, Image & Font Tools
            HStack(spacing: 10) {
                Button(action: { insertText("# ") }) {
                    Image(systemName: "number")
                }
                .help("Heading H1")
                
                Button(action: { insertText("**", suffix: "**") }) {
                    Image(systemName: "bold")
                }
                .help("Bold")
                
                Button(action: { insertText("*", suffix: "*") }) {
                    Image(systemName: "italic")
                }
                .help("Italic")
                
                Button(action: { insertText("`", suffix: "`") }) {
                    Image(systemName: "code")
                }
                .help("Inline Code")
                
                Button(action: { insertText("\n```swift\n// Code\n```\n") }) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                }
                .help("Insert Code Block (```)")
                
                Button(action: { insertText("- [ ] ") }) {
                    Image(systemName: "checkmark.square")
                }
                .help("Checklist Item")
                
                Button(action: { insertText("[[", suffix: "]]") }) {
                    Image(systemName: "link")
                }
                .help("Insert WikiLink [[Note Title]]")
                
                Button(action: { selectImageFile() }) {
                    Image(systemName: "photo")
                }
                .help("Insert Image File")
                
                Button(action: { insertTableTemplate() }) {
                    Image(systemName: "tablecells")
                }
                .help("Insert Markdown Table")
                
                // Font Family Options Menu
                Menu {
                    Text("Font Options").font(.caption)
                    Divider()
                    ForEach(EditorFontFamily.allCases) { family in
                        Button(action: { rawFontFamily = family.rawValue }) {
                            HStack {
                                Text(family.displayName)
                                if fontFamily == family {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "textformat")
                }
                .menuStyle(.borderlessButton)
                .help("Font Options (Monospace, Sans-Serif, Serif, Rounded)")
                
                // Export Note Options Menu
                Menu {
                    Text("Export Note").font(.caption)
                    Divider()
                    Button(action: { NoteExporter.exportToPDF(note: note, store: store) }) {
                        Label("Export as PDF (.pdf)", systemImage: "doc.plaintext")
                    }
                    Button(action: { NoteExporter.exportToHTML(note: note, store: store) }) {
                        Label("Export as HTML (.html)", systemImage: "globe")
                    }
                    Button(action: { NoteExporter.exportToMarkdown(note: note) }) {
                        Label("Export as Markdown (.md)", systemImage: "doc.text")
                    }
                    Button(action: { NoteExporter.exportToPlainText(note: note) }) {
                        Label("Export as Plain Text (.txt)", systemImage: "text.alignleft")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .menuStyle(.borderlessButton)
                .help("Export Note (PDF, HTML, Markdown, Plain Text)")
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.primary.opacity(0.85))
            
            if !isCompact {
                Divider()
                    .frame(height: 14)
                
                // Note Stats & Auto-Correct Toggle
                HStack(spacing: 10) {
                    Text("\(note.wordCount)w")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Button(action: { isAutoCorrectEnabled.toggle() }) {
                        Image(systemName: isAutoCorrectEnabled ? "text.badge.checkmark" : "text.badge.xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isAutoCorrectEnabled ? .accentColor : .secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help(isAutoCorrectEnabled ? "Auto-Correct Enabled" : "Auto-Correct Disabled")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 3)
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isCompact)
    }
    
    private func selectImageFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? Data(contentsOf: url),
               let relativePath = store.saveImageAsset(data: data, extension: url.pathExtension.lowercased()) {
                insertText("![Image](\(relativePath))\n")
            }
        }
    }
    
    private func insertTableTemplate() {
        let snippet = "\n| Header 1 | Header 2 | Header 3 |\n| --- | --- | --- |\n| Item A | Details B | Status C |\n| Item D | Details E | Status F |\n"
        insertText(snippet)
    }
    
    // MARK: - Autocomplete Overlay Box
    
    private func autocompleteBox(title: String, items: [String], icon: String, onSelect: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.0)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(items.prefix(5), id: \.self) { item in
                        Button(action: { onSelect(item) }) {
                            HStack(spacing: 8) {
                                Image(systemName: icon)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text(item)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
        }
        .frame(maxWidth: 320, maxHeight: 180)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
        )
    }
    
    private func insertText(_ text: String, suffix: String = "") {
        if suffix.isEmpty {
            viewModel.content += text
        } else {
            viewModel.content += "\(text)\(suffix)"
        }
    }
    
    // MARK: - Banner Header
    
    private var bannerPresets: [(id: String, name: String)] = [
        ("indigo", "Indigo Night"),
        ("sunset", "Sunset Glow"),
        ("emerald", "Emerald Forest"),
        ("cyan", "Cyan Neon"),
        ("obsidian", "Obsidian Dark")
    ]
    
    private var emojiPresets: [String] = ["📝", "🚀", "💡", "🎨", "⚡️", "🧠", "🔥", "📌", "🌐"]
    
    private func gradient(for style: String) -> LinearGradient {
        switch style {
        case "indigo": return LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "sunset": return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "emerald": return LinearGradient(colors: [.teal, .green], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "cyan": return LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        default: return LinearGradient(colors: [.gray.opacity(0.8), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private func updateFrontmatter(banner: String?, icon: String?) {
        var currentBanner = note.bannerStyle
        var currentIcon = note.iconEmoji
        
        if let b = banner { currentBanner = b.isEmpty ? nil : b }
        if let i = icon { currentIcon = i.isEmpty ? nil : i }
        
        let fullContent = constructFullContent(body: viewModel.content, banner: currentBanner, icon: currentIcon)
        onContentChange(fullContent)
    }

    private func isCustomImageBanner(_ style: String) -> Bool {
        return style.contains("/") || style.contains(".")
    }

    private func selectCustomBannerImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? Data(contentsOf: url),
               let relativePath = store.saveImageAsset(data: data, extension: url.pathExtension.lowercased()) {
                updateFrontmatter(banner: relativePath, icon: nil)
            }
        }
    }

    private var noteBannerHeader: some View {
        VStack(spacing: 0) {
            if let banner = note.bannerStyle {
                ZStack(alignment: .bottomLeading) {
                    if isCustomImageBanner(banner) {
                        let imageURL = store.resolveImagePath(banner)
                        if let nsImage = NSImage(contentsOf: imageURL) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 130)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        } else {
                            Rectangle()
                                .fill(gradient(for: "obsidian"))
                                .frame(height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        Rectangle()
                            .fill(gradient(for: banner))
                            .frame(height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                    
                    HStack {
                        Spacer()
                        Menu {
                            Button("Upload Custom Image...") {
                                selectCustomBannerImage()
                            }
                            Divider()
                            Text("Color Presets").font(.caption2)
                            ForEach(bannerPresets, id: \.id) { preset in
                                Button(preset.name) {
                                    updateFrontmatter(banner: preset.id, icon: nil)
                                }
                            }
                            Divider()
                            Button("Remove Banner", role: .destructive) {
                                updateFrontmatter(banner: "", icon: nil)
                            }
                        } label: {
                            Label("Change Cover", systemImage: "photo.on.rectangle")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(.ultraThinMaterial))
                                .foregroundColor(.primary)
                        }
                        .menuStyle(.borderlessButton)
                        .padding(10)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            
            HStack(spacing: 12) {
                if let icon = note.iconEmoji {
                    Menu {
                        Text("Select Header Icon").font(.caption)
                        Divider()
                        ForEach(emojiPresets, id: \.self) { emoji in
                            Button("\(emoji) Emoji") {
                                updateFrontmatter(banner: nil, icon: emoji)
                            }
                        }
                        Divider()
                        Button("Remove Icon", role: .destructive) {
                            updateFrontmatter(banner: nil, icon: "")
                        }
                    } label: {
                        Text(icon)
                            .font(.system(size: 32))
                            .padding(8)
                            .background(Circle().fill(.thinMaterial))
                    }
                    .menuStyle(.borderlessButton)
                }
                
                HStack(spacing: 8) {
                    if note.bannerStyle == nil {
                        Menu {
                            Button("Upload Custom Image...") {
                                selectCustomBannerImage()
                            }
                            Divider()
                            ForEach(bannerPresets, id: \.id) { preset in
                                Button("Banner: \(preset.name)") {
                                    updateFrontmatter(banner: preset.id, icon: nil)
                                }
                            }
                        } label: {
                            Label("Add Cover Banner", systemImage: "photo")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                    }
                    
                    if note.iconEmoji == nil {
                        Menu {
                            ForEach(emojiPresets, id: \.self) { emoji in
                                Button("Icon: \(emoji)") {
                                    updateFrontmatter(banner: nil, icon: emoji)
                                }
                            }
                        } label: {
                            Label("Add Icon", systemImage: "face.smiling")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                    }
                }
                .padding(.top, note.bannerStyle != nil ? 8 : 12)
                
                Spacer()
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Markdown Preview with Typography, Tables & Syntax Highlighting

enum MarkdownBlock {
    case line(String)
    case table(headers: [String], rows: [[String]])
    case codeBlock(language: String, code: String)
}

struct MarkdownTableView: View {
    let headers: [String]
    let rows: [[String]]
    var fontFamily: EditorFontFamily = .mono
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { idx, header in
                    Text(header)
                        .font(.system(size: 13, weight: .bold, design: fontFamily.swiftUIFontDesign))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    if idx < headers.count - 1 {
                        Divider()
                    }
                }
            }
            .background(Color.primary.opacity(0.06))
            
            Divider()
            
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIdx, cell in
                        Text(cell)
                            .font(.system(size: 13, weight: .regular, design: fontFamily.swiftUIFontDesign))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                        if colIdx < row.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(rowIdx % 2 == 0 ? Color.clear : Color.primary.opacity(0.02))
                if rowIdx < rows.count - 1 {
                    Divider().opacity(0.5)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.02)))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .padding(.vertical, 6)
    }
}

final class CodeBlockState: ObservableObject {
    @Published var isCopied: Bool = false
}

struct MarkdownCodeBlockView: View {
    let language: String
    let code: String
    @StateObject private var state = CodeBlockState()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 5) {
                    Circle().fill(Color.red.opacity(0.7)).frame(width: 8, height: 8)
                    Circle().fill(Color.yellow.opacity(0.7)).frame(width: 8, height: 8)
                    Circle().fill(Color.green.opacity(0.7)).frame(width: 8, height: 8)
                    
                    Text(language.isEmpty ? "code" : language.lowercased())
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.leading, 6)
                }
                
                Spacer()
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    state.isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        state.isCopied = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: state.isCopied ? "checkmark" : "doc.on.doc")
                        Text(state.isCopied ? "Copied" : "Copy")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(state.isCopied ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.04))
            
            Divider()
                .opacity(0.5)
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(highlightedCode(code, language: language))
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .padding(12)
            }
        }
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .padding(.vertical, 4)
    }
    
    private func highlightedCode(_ codeStr: String, language: String) -> AttributedString {
        var attr = AttributedString(codeStr)
        let lang = language.lowercased()
        
        let keywords: Set<String>
        switch lang {
        case "swift":
            keywords = ["func", "var", "let", "struct", "class", "enum", "import", "return", "if", "else", "for", "in", "while", "guard", "switch", "case", "public", "private", "final", "override", "self", "true", "false", "nil", "@State", "@Binding", "@ObservedObject", "@Published", "@MainActor", "some", "View"]
        case "python", "py":
            keywords = ["def", "class", "import", "from", "return", "if", "elif", "else", "for", "in", "while", "with", "as", "try", "except", "lambda", "True", "False", "None", "self", "async", "await", "and", "or", "not"]
        case "javascript", "js", "typescript", "ts":
            keywords = ["const", "let", "var", "function", "return", "if", "else", "for", "while", "switch", "case", "import", "export", "default", "class", "extends", "async", "await", "true", "false", "null", "undefined", "this", "new", "type", "interface"]
        case "html", "xml", "css":
            keywords = ["html", "head", "body", "div", "span", "p", "a", "h1", "h2", "h3", "table", "tr", "td", "th", "style", "script", "color", "background", "margin", "padding", "font-family", "display", "flex"]
        case "json":
            keywords = ["true", "false", "null"]
        default:
            keywords = ["func", "def", "function", "var", "let", "const", "class", "struct", "import", "return", "if", "else", "true", "false"]
        }
        
        for word in keywords {
            if let regex = try? NSRegularExpression(pattern: "\\b\(NSRegularExpression.escapedPattern(for: word))\\b") {
                let nsString = codeStr as NSString
                let matches = regex.matches(in: codeStr, range: NSRange(location: 0, length: nsString.length))
                for match in matches {
                    if let range = Range(match.range, in: codeStr),
                       let attrRange = Range(range, in: attr) {
                        attr[attrRange].foregroundColor = Color.purple
                        attr[attrRange].inlinePresentationIntent = .stronglyEmphasized
                    }
                }
            }
        }
        
        if let regex = try? NSRegularExpression(pattern: "\"([^\"]*)\"|'([^']*)'") {
            let nsString = codeStr as NSString
            let matches = regex.matches(in: codeStr, range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                if let range = Range(match.range, in: codeStr),
                   let attrRange = Range(range, in: attr) {
                    attr[attrRange].foregroundColor = Color.green
                }
            }
        }
        
        if let regex = try? NSRegularExpression(pattern: "(//.*$|#.*$)", options: .anchorsMatchLines) {
            let nsString = codeStr as NSString
            let matches = regex.matches(in: codeStr, range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                if let range = Range(match.range, in: codeStr),
                   let attrRange = Range(range, in: attr) {
                    attr[attrRange].foregroundColor = Color.secondary
                }
            }
        }
        
        if let regex = try? NSRegularExpression(pattern: "\\b[0-9]+\\b") {
            let nsString = codeStr as NSString
            let matches = regex.matches(in: codeStr, range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                if let range = Range(match.range, in: codeStr),
                   let attrRange = Range(range, in: attr) {
                    attr[attrRange].foregroundColor = Color.orange
                }
            }
        }
        
        return attr
    }
}

struct MarkdownPreview: View {
    let content: String
    @ObservedObject var store: NoteStore
    var fontFamily: EditorFontFamily = .mono
    
    private var cleanContent: String {
        var text = content
        if let regex = try? NSRegularExpression(pattern: "(?s)^---.*?---", options: []) {
            let nsRange = NSRange(location: 0, length: (text as NSString).length)
            text = regex.stringByReplacingMatches(in: text, options: [], range: nsRange, withTemplate: "")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var blocks: [MarkdownBlock] {
        let rawLines = cleanContent.components(separatedBy: .newlines)
        var result: [MarkdownBlock] = []
        var currentTableLines: [String] = []
        var currentCodeLines: [String] = []
        var inCodeBlock = false
        var codeLang = ""
        
        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    result.append(.codeBlock(language: codeLang, code: currentCodeLines.joined(separator: "\n")))
                    currentCodeLines.removeAll()
                    inCodeBlock = false
                    codeLang = ""
                } else {
                    if !currentTableLines.isEmpty {
                        if let tableBlock = parseTableBlock(currentTableLines) {
                            result.append(tableBlock)
                        } else {
                            for tLine in currentTableLines { result.append(.line(tLine)) }
                        }
                        currentTableLines.removeAll()
                    }
                    inCodeBlock = true
                    codeLang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                continue
            }
            
            if inCodeBlock {
                currentCodeLines.append(line)
                continue
            }
            
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && trimmed.count > 1 {
                currentTableLines.append(trimmed)
            } else {
                if !currentTableLines.isEmpty {
                    if let tableBlock = parseTableBlock(currentTableLines) {
                        result.append(tableBlock)
                    } else {
                        for tLine in currentTableLines { result.append(.line(tLine)) }
                    }
                    currentTableLines.removeAll()
                }
                result.append(.line(line))
            }
        }
        
        if inCodeBlock && !currentCodeLines.isEmpty {
            result.append(.codeBlock(language: codeLang, code: currentCodeLines.joined(separator: "\n")))
        }
        
        if !currentTableLines.isEmpty {
            if let tableBlock = parseTableBlock(currentTableLines) {
                result.append(tableBlock)
            } else {
                for tLine in currentTableLines { result.append(.line(tLine)) }
            }
        }
        
        return result
    }
    
    private func parseTableBlock(_ lines: [String]) -> MarkdownBlock? {
        guard lines.count >= 2 else { return nil }
        let splitRows = lines.map { row -> [String] in
            let components = row.split(separator: "|", omittingEmptySubsequences: false)
            guard components.count >= 2 else { return [] }
            return components.dropFirst().dropLast().map { $0.trimmingCharacters(in: .whitespaces) }
        }
        
        guard !splitRows.isEmpty, !splitRows[0].isEmpty else { return nil }
        let headers = splitRows[0]
        
        let isSeparator = splitRows[1].allSatisfy { cell in
            cell.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "").isEmpty
        }
        
        guard isSeparator else { return nil }
        
        let dataRows = Array(splitRows.dropFirst(2))
        return .table(headers: headers, rows: dataRows)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .line(let line):
                    parseLine(line)
                case .table(let headers, let rows):
                    MarkdownTableView(headers: headers, rows: rows, fontFamily: fontFamily)
                case .codeBlock(let language, let code):
                    MarkdownCodeBlockView(language: language, code: code)
                }
            }
        }
    }
    
    @ViewBuilder
    private func parseLine(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        if let (alt, imagePath) = extractImageMarkdown(trimmed) {
            let fileURL = store.resolveImagePath(imagePath)
            if let nsImage = NSImage(contentsOf: fileURL) {
                VStack(alignment: .leading, spacing: 4) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 420)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                    if !alt.isEmpty {
                        Text(alt)
                            .font(.system(size: 11, design: fontFamily.swiftUIFontDesign))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .foregroundColor(.orange)
                    Text("Image not found: \(imagePath)")
                        .font(.system(size: 11, design: fontFamily.swiftUIFontDesign))
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.1)))
            }
        } else if trimmed.hasPrefix("# ") {
            Text(trimmed.dropFirst(2))
                .font(.system(size: 26, weight: .bold, design: fontFamily.swiftUIFontDesign))
                .foregroundColor(.primary)
                .padding(.top, 4)
        } else if trimmed.hasPrefix("## ") {
            Text(trimmed.dropFirst(3))
                .font(.system(size: 20, weight: .semibold, design: fontFamily.swiftUIFontDesign))
                .foregroundColor(.primary)
                .padding(.top, 4)
        } else if trimmed.hasPrefix("### ") {
            Text(trimmed.dropFirst(4))
                .font(.system(size: 16, weight: .semibold, design: fontFamily.swiftUIFontDesign))
                .foregroundColor(.primary)
                .padding(.top, 2)
        } else if trimmed.hasPrefix("- [ ] ") {
            HStack(spacing: 8) {
                Image(systemName: "square")
                    .foregroundColor(.secondary)
                Text(trimmed.dropFirst(6))
                    .font(.system(size: 14, design: fontFamily.swiftUIFontDesign))
            }
        } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.square.fill")
                    .foregroundColor(.blue)
                Text(trimmed.dropFirst(6))
                    .font(.system(size: 14, design: fontFamily.swiftUIFontDesign))
                    .strikethrough()
                    .foregroundColor(.secondary)
            }
        } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            HStack(alignment: .top, spacing: 8) {
                Text("•").font(.body).bold().foregroundColor(.blue)
                Text(trimmed.dropFirst(2))
                    .font(.system(size: 14, design: fontFamily.swiftUIFontDesign))
            }
        } else if trimmed.isEmpty {
            Spacer().frame(height: 4)
        } else {
            Text(formattedMarkdown(trimmed))
                .font(.system(size: 14, design: fontFamily.swiftUIFontDesign))
                .lineSpacing(5)
        }
    }
    
    private func extractImageMarkdown(_ text: String) -> (alt: String, path: String)? {
        let pattern = "^!\\[([^\\]]*)\\]\\(([^\\)]+)\\)$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        guard let result = results.first, result.numberOfRanges > 2 else { return nil }
        let alt = nsString.substring(with: result.range(at: 1))
        let path = nsString.substring(with: result.range(at: 2))
        return (alt, path)
    }
    
    private func formattedMarkdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

// MARK: - Native AppKit NSTextView Wrapper with Right-Click Context Menu & Callbacks

struct MacEditorView: NSViewRepresentable {
    @Binding var text: String
    var isAutoCorrectEnabled: Bool = true
    var fontFamily: EditorFontFamily = .mono
    var onPasteImage: ((Data, String) -> Void)?
    var onDropImageFile: ((URL) -> Void)?
    var onInsertTable: (() -> Void)?
    var onInsertImage: (() -> Void)?
    var onInsertCodeBlock: (() -> Void)?
    var onInsertBold: (() -> Void)?
    var onInsertItalic: (() -> Void)?
    var onInsertH1: (() -> Void)?
    var onInsertH2: (() -> Void)?
    var onInsertWikiLink: (() -> Void)?
    var onExportPDF: (() -> Void)?
    var onExportHTML: (() -> Void)?
    var onExportMD: (() -> Void)?
    var onExportTXT: (() -> Void)?
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacEditorView
        
        init(_ parent: MacEditorView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if parent.text != textView.string {
                parent.text = textView.string
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let contentSize = scrollView.contentSize
        
        let textView = ImageNSTextView(frame: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height))
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        if let container = textView.textContainer {
            container.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            container.widthTracksTextView = true
        }
        
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isContinuousSpellCheckingEnabled = isAutoCorrectEnabled
        textView.isGrammarCheckingEnabled = isAutoCorrectEnabled
        textView.isAutomaticSpellingCorrectionEnabled = isAutoCorrectEnabled
        textView.isAutomaticTextReplacementEnabled = isAutoCorrectEnabled
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.font = fontFamily.nsFont
        textView.textColor = NSColor.textColor
        textView.drawsBackground = false
        
        configureTextViewCallbacks(textView)
        textView.registerForDraggedTypes([.fileURL, .png, .tiff])
        
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? ImageNSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.font = fontFamily.nsFont
        configureTextViewCallbacks(textView)
        if textView.isAutomaticSpellingCorrectionEnabled != isAutoCorrectEnabled {
            textView.isContinuousSpellCheckingEnabled = isAutoCorrectEnabled
            textView.isGrammarCheckingEnabled = isAutoCorrectEnabled
            textView.isAutomaticSpellingCorrectionEnabled = isAutoCorrectEnabled
            textView.isAutomaticTextReplacementEnabled = isAutoCorrectEnabled
        }
    }
    
    private func configureTextViewCallbacks(_ textView: ImageNSTextView) {
        textView.onPasteImage = onPasteImage
        textView.onDropImage = onDropImageFile
        textView.onInsertTable = onInsertTable
        textView.onInsertImage = onInsertImage
        textView.onInsertCodeBlock = onInsertCodeBlock
        textView.onInsertBold = onInsertBold
        textView.onInsertItalic = onInsertItalic
        textView.onInsertH1 = onInsertH1
        textView.onInsertH2 = onInsertH2
        textView.onInsertWikiLink = onInsertWikiLink
        textView.onExportPDF = onExportPDF
        textView.onExportHTML = onExportHTML
        textView.onExportMD = onExportMD
        textView.onExportTXT = onExportTXT
    }
}

class ImageNSTextView: NSTextView {
    var onPasteImage: ((Data, String) -> Void)?
    var onDropImage: ((URL) -> Void)?
    var onInsertTable: (() -> Void)?
    var onInsertImage: (() -> Void)?
    var onInsertCodeBlock: (() -> Void)?
    var onInsertBold: (() -> Void)?
    var onInsertItalic: (() -> Void)?
    var onInsertH1: (() -> Void)?
    var onInsertH2: (() -> Void)?
    var onInsertWikiLink: (() -> Void)?
    var onExportPDF: (() -> Void)?
    var onExportHTML: (() -> Void)?
    var onExportMD: (() -> Void)?
    var onExportTXT: (() -> Void)?
    
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        
        // Formatting Section
        let formatItem = NSMenuItem(title: "Format Text", action: nil, keyEquivalent: "")
        let formatSub = NSMenu()
        formatSub.addItem(NSMenuItem(title: "Heading H1 (#)", action: #selector(ctxH1), keyEquivalent: ""))
        formatSub.addItem(NSMenuItem(title: "Heading H2 (##)", action: #selector(ctxH2), keyEquivalent: ""))
        formatSub.addItem(NSMenuItem(title: "Bold (**text**)", action: #selector(ctxBold), keyEquivalent: ""))
        formatSub.addItem(NSMenuItem(title: "Italic (*text*)", action: #selector(ctxItalic), keyEquivalent: ""))
        formatItem.submenu = formatSub
        menu.addItem(formatItem)
        
        // Insert Section
        let insertItem = NSMenuItem(title: "Insert Element", action: nil, keyEquivalent: "")
        let insertSub = NSMenu()
        insertSub.addItem(NSMenuItem(title: "Markdown Table", action: #selector(ctxTable), keyEquivalent: ""))
        insertSub.addItem(NSMenuItem(title: "Code Block (```)", action: #selector(ctxCodeBlock), keyEquivalent: ""))
        insertSub.addItem(NSMenuItem(title: "Image File...", action: #selector(ctxImage), keyEquivalent: ""))
        insertSub.addItem(NSMenuItem(title: "WikiLink [[Note]]", action: #selector(ctxWikiLink), keyEquivalent: ""))
        insertItem.submenu = insertSub
        menu.addItem(insertItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Standard Text Commands
        menu.addItem(NSMenuItem(title: "Cut", action: #selector(cut(_:)), keyEquivalent: "x"))
        menu.addItem(NSMenuItem(title: "Copy", action: #selector(copy(_:)), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "Paste", action: #selector(paste(_:)), keyEquivalent: "v"))
        menu.addItem(NSMenuItem(title: "Select All", action: #selector(selectAll(_:)), keyEquivalent: "a"))
        
        menu.addItem(NSMenuItem.separator())
        
        // Export Section
        let exportItem = NSMenuItem(title: "Export Note", action: nil, keyEquivalent: "")
        let exportSub = NSMenu()
        exportSub.addItem(NSMenuItem(title: "Export as PDF (.pdf)", action: #selector(ctxExportPDF), keyEquivalent: ""))
        exportSub.addItem(NSMenuItem(title: "Export as HTML (.html)", action: #selector(ctxExportHTML), keyEquivalent: ""))
        exportSub.addItem(NSMenuItem(title: "Export as Markdown (.md)", action: #selector(ctxExportMD), keyEquivalent: ""))
        exportSub.addItem(NSMenuItem(title: "Export as Plain Text (.txt)", action: #selector(ctxExportTXT), keyEquivalent: ""))
        exportItem.submenu = exportSub
        menu.addItem(exportItem)
        
        return menu
    }
    
    @objc private func ctxH1() { insertSnippetAtCursor("# ") }
    @objc private func ctxH2() { insertSnippetAtCursor("## ") }
    @objc private func ctxBold() { insertSnippetAtCursor("**", suffix: "**") }
    @objc private func ctxItalic() { insertSnippetAtCursor("*", suffix: "*") }
    @objc private func ctxTable() {
        let snippet = "\n| Header 1 | Header 2 | Header 3 |\n| --- | --- | --- |\n| Item A | Details B | Status C |\n| Item D | Details E | Status F |\n"
        insertSnippetAtCursor(snippet)
    }
    @objc private func ctxCodeBlock() { insertCodeBlockAtCursor() }
    @objc private func ctxImage() { onInsertImage?() }
    @objc private func ctxWikiLink() { insertSnippetAtCursor("[[", suffix: "]]") }
    @objc private func ctxExportPDF() { onExportPDF?() }
    @objc private func ctxExportHTML() { onExportHTML?() }
    @objc private func ctxExportMD() { onExportMD?() }
    @objc private func ctxExportTXT() { onExportTXT?() }
    
    public func insertSnippetAtCursor(_ prefix: String, suffix: String = "") {
        let range = selectedRange()
        let nsString = string as NSString
        
        if range.location != NSNotFound && range.length > 0 {
            let selectedText = nsString.substring(with: range)
            let replacement = "\(prefix)\(selectedText)\(suffix)"
            insertText(replacement, replacementRange: range)
        } else if range.location != NSNotFound {
            let replacement = "\(prefix)\(suffix)"
            insertText(replacement, replacementRange: range)
        } else {
            let replacement = "\(prefix)\(suffix)"
            insertText(replacement, replacementRange: NSRange(location: nsString.length, length: 0))
        }
    }
    
    public func insertCodeBlockAtCursor(language: String = "swift") {
        let range = selectedRange()
        let nsString = string as NSString
        
        if range.location != NSNotFound && range.length > 0 {
            let selectedText = nsString.substring(with: range)
            let replacement = "\n```\(language)\n\(selectedText)\n```\n"
            insertText(replacement, replacementRange: range)
        } else if range.location != NSNotFound {
            let replacement = "\n```\(language)\n// Write your \(language) code here\n```\n"
            insertText(replacement, replacementRange: range)
        } else {
            let replacement = "\n```\(language)\n// Write your \(language) code here\n```\n"
            insertText(replacement, replacementRange: NSRange(location: nsString.length, length: 0))
        }
    }
    
    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        
        if let data = pb.data(forType: .png) {
            onPasteImage?(data, "png")
            return
        } else if let data = pb.data(forType: .tiff), let img = NSImage(data: data), let pngData = img.pngData {
            onPasteImage?(pngData, "png")
            return
        }
        
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            if let imageURL = urls.first(where: { ["png", "jpg", "jpeg", "gif", "webp"].contains($0.pathExtension.lowercased()) }) {
                if let data = try? Data(contentsOf: imageURL) {
                    onPasteImage?(data, imageURL.pathExtension.lowercased())
                    return
                }
            }
        }
        
        super.paste(sender)
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pb = sender.draggingPasteboard
        if pb.canReadObject(forClasses: [NSURL.self], options: nil) {
            return .copy
        }
        return super.draggingEntered(sender)
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            if let imageURL = urls.first(where: { ["png", "jpg", "jpeg", "gif", "webp"].contains($0.pathExtension.lowercased()) }) {
                onDropImage?(imageURL)
                return true
            }
        }
        return super.performDragOperation(sender)
    }
}

extension NSImage {
    var pngData: Data? {
        guard let tiffData = tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmapImage.representation(using: .png, properties: [:])
    }
}
