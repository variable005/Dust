import SwiftUI
import AppKit

final class EditorViewState: ObservableObject {
    @Published var isPreviewMode: Bool = false
}

struct MarkdownEditorView: View {
    let note: Note
    var onContentChange: (String) -> Void
    
    @StateObject private var viewState = EditorViewState()
    
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
                        if viewState.isPreviewMode {
                            ScrollView {
                                MarkdownPreview(content: note.content)
                                    .padding(.horizontal, horizontalMargin)
                                    .padding(.top, 24)
                                    .padding(.bottom, 90)
                                    .frame(maxWidth: 800, alignment: .leading)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .background(.ultraThinMaterial)
                        } else {
                            HStack {
                                Spacer(minLength: 0)
                                TextEditor(text: Binding(
                                    get: { note.content },
                                    set: { newValue in
                                        onContentChange(newValue)
                                    }
                                ))
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .lineSpacing(6)
                                .scrollContentBackground(.hidden)
                                .background(.ultraThinMaterial)
                                .padding(.horizontal, horizontalMargin)
                                .padding(.top, 20)
                                .padding(.bottom, 90)
                                .frame(maxWidth: 850)
                                Spacer(minLength: 0)
                            }
                            .background(.ultraThinMaterial)
                        }
                    }
                }
                
                // Floating Liquid Glass Ornaments Bar (Apple Design Pattern)
                floatingOrnamentsBar(isCompact: isCompact)
                    .padding(.bottom, 16)
            }
        }
    }
    
    // MARK: - Top Mode Toolbar
    
    private func editorToolbar(isCompact: Bool) -> some View {
        HStack(spacing: 12) {
            Picker("View Mode", selection: $viewState.isPreviewMode) {
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
            
            Spacer()
            
            if !note.tags.isEmpty && !isCompact {
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    ForEach(Array(note.tags).prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.blue.opacity(0.1)))
            }
            
            Text(note.title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
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
    
    // MARK: - Text Insertion Helper
    
    private func insertText(_ prefix: String, suffix: String = "") {
        let newContent = note.content + "\(prefix)\(suffix)"
        onContentChange(newContent)
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

