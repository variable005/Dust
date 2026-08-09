import SwiftUI
import AppKit

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
    @StateObject private var viewModel = EditorViewModel()
    @FocusState private var isFocused: Bool
    
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
            let horizontalMargin = max(20, min(geometry.size.width * 0.08, 56))
            
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Top Header / Editor Mode Switcher Bar
                    editorToolbar(isCompact: isCompact)
                    
                    Divider()
                    
                    // Main Editor / Preview Canvas
                    ZStack {
                        if viewModel.isPreviewMode {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 12) {
                                    noteBannerHeader
                                    MarkdownPreview(content: viewModel.content)
                                }
                                .padding(.horizontal, horizontalMargin)
                                .padding(.top, 12)
                                .padding(.bottom, 90)
                                .frame(maxWidth: 800, alignment: .leading)
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .background(.ultraThinMaterial)
                        } else {
                            VStack(spacing: 0) {
                                noteBannerHeader
                                HStack {
                                    Spacer(minLength: 0)
                                    MacEditorView(text: $viewModel.content, isAutoCorrectEnabled: isAutoCorrectEnabled)
                                        .padding(.horizontal, horizontalMargin)
                                        .padding(.top, 12)
                                        .padding(.bottom, 90)
                                        .frame(maxWidth: 850)
                                    Spacer(minLength: 0)
                                }
                            }
                            .background(.ultraThinMaterial)
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
                    
                    // Floating Liquid Glass Ornaments Bar (Apple Design Pattern)
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
    
    // MARK: - Top Mode Toolbar
    
    private func editorToolbar(isCompact: Bool) -> some View {
        HStack(spacing: 12) {
            Picker("View Mode", selection: $viewModel.isPreviewMode) {
                if isCompact {
                    Image(systemName: "pencil").tag(false)
                    Image(systemName: "eye.fill").tag(true)
                } else {
                    Label("Edit", systemImage: "pencil").tag(false)
                    Label("Preview", systemImage: "eye.fill").tag(true)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            
            Button(action: { isAutoCorrectEnabled.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: isAutoCorrectEnabled ? "text.badge.checkmark" : "text.badge.xmark")
                    if !isCompact {
                        Text(isAutoCorrectEnabled ? "Auto-Correct On" : "Auto-Correct Off")
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isAutoCorrectEnabled ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.06))
                )
                .foregroundColor(isAutoCorrectEnabled ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(isAutoCorrectEnabled ? "Auto-Correct is Enabled" : "Auto-Correct is Disabled")
            
            Spacer(minLength: 12)
            
            Text(note.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Floating Liquid Glass Ornament Bar
    
    private func floatingOrnamentsBar(isCompact: Bool) -> some View {
        HStack(spacing: 14) {
            // Quick Formatting Tools
            HStack(spacing: 8) {
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
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.primary)
            
            if !isCompact {
                Divider()
                    .frame(height: 16)
                
                // Dynamic Note Stats Pill
                HStack(spacing: 8) {
                    Label("\(note.wordCount) Words", systemImage: "text.alignleft")
                    Text("•")
                    Label("\(note.readingTimeMinutes)m read", systemImage: "clock")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 4)
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isCompact)
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
            .frame(maxHeight: 140)
        }
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.22), radius: 12, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Banner & Frontmatter Helpers
    
    private var bannerPresets: [(id: String, name: String, colors: [Color])] {
        [
            ("indigo", "Cosmic Indigo", [.indigo, .purple, .blue]),
            ("sunset", "Sunset Flame", [.orange, .red, .purple]),
            ("emerald", "Emerald Dawn", [.mint, .teal, .green]),
            ("cyan", "Liquid Cyan", [.cyan, .blue, .indigo]),
            ("obsidian", "Obsidian Dark", [.black, .gray.opacity(0.8), .black])
        ]
    }
    
    private var emojiPresets: [String] {
        ["🚀", "📝", "💡", "🎨", "⚡️", "🧠", "🔬", "📌", "✨", "🔥", "📂", "💻", "📚", "🎯", "🌐"]
    }

    private func gradient(for style: String?) -> LinearGradient {
        let preset = bannerPresets.first(where: { $0.id == style }) ?? bannerPresets[0]
        return LinearGradient(colors: preset.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func updateFrontmatter(banner: String?, icon: String?) {
        var newContent = viewModel.content
        var currentBanner = note.bannerStyle
        var currentIcon = note.iconEmoji
        
        if let b = banner { currentBanner = b.isEmpty ? nil : b }
        if let i = icon { currentIcon = i.isEmpty ? nil : i }
        
        // Remove existing frontmatter block if present
        if newContent.hasPrefix("---") {
            if let closingRange = newContent.range(of: "---", options: [], range: newContent.index(newContent.startIndex, offsetBy: 3)..<newContent.endIndex) {
                newContent.removeSubrange(newContent.startIndex...closingRange.upperBound)
                newContent = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Build new YAML frontmatter block
        if currentBanner != nil || currentIcon != nil {
            var front = "---\n"
            if let b = currentBanner { front += "banner: \"\(b)\"\n" }
            if let i = currentIcon { front += "icon: \"\(i)\"\n" }
            front += "---\n\n"
            newContent = front + newContent
        }
        
        viewModel.content = newContent
    }

    private var noteBannerHeader: some View {
        VStack(spacing: 0) {
            if let banner = note.bannerStyle {
                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(gradient(for: banner))
                        .frame(height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    
                    HStack {
                        Spacer()
                        Menu {
                            Text("Change Banner Style").font(.caption)
                            Divider()
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
                .padding(.leading, note.iconEmoji == nil ? 16 : 0)
                .padding(.top, note.bannerStyle != nil ? 6 : 10)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Text Insertion Helper
    
    private func insertText(_ prefix: String, suffix: String = "") {
        viewModel.content += "\(prefix)\(suffix)"
    }
}

// MARK: - Styled Markdown Preview Component

struct MarkdownPreview: View {
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            let lines = content.components(separatedBy: .newlines)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                parseLine(line)
            }
        }
    }
    
    @ViewBuilder
    private func parseLine(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        if trimmed.hasPrefix("# ") {
            Text(trimmed.dropFirst(2))
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.primary)
                .padding(.top, 4)
        } else if trimmed.hasPrefix("## ") {
            Text(trimmed.dropFirst(3))
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.top, 4)
        } else if trimmed.hasPrefix("### ") {
            Text(trimmed.dropFirst(4))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.top, 2)
        } else if trimmed.hasPrefix("- [ ] ") {
            HStack(spacing: 8) {
                Image(systemName: "square")
                    .foregroundColor(.secondary)
                Text(trimmed.dropFirst(6))
                    .font(.system(size: 14))
            }
        } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.square.fill")
                    .foregroundColor(.blue)
                Text(trimmed.dropFirst(6))
                    .font(.system(size: 14))
                    .strikethrough()
                    .foregroundColor(.secondary)
            }
        } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            HStack(alignment: .top, spacing: 8) {
                Text("•").font(.body).bold().foregroundColor(.blue)
                Text(trimmed.dropFirst(2))
                    .font(.system(size: 14))
            }
        } else if trimmed.hasPrefix("```") {
            Divider()
        } else if trimmed.isEmpty {
            Spacer().frame(height: 4)
        } else {
            Text(formattedMarkdown(trimmed))
                .font(.system(size: 14))
                .lineSpacing(5)
        }
    }
    
    private func formattedMarkdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

// MARK: - Native AppKit NSTextView Wrapper for Reliable Keyboard Focus

struct MacEditorView: NSViewRepresentable {
    @Binding var text: String
    var isAutoCorrectEnabled: Bool = true
    
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
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
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
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = NSColor.textColor
        textView.drawsBackground = false
        
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
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        if textView.isAutomaticSpellingCorrectionEnabled != isAutoCorrectEnabled {
            textView.isContinuousSpellCheckingEnabled = isAutoCorrectEnabled
            textView.isGrammarCheckingEnabled = isAutoCorrectEnabled
            textView.isAutomaticSpellingCorrectionEnabled = isAutoCorrectEnabled
            textView.isAutomaticTextReplacementEnabled = isAutoCorrectEnabled
        }
    }
}

