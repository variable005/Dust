import SwiftUI
import AppKit

final class FocusViewState: ObservableObject {
    @Published var content: String = ""
    @Published var isPreviewMode: Bool = false
}

struct FullScreenFocusView: View {
    let note: Note
    @ObservedObject var store: NoteStore
    var onDismiss: () -> Void
    
    @StateObject private var focusState = FocusViewState()
    @AppStorage("isAutoCorrectEnabled") private var isAutoCorrectEnabled: Bool = true
    @AppStorage("editorFontFamily") private var rawFontFamily: String = EditorFontFamily.mono.rawValue
    
    private var fontFamily: EditorFontFamily {
        EditorFontFamily(rawValue: rawFontFamily) ?? .mono
    }
    
    var wordCount: Int {
        let components = focusState.content.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.count
    }
    
    var charCount: Int {
        focusState.content.count
    }
    
    var readingTimeMinutes: Int {
        max(1, Int(ceil(Double(wordCount) / 200.0)))
    }
    
    var body: some View {
        ZStack {
            // Ambient Backdrop
            LinearGradient(
                colors: [Color.black.opacity(0.88), Color.indigo.opacity(0.2), Color.black.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Control Bar
                HStack {
                    // Exit Button
                    Button(action: {
                        onDismiss()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 13, weight: .bold))
                            Text("Exit Focus Mode")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Exit Focus Mode (Esc / Cmd+Shift+F)")
                    
                    Spacer()
                    
                    // Note Title Indicator
                    HStack(spacing: 8) {
                        Text(note.iconEmoji ?? "📝")
                            .font(.title3)
                        Text(note.title)
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    
                    Spacer()
                    
                    // Edit / Preview Toggle & Auto-Correct Control
                    HStack(spacing: 12) {
                        Button(action: { isAutoCorrectEnabled.toggle() }) {
                            HStack(spacing: 5) {
                                Image(systemName: isAutoCorrectEnabled ? "text.badge.checkmark" : "text.badge.xmark")
                                Text(isAutoCorrectEnabled ? "Auto-Correct On" : "Auto-Correct Off")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isAutoCorrectEnabled ? Color.cyan.opacity(0.25) : Color.white.opacity(0.1))
                            )
                            .foregroundColor(isAutoCorrectEnabled ? .cyan : .white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help(isAutoCorrectEnabled ? "Auto-Correct is Enabled" : "Auto-Correct is Disabled")
                        
                        Picker("Mode", selection: $focusState.isPreviewMode) {
                            Label("Write", systemImage: "square.and.pencil").tag(false)
                            Label("Preview", systemImage: "eye").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Writing Canvas
                ZStack {
                    if focusState.isPreviewMode {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                MarkdownPreview(content: focusState.content, store: store, fontFamily: fontFamily)
                            }
                            .padding(.horizontal, 40)
                            .padding(.top, 30)
                            .padding(.bottom, 100)
                            .frame(maxWidth: 850, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    } else {
                        HStack {
                            Spacer(minLength: 0)
                            MacEditorView(
                                text: $focusState.content,
                                isAutoCorrectEnabled: isAutoCorrectEnabled,
                                fontFamily: fontFamily,
                                onPasteImage: { data, ext in
                                    if let relativePath = store.saveImageAsset(data: data, extension: ext) {
                                        focusState.content += "\n![Image](\(relativePath))\n"
                                    }
                                },
                                onDropImageFile: { url in
                                    if let data = try? Data(contentsOf: url),
                                       let relativePath = store.saveImageAsset(data: data, extension: url.pathExtension.lowercased()) {
                                        focusState.content += "\n![Image](\(relativePath))\n"
                                    }
                                }
                            )
                            .padding(.horizontal, 40)
                            .padding(.top, 24)
                            .padding(.bottom, 100)
                            .frame(maxWidth: 880)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .onChange(of: focusState.content) { oldValue, newValue in
                    store.updateNoteContent(id: note.id, newContent: newValue)
                }
            }
            
            // Bottom Status Capsule
            VStack {
                Spacer()
                
                HStack(spacing: 18) {
                    HStack(spacing: 5) {
                        Image(systemName: "text.word.spacing")
                        Text("\(wordCount) words")
                    }
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 5) {
                        Image(systemName: "character")
                        Text("\(charCount) chars")
                    }
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                        Text("\(readingTimeMinutes) min read")
                    }
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text("Press Esc to exit")
                        .font(.caption.bold())
                        .foregroundColor(.cyan)
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            focusState.content = note.content
        }
        // Capture Escape key to exit focus mode
        .background(
            KeyShortcutHandler(onEscape: onDismiss, onToggleFocus: onDismiss)
        )
    }
}

// Custom Key Shortcut Listener View
private struct KeyShortcutHandler: NSViewRepresentable {
    var onEscape: () -> Void
    var onToggleFocus: () -> Void
    
    func makeNSView(context: Context) -> KeyView {
        let view = KeyView()
        view.onEscape = onEscape
        view.onToggleFocus = onToggleFocus
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }
    
    func updateNSView(_ nsView: KeyView, context: Context) {
        nsView.onEscape = onEscape
        nsView.onToggleFocus = onToggleFocus
    }
    
    class KeyView: NSView {
        var onEscape: (() -> Void)?
        var onToggleFocus: (() -> Void)?
        
        override var acceptsFirstResponder: Bool { true }
        
        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53 { // ESC key
                onEscape?()
                return
            }
            // Cmd + Shift + F
            if event.modifierFlags.contains([.command, .shift]) && event.charactersIgnoringModifiers?.lowercased() == "f" {
                onToggleFocus?()
                return
            }
            super.keyDown(with: event)
        }
    }
}
