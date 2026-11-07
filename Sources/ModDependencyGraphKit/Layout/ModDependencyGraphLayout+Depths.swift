//
//  ModDependencyGraphLayout+Depths.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import CoreGraphics
import Foundation

extension ModDependencyGraphLayout {
    /// Longest-path layering keeps dependency edges pointing to the right. Back
    /// edges introduced by dependency cycles are skipped for layout purposes.
    ///
    /// A DFS postorder produces a topological order once back edges are ignored;
    /// relaxing that order in a single pass computes the longest path in O(V + E)
    /// without revisiting shared subtrees.
    static func layoutDepths(
        nodes: [ModDependencyGraph.Node],
        parentsById: [String: [String]],
        childrenById: [String: [String]],
    ) -> [String: Int] {
        let orderedNodes = nodes.sorted(by: titleOrder)

        var titleOrderIndex: [String: Int] = [:]
        titleOrderIndex.reserveCapacity(nodes.count)
        for (index, node) in orderedNodes.enumerated() {
            titleOrderIndex[node.id] = index
        }

        // Sort adjacency so cycle breaking does not depend on scan order.
        let orderedChildren = childrenById.mapValues { childIDs in
            childIDs.sorted {
                titleOrderIndex[$0]! < titleOrderIndex[$1]!
            }
        }

        var visited: Set<String> = []
        var postorder: [String] = []
        postorder.reserveCapacity(nodes.count)

        func visit(_ id: String) {
            guard visited.insert(id).inserted else {
                return
            }
            for child in orderedChildren[id] ?? [] {
                visit(child)
            }
            postorder.append(id)
        }

        for node in orderedNodes where parentsById[node.id] == nil {
            visit(node.id)
        }
        for node in orderedNodes {
            visit(node.id)
        }

        let topologicalOrder = Array(postorder.reversed())
        var topologicalIndex: [String: Int] = [:]
        topologicalIndex.reserveCapacity(topologicalOrder.count)
        for (index, id) in topologicalOrder.enumerated() {
            topologicalIndex[id] = index
        }

        var depths: [String: Int] = [:]
        depths.reserveCapacity(nodes.count)
        for node in nodes {
            depths[node.id] = 0
        }

        for id in topologicalOrder {
            let nextDepth = depths[id]! + 1
            for child in orderedChildren[id] ?? [] {
                // Back edges are the only edges pointing backwards in reverse
                // postorder; skipping them breaks dependency cycles.
                guard topologicalIndex[child]! > topologicalIndex[id]! else {
                    continue
                }
                if nextDepth > depths[child]! {
                    depths[child] = nextDepth
                }
            }
        }

        return depths
    }

}
