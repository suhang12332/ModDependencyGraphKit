//
//  ModDependencyGraphLayout+Roots.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import CoreGraphics
import Foundation

extension ModDependencyGraphLayout {
    /// Nodes that connect directly to the game root.
    ///
    /// Acyclic components contribute every parentless node. Cycle-only
    /// components contribute one representative so they are never left
    /// disconnected from the game card.
    static func rootTargetNodes(
        nodes: [ModDependencyGraph.Node],
        edges: [ModDependencyGraph.Edge],
        parentsById: [String: [String]],
        layoutDepths: [String: Int],
    ) -> [ModDependencyGraph.Node] {
        var targets = nodes.filter { parentsById[$0.id] == nil }
        targets.append(contentsOf: cycleOnlyComponentRepresentatives(
            nodes: nodes,
            edges: edges,
            parentsById: parentsById,
            layoutDepths: layoutDepths,
        ))
        targets.sort(by: titleOrder)
        return targets
    }

    static func cycleOnlyComponentRepresentatives(
        nodes: [ModDependencyGraph.Node],
        edges: [ModDependencyGraph.Edge],
        parentsById: [String: [String]],
        layoutDepths: [String: Int],
    ) -> [ModDependencyGraph.Node] {
        var adjacency: [String: [String]] = [:]
        for edge in edges {
            adjacency[edge.from, default: []].append(edge.to)
            adjacency[edge.to, default: []].append(edge.from)
        }

        let nodeByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        var visited: Set<String> = []
        var representatives: [ModDependencyGraph.Node] = []

        for node in nodes {
            guard visited.insert(node.id).inserted else { continue }

            var component: [String] = []
            var queue = [node.id]
            var index = 0
            while index < queue.count {
                let id = queue[index]
                index += 1
                component.append(id)
                for next in adjacency[id] ?? [] where visited.insert(next).inserted {
                    queue.append(next)
                }
            }

            guard !component.contains(where: { parentsById[$0] == nil }) else {
                continue
            }

            let componentNodes = component.map { nodeByID[$0]! }
            let representative = componentNodes.min(by: { lhs, rhs in
                let lhsDepth = layoutDepths[lhs.id]!
                let rhsDepth = layoutDepths[rhs.id]!
                if lhsDepth != rhsDepth {
                    return lhsDepth < rhsDepth
                }
                return titleOrder(lhs, rhs)
            })
            if let representative {
                representatives.append(representative)
            }
        }

        return representatives
    }

}
