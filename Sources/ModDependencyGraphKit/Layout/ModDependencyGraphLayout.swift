//
//  ModDependencyGraphLayout.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import CoreGraphics
import Foundation

/// Deterministic mind-map style layout for the mod dependency graph.
///
/// Every mod appears exactly once. Mods are arranged in columns from left to
/// right, with each dependency pointing to the mods that require it. Shared
/// libraries therefore fan out to several dependents from a single node.
/// Deterministic jitter and vertical relaxation keep the result from looking like
/// a rigid grid without introducing overlaps or changing between launches.
public struct ModDependencyGraphLayout: Sendable {
    public struct Node: Identifiable, Sendable {
        public let mod: ModDependencyGraph.Node
        public let frame: CGRect

        public var id: String { mod.id }

        public init(mod: ModDependencyGraph.Node, frame: CGRect) {
            self.mod = mod
            self.frame = frame
        }
    }

    public typealias Edge = ModDependencyGraph.Edge

    public static let gameNodeID = "game"
    public static let gameCardSize = CGSize(width: 210, height: 56)
    public static let nodeSize = CGSize(width: 210, height: 56)
    public static let layerSpacing: CGFloat = 96
    public static let verticalSpacing: CGFloat = 28
    public static let contentPadding: CGFloat = 44

    public let rootFrame: CGRect
    public let nodes: [Node]
    public let edges: [Edge]
    public let size: CGSize
    /// Node frames keyed by id, including the game root.
    public let framesByNodeID: [String: CGRect]

    public init(
        nodes graphNodes: [ModDependencyGraph.Node],
        edges graphEdges: [ModDependencyGraph.Edge],
    ) {
        // Modrinth dependency edges point from the dependent mod to the required
        // project. The board shows the inverse: required project -> dependent mod.
        // Remove transitive shortcuts before placing nodes so only the shortest
        // dependency paths are drawn.
        let invertedEdges = graphEdges.map {
            ModDependencyGraph.Edge(from: $0.to, to: $0.from)
        }
        let displayEdges = Self.transitiveReduction(invertedEdges)
        let parentsById = Self.parentsById(displayEdges)
        let childrenById = Self.childrenById(displayEdges)
        let layoutDepths = Self.layoutDepths(
            nodes: graphNodes,
            parentsById: parentsById,
            childrenById: childrenById,
        )
        let modLayerCount = layoutDepths.values.reduce(0) { max($0, $1) } + 1
        let isolatedNodes = graphNodes
            .filter { parentsById[$0.id] == nil && childrenById[$0.id] == nil }
            .sorted { Self.titleOrder($0, $1) }
        let isolatedIDs = Set(isolatedNodes.map(\.id))

        var layers = Array(repeating: [ModDependencyGraph.Node](), count: modLayerCount)
        for node in graphNodes where !isolatedIDs.contains(node.id) {
            let depth = layoutDepths[node.id]!
            layers[depth].append(node)
        }
        Self.orderLayers(
            &layers,
            parentsById: parentsById,
            childrenById: childrenById,
        )

        let activeLayers = layers
        let rawY = Self.verticalPositions(
            layers: activeLayers,
            parentsById: parentsById,
            childrenById: childrenById,
        )
        let isolatedY = Self.verticalPositions(
            layers: [isolatedNodes],
            parentsById: parentsById,
            childrenById: childrenById,
        )

        let gameX = isolatedNodes.isEmpty
            ? 0
            : Self.contentPadding + Self.nodeSize.width + Self.layerSpacing
        let modStartX = gameX + Self.gameCardSize.width + Self.layerSpacing
        var layoutNodes: [Node] = []

        for (layerIndex, layer) in activeLayers.enumerated() {
            let baseX = modStartX + CGFloat(layerIndex) * (Self.nodeSize.width + Self.layerSpacing)

            for node in layer {
                let frame = CGRect(
                    origin: CGPoint(
                        x: baseX + Self.jitter(
                            for: node.id,
                            salt: 0x9E37_79B9_7F4A_7C15,
                            range: -42 ... 42,
                        ),
                        y: rawY[node.id]! + Self.jitter(
                            for: node.id,
                            salt: 0xC2B2_AE3D_27D4_EB4F,
                            range: -11 ... 11,
                        ),
                    ),
                    size: Self.nodeSize,
                )
                layoutNodes.append(Node(
                    mod: node,
                    frame: frame,
                ))
            }
        }

        for node in isolatedNodes {
            let frame = CGRect(
                x: Self.contentPadding + Self.jitter(
                    for: node.id,
                    salt: 0x9E37_79B9_7F4A_7C15,
                    range: -11 ... 11,
                ),
                y: isolatedY[node.id]! + Self.jitter(
                    for: node.id,
                    salt: 0xC2B2_AE3D_27D4_EB4F,
                    range: -11 ... 11,
                ),
                width: Self.nodeSize.width,
                height: Self.nodeSize.height,
            )
            layoutNodes.append(Node(mod: node, frame: frame))
        }

        // Every acyclic component connects its parentless nodes to the game
        // root. Components made entirely of dependency cycles have no parentless
        // node, so they contribute one deterministic entry point instead.
        let rootTargetNodes = Self.rootTargetNodes(
            nodes: graphNodes,
            edges: displayEdges,
            parentsById: parentsById,
            layoutDepths: layoutDepths,
        )
        let rootTargetIDs = Set(rootTargetNodes.map(\.id))
        let rootTargetCenters = layoutNodes
            .filter { rootTargetIDs.contains($0.id) }
            .map(\.frame.midY)
        let rootCenterY = rootTargetCenters.isEmpty
            ? 0
            : rootTargetCenters.reduce(0, +) / CGFloat(rootTargetCenters.count)
        let rootFrame = CGRect(
            x: gameX,
            y: rootCenterY - Self.gameCardSize.height / 2,
            width: Self.gameCardSize.width,
            height: Self.gameCardSize.height,
        )

        let bounds = layoutNodes.reduce(rootFrame) { currentBounds, node in
            currentBounds.union(node.frame)
        }
        let minX = bounds.minX
        let maxX = bounds.maxX
        let minY = bounds.minY
        let maxY = bounds.maxY
        let contentWidth = max(maxX - minX + Self.contentPadding * 2, 320)
        let contentHeight = max(maxY - minY + Self.contentPadding * 2, 320)
        let extraX = contentWidth - (maxX - minX) - Self.contentPadding * 2
        let extraY = contentHeight - (maxY - minY) - Self.contentPadding * 2
        let shift = CGPoint(
            x: Self.contentPadding - minX + extraX / 2,
            y: Self.contentPadding - minY + extraY / 2,
        )

        layoutNodes = layoutNodes.map { node in
            Node(
                mod: node.mod,
                frame: node.frame.offsetBy(dx: shift.x, dy: shift.y),
            )
        }
        layoutNodes.sort {
            $0.frame.minX == $1.frame.minX
                ? $0.frame.minY < $1.frame.minY
                : $0.frame.minX < $1.frame.minX
        }

        let shiftedRootFrame = rootFrame.offsetBy(dx: shift.x, dy: shift.y)

        var allEdges = displayEdges
        allEdges.append(contentsOf: rootTargetNodes.map {
            ModDependencyGraph.Edge(from: Self.gameNodeID, to: $0.id)
        })
        edges = allEdges

        self.rootFrame = shiftedRootFrame
        nodes = layoutNodes
        size = CGSize(width: contentWidth, height: contentHeight)

        var frames: [String: CGRect] = [Self.gameNodeID: shiftedRootFrame]
        for node in layoutNodes {
            frames[node.id] = node.frame
        }
        framesByNodeID = frames
    }

}
