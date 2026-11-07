//
//  ModDependencyGraphCanvasView.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftUI

/// Freeform-style whiteboard for browsing mod dependencies.
///
/// Nodes use a fixed automatic layout while the canvas can be panned and zoomed
/// like an infinite board.
public struct ModDependencyGraphCanvasView: View {
    public let layout: ModDependencyGraphLayout
    public let game: ModDependencyGraphGame
    public let projectIcons: [String: NSImage]

    @State private var zoom: CGFloat = 1
    @State private var magnifyStartZoom: CGFloat?
    @State private var selectedNodeIDs: Set<String> = []
    private let frames: [String: CGRect]
    private let parentsByNodeID: [String: [String]]
    private let canvasSize: CGSize

    public init(
        layout: ModDependencyGraphLayout,
        game: ModDependencyGraphGame,
        projectIcons: [String: NSImage],
    ) {
        self.layout = layout
        self.game = game
        self.projectIcons = projectIcons

        // Keep a modest margin around the graph. Large blank margins multiply
        // the backing surface size when the entire canvas is magnified.
        let width = max(layout.size.width + 160, 960)
        let height = max(layout.size.height + 160, 640)
        canvasSize = CGSize(width: width, height: height)

        let origin = CGPoint(
            x: (width - layout.size.width) / 2,
            y: (height - layout.size.height) / 2,
        )
        frames = layout.framesByNodeID.mapValues {
            $0.offsetBy(dx: origin.x, dy: origin.y)
        }

        var parents: [String: [String]] = [:]
        for edge in layout.edges {
            parents[edge.to, default: []].append(edge.from)
        }
        parentsByNodeID = parents
    }

    public var body: some View {
        ScrollView([.horizontal, .vertical]) {
            canvasContent
                .scaleEffect(zoom, anchor: .topLeading)
                .frame(
                    width: canvasSize.width * zoom,
                    height: canvasSize.height * zoom,
                    alignment: .topLeading,
                )
        }
        .defaultScrollAnchor(.center)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
        .simultaneousGesture(magnifyGesture)
    }

    private var canvasContent: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                drawModDependencyConnections(
                    edges: layout.edges,
                    frames: frames,
                    in: &context,
                )
            }
            .frame(width: canvasSize.width, height: canvasSize.height)

            ModDependencyGraphGameCard(game: game)
                .position(
                    x: canvasFrame(for: ModDependencyGraphLayout.gameNodeID).midX,
                    y: canvasFrame(for: ModDependencyGraphLayout.gameNodeID).midY,
                )

            ForEach(layout.nodes) { node in
                let frame = canvasFrame(for: node.id)
                ModDependencyGraphModCard(
                    node: node.mod,
                    icon: projectIcons[node.mod.projectId],
                    isSelected: selectedNodeIDs.contains(node.id),
                )
                .position(x: frame.midX, y: frame.midY)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        .contentShape(Rectangle())
        .gesture(selectionGesture)
    }

    private func canvasFrame(for nodeID: String) -> CGRect {
        frames[nodeID]!
    }

    private func ancestorSelection(for id: String) -> Set<String> {
        var result: Set<String> = [id]
        var pending = [id]

        while let current = pending.popLast() {
            for parentID in parentsByNodeID[current] ?? [] where result.insert(parentID).inserted {
                pending.append(parentID)
            }
        }

        return result
    }

    private var selectionGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let point = value.location
                if let hitNode = layout.nodes.first(where: {
                    canvasFrame(for: $0.id).contains(point)
                }) {
                    selectedNodeIDs = ancestorSelection(for: hitNode.id)
                } else {
                    selectedNodeIDs.removeAll()
                }
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let base = magnifyStartZoom ?? zoom
                magnifyStartZoom = base
                // Large magnification multiplies backing surface memory by the
                // square of the zoom factor.
                zoom = min(2, max(0.5, base * value.magnification))
            }
            .onEnded { _ in
                magnifyStartZoom = nil
            }
    }
}
