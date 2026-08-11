import SwiftUI
import AppKit
import UniformTypeIdentifiers
import WebKit

@MainActor
public struct NoteExporter {
    
    // MARK: - Export Markdown
    
    public static func exportToMarkdown(note: Note) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = sanitizeFilename(note.title) + ".md"
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            try? note.content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    // MARK: - Export Plain Text
    
    public static func exportToPlainText(note: Note) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = sanitizeFilename(note.title) + ".txt"
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            let plain = stripMarkdownSymbols(note.bodyText)
            try? plain.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    // MARK: - Export HTML
    
    public static func exportToHTML(note: Note, store: NoteStore) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = sanitizeFilename(note.title) + ".html"
        panel.allowedContentTypes = [.html]
        if panel.runModal() == .OK, let url = panel.url {
            let htmlContent = generateHTML(note: note, store: store)
            try? htmlContent.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    // MARK: - Export PDF
    
    public static func exportToPDF(note: Note, store: NoteStore) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = sanitizeFilename(note.title) + ".pdf"
        panel.allowedContentTypes = [.pdf]
        if panel.runModal() == .OK, let destinationURL = panel.url {
            let htmlContent = generateHTML(note: note, store: store)
            
            let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
            webView.loadHTMLString(htmlContent, baseURL: store.rootFolderURL)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                webView.createPDF(configuration: WKPDFConfiguration()) { result in
                    switch result {
                    case .success(let data):
                        do {
                            try data.write(to: destinationURL)
                        } catch {
                            print("Failed to save PDF: \(error)")
                        }
                    case .failure(let error):
                        print("PDF Export failed: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - HTML Generator
    
    private static func generateHTML(note: Note, store: NoteStore) -> String {
        let title = note.title
        var bodyHTML = ""
        
        // Add Banner Image if present
        if let banner = note.bannerStyle {
            let imageURL = store.resolveImagePath(banner)
            if FileManager.default.fileExists(atPath: imageURL.path) {
                bodyHTML += """
                <div class="cover-banner">
                    <img src="file://\(imageURL.path)" alt="Cover Banner" />
                </div>
                """
            } else if banner != "obsidian" {
                bodyHTML += """
                <div class="cover-banner preset-\(banner)"></div>
                """
            }
        }
        
        // Title Header
        bodyHTML += "<h1 class=\"note-title\">"
        if let icon = note.iconEmoji {
            bodyHTML += "<span class=\"note-icon\">\(icon)</span> "
        }
        bodyHTML += "\(title)</h1>\n"
        
        // Convert Markdown lines to HTML
        let lines = note.bodyText.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                bodyHTML += "<h1>\(trimmed.dropFirst(2))</h1>\n"
            } else if trimmed.hasPrefix("## ") {
                bodyHTML += "<h2>\(trimmed.dropFirst(3))</h2>\n"
            } else if trimmed.hasPrefix("### ") {
                bodyHTML += "<h3>\(trimmed.dropFirst(4))</h3>\n"
            } else if trimmed.hasPrefix("- [ ] ") {
                bodyHTML += "<p><input type=\"checkbox\" disabled> \(trimmed.dropFirst(6))</p>\n"
            } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                bodyHTML += "<p><input type=\"checkbox\" checked disabled> <del>\(trimmed.dropFirst(6))</del></p>\n"
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                bodyHTML += "<ul><li>\(trimmed.dropFirst(2))</li></ul>\n"
            } else if trimmed.isEmpty {
                bodyHTML += "<br/>\n"
            } else {
                bodyHTML += "<p>\(trimmed)</p>\n"
            }
        }
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <title>\(title)</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    margin: 40px auto;
                    max-width: 760px;
                    line-height: 1.6;
                    color: #1f2937;
                    background: #ffffff;
                    padding: 0 20px;
                }
                .cover-banner {
                    width: 100%;
                    height: 180px;
                    border-radius: 12px;
                    overflow: hidden;
                    margin-bottom: 24px;
                    background: #111827;
                }
                .cover-banner img {
                    width: 100%;
                    height: 100%;
                    object-fit: cover;
                }
                .cover-banner.preset-indigo { background: linear-gradient(135deg, #4f46e5, #7c3aed); }
                .cover-banner.preset-sunset { background: linear-gradient(135deg, #f97316, #ef4444); }
                .cover-banner.preset-emerald { background: linear-gradient(135deg, #0d9488, #10b981); }
                .cover-banner.preset-cyan { background: linear-gradient(135deg, #06b6d4, #3b82f6); }
                .note-title {
                    font-size: 32px;
                    font-weight: 800;
                    margin-bottom: 24px;
                    color: #111827;
                }
                .note-icon {
                    margin-right: 8px;
                }
                h1 { font-size: 26px; border-bottom: 1px solid #e5e7eb; padding-bottom: 6px; }
                h2 { font-size: 22px; }
                h3 { font-size: 18px; }
                p { margin: 8px 0; }
                ul { padding-left: 20px; }
                li { margin: 4px 0; }
            </style>
        </head>
        <body>
            \(bodyHTML)
        </body>
        </html>
        """
    }
    
    // MARK: - Helpers
    
    private static func sanitizeFilename(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return name.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
    
    private static func stripMarkdownSymbols(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "!\\[([^\\]]*)\\]\\(([^\\)]+)\\)", with: "[Image: $1]", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\(([^\\)]+)\\)", with: "$1", options: .regularExpression)
        return result
    }
}
