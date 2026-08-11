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
            content = note.content
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
                                    }
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
            if newText != note.content {
                onContentChange(newText)
            }
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
                .help("Code Snippet")
                
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
        var lines = viewModel.content.components(separatedBy: .newlines)
        var hasFrontmatter = false
        var frontmatterEndIndex = -1
        
        if lines.first == "---" {
            hasFrontmatter = true
            for (idx, line) in lines.enumerated().dropFirst() {
                if line == "---" {
                    frontmatterEndIndex = idx
                    break
                }
            }
        }
        
        var currentBanner = note.bannerStyle
        var currentIcon = note.iconEmoji
        
        if let b = banner { currentBanner = b.isEmpty ? nil : b }
        if let i = icon { currentIcon = i.isEmpty ? nil : i }
        
        var newFrontLines: [String] = []
        if let b = currentBanner { newFrontLines.append("banner: \"\(b)\"") }
        if let i = currentIcon { newFrontLines.append("icon: \"\(i)\"") }
        
        if hasFrontmatter && frontmatterEndIndex != -1 {
            lines.removeSubrange(0...frontmatterEndIndex)
        }
        
        var newContent = lines.joined(separator: "\n")
        if !newFrontLines.isEmpty {
            let front = "---\n" + newFrontLines.joined(separator: "\n") + "\n---\n\n"
            newContent = front + newContent
        }
        
        viewModel.content = newContent
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

// MARK: - Markdown Preview with Typography Options

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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            let lines = cleanContent.components(separatedBy: .newlines)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                parseLine(line)
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
        } else if trimmed.hasPrefix("```") {
            Divider()
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

// MARK: - Native AppKit NSTextView Wrapper with Typography Options

struct MacEditorView: NSViewRepresentable {
    @Binding var text: String
    var isAutoCorrectEnabled: Bool = true
    var fontFamily: EditorFontFamily = .mono
    var onPasteImage: ((Data, String) -> Void)?
    var onDropImageFile: ((URL) -> Void)?
    
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
        
        textView.onPasteImage = onPasteImage
        textView.onDropImage = onDropImageFile
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
        textView.onPasteImage = onPasteImage
        textView.onDropImage = onDropImageFile
        if textView.isAutomaticSpellingCorrectionEnabled != isAutoCorrectEnabled {
            textView.isContinuousSpellCheckingEnabled = isAutoCorrectEnabled
            textView.isGrammarCheckingEnabled = isAutoCorrectEnabled
            textView.isAutomaticSpellingCorrectionEnabled = isAutoCorrectEnabled
            textView.isAutomaticTextReplacementEnabled = isAutoCorrectEnabled
        }
    }
}

class ImageNSTextView: NSTextView {
    var onPasteImage: ((Data, String) -> Void)?
    var onDropImage: ((URL) -> Void)?
    
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
