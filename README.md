# Dust

**Dust** is a high-performance, 100% offline native macOS note-taking application built in **Swift** and **SwiftUI**. Designed around Apple's modern **Liquid Glass visual paradigm**, Dust stores your notes as plain Markdown (`.md`) files directly on your local file system with zero cloud dependencies or network latency.

---

## Features

- **Liquid Glass Aesthetics**: Native translucent materials (`.ultraThinMaterial`), dynamic background blending, and vibrant system icon highlights tailored for macOS.
- **Floating Formatting Ornaments**: Sleek bottom floating capsule pod providing instant access to Markdown formatting tools (`# Header`, `**Bold**`, `*Italic*`, `` `Code` ``, `- [ ] Checklist`, `[[WikiLink]]`) alongside real-time word count and reading duration metrics.
- **Native `.inspector` Panel**: System-integrated sliding drawer showing note location, document statistics, incoming backlinks, and outgoing connections.
- **Spatial Knowledge Graph**: Interactive visualizer representing note relationships (`[[WikiLinks]]`) with glowing spatial node particles and gradient connection lines.
- **Global Quick Scratchpad HUD**: Lightweight floating modal overlay to capture rapid thoughts from anywhere within the app.
- **Bi-Directional WikiLinks & Tagging**: Full support for `#nested/tags` and `[[WikiLink Note Titles]]` with instant title auto-creation.
- **100% Local Plain-Text Storage**: Your notes are stored as standard `.md` files in `~/Documents/Dust/` for total data ownership and compatibility with external editors.

---

## Architecture & Tech Stack

- **Language**: Swift 5.9+ (Swift 6 strict concurrency ready)
- **UI Framework**: SwiftUI & AppKit (`NavigationSplitView`, `.inspector`, `Canvas`)
- **State Management**: Reactive data flow with `@MainActor` thread-safety isolation
- **File System Observer**: Automatic file monitoring using low-level `DispatchSourceFileSystemObject` to keep UI synced with external edits

---

## How to Build & Run

### Prerequisites
- macOS 14.0 (Sonoma) or macOS 15.0+ (Sequoia)
- Swift 5.9+ / Xcode Command Line Tools

### 1. Clone the Repository
```bash
git clone https://github.com/variable005/Dust.git
cd Dust
```

### 2. Build the Executable
```bash
swift build
```

### 3. Run the App
```bash
swift run
```

Alternatively, open the directory in Xcode or build a standalone release binary:
```bash
swift build -c release
```
The compiled binary will be located at `.build/release/Dust`.

---

## Keyboard Shortcuts

| Action | Shortcut |
| :--- | :--- |
| **New Note** | `Cmd + N` |
| **Quick Scratchpad** | `Cmd + Shift + N` / Toolbar |
| **Save Quick Note** | `Cmd + Return` |
| **Close Modal / Graph** | `Escape` |
| **Toggle Inspector** | Toolbar Button |
