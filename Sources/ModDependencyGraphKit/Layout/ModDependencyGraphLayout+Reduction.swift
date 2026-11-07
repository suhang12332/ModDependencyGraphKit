//
//  ModDependencyGraphLayout+Reduction.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import CoreGraphics
import Foundation

extension ModDependencyGraphLayout {
    /// Drops edges that are already implied by a longer dependency path. For
    /// example, `C -> A` is removed when `C -> B -> A` exists, which keeps the
    /// board readable without losing reachability.
    ///
    /// Edges that belong to a cycle are always kept. Otherwise a cycle would
    /// act as the "alternate path" for its own edges and remove them, leaving
    /// genuinely required nodes disconnected.
    static func transitiveReduction(
        _ edges: [ModDependencyGraph.Edge],
    ) -> [ModDependencyGraph.Edge] {
        var adjacency: [String: [String]] = [:]
        for edge in edges {
            adjacency[edge.from, default: []].append(edge.to)
        }

        let cycleEdgeIndices = Set(edges.indices.filter { index in
            let edge = edges[index]
            return hasPath(from: edge.to, to: edge.from, adjacency: adjacency)
        })

        var acyclicAdjacency: [String: [String]] = [:]
        for (index, edge) in edges.enumerated() where !cycleEdgeIndices.contains(index) {
            acyclicAdjacency[edge.from, default: []].append(edge.to)
        }

        return edges.enumerated().compactMap { index, edge in
            guard !cycleEdgeIndices.contains(index) else {
                return edge
            }
            return hasPath(
                from: edge.from,
                to: edge.to,
                adjacency: acyclicAdjacency,
                ignoringDirectEdge: true,
            ) ? nil : edge
        }
    }

    static func hasPath(
        from source: String,
        to target: String,
        adjacency: [String: [String]],
        ignoringDirectEdge: Bool = false,
    ) -> Bool {
        var queue = [source]
        var visited: Set<String> = [source]
        var index = 0

        while index < queue.count {
            let node = queue[index]
            index += 1

            for next in adjacency[node] ?? [] {
                if ignoringDirectEdge, node == source, next == target {
                    continue
                }
                if next == target {
                    return true
                }
                if visited.insert(next).inserted {
                    queue.append(next)
                }
            }
        }

        return false
    }

}
