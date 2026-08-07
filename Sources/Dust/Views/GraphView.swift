import SwiftUI

struct GraphNode: Identifiable {
    let id: UUID
    let title: String
    var position: CGPoint
    var velocity: CGPoint = .zero
    let linkCount: Int
}

struct GraphEdge: Identifiable {
    let id = UUID()
    let sourceId: UUID
    let targetId: UUID
}

final class GraphViewState: ObservableObject {
    @Published var nodes: [GraphNode] = []
    @Published var edges: [GraphEdge] = []
    @Published var selectedNodeTitle: String? = nil
}

struct GraphView: View {
    @ObservedObject var store: NoteStore
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var graphState = GraphViewState()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar with Liquid Glass styling
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "circle.hexagonpath.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.linearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("Knowledge Graph Visualizer")
                        .font(.title3.bold())
                }
                Spacer()
                
                HStack(spacing: 12) {
                    Text("\(graphState.nodes.count) Notes • \(graphState.edges.count) Connections")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.thinMaterial))
                        .foregroundColor(.secondary)
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Visual Canvas
            GeometryReader { geo in
                ZStack {
                    LinearGradient(
                        colors: [Color.black.opacity(0.85), Color.indigo.opacity(0.3), Color.black.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    Canvas { context, size in
                        // Draw Edges with radiant glow
                        for edge in graphState.edges {
                            if let source = graphState.nodes.first(where: { $0.id == edge.sourceId }),
                               let target = graphState.nodes.first(where: { $0.id == edge.targetId }) {
                                var path = Path()
                                path.move(to: source.position)
                                path.addLine(to: target.position)
                                context.stroke(
                                    path,
                                    with: .linearGradient(
                                        Gradient(colors: [Color.cyan.opacity(0.6), Color.purple.opacity(0.6)]),
                                        startPoint: source.position,
                                        endPoint: target.position
                                    ),
                                    lineWidth: 2.0
                                )
                            }
                        }
                        
                        // Draw Nodes with spatial glow rings
                        for node in graphState.nodes {
                            let isSelected = node.title == graphState.selectedNodeTitle
                            let baseRadius: CGFloat = CGFloat(12 + min(node.linkCount * 4, 24))
                            let rect = CGRect(
                                x: node.position.x - baseRadius,
                                y: node.position.y - baseRadius,
                                width: baseRadius * 2,
                                height: baseRadius * 2
                            )
                            
                            // Outer Glow Ring
                            let glowRect = rect.insetBy(dx: -6, dy: -6)
                            let glowColor = isSelected ? Color.cyan : (node.linkCount > 0 ? Color.purple : Color.blue)
                            context.fill(Path(ellipseIn: glowRect), with: .color(glowColor.opacity(0.35)))
                            
                            // Node Solid Core
                            context.fill(Path(ellipseIn: rect), with: .color(glowColor))
                            
                            // Node Label text
                            let text = Text(node.title)
                                .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                                .foregroundColor(.white)
                            context.draw(text, at: CGPoint(x: node.position.x, y: node.position.y + baseRadius + 8), anchor: .top)
                        }
                    }
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                if let tapped = graphState.nodes.first(where: {
                                    hypot($0.position.x - value.location.x, $0.position.y - value.location.y) < 30
                                }) {
                                    graphState.selectedNodeTitle = tapped.title
                                    store.selectedNoteId = tapped.id
                                    dismiss()
                                }
                            }
                    )
                }
                .onAppear {
                    buildGraph(in: geo.size)
                }
                .onChange(of: geo.size) { _, newSize in
                    buildGraph(in: newSize)
                }
            }
        }
        .frame(minWidth: 750, minHeight: 520)
    }
    
    private func buildGraph(in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.35
        
        var generatedNodes: [GraphNode] = []
        var generatedEdges: [GraphEdge] = []
        
        let count = store.notes.count
        guard count > 0 else { return }
        
        for (index, note) in store.notes.enumerated() {
            let angle = (Double(index) / Double(count)) * 2 * .pi
            let x = center.x + CGFloat(cos(angle)) * radius + CGFloat.random(in: -25...25)
            let y = center.y + CGFloat(sin(angle)) * radius + CGFloat.random(in: -25...25)
            
            let linksCount = note.wikiLinks.count + store.backlinks(for: note.title).count
            let node = GraphNode(id: note.id, title: note.title, position: CGPoint(x: x, y: y), linkCount: linksCount)
            generatedNodes.append(node)
        }
        
        // Build Edges from WikiLinks
        for note in store.notes {
            for linkTarget in note.wikiLinks {
                if let targetNote = store.notes.first(where: { $0.title.lowercased() == linkTarget.lowercased() }) {
                    generatedEdges.append(GraphEdge(sourceId: note.id, targetId: targetNote.id))
                }
            }
        }
        
        graphState.nodes = generatedNodes
        graphState.edges = generatedEdges
    }
}


