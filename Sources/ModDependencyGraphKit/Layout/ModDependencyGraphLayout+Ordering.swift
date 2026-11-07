//
//  ModDependencyGraphLayout+Ordering.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import CoreGraphics
import Foundation

extension ModDependencyGraphLayout {
    /// Alternating downward/upward barycenter sweeps reduce edge crossings while
    /// keeping each layer's nodes in a deterministic order.
    static func orderLayers(
        _ layers: inout [[ModDependencyGraph.Node]],
        parentsById: [String: [String]],
        childrenById: [String: [String]],
    ) {
        for layer in layers.indices {
            layers[layer].sort(by: titleOrder)
        }

        for _ in 0 ..< 2 {
            var ranks = rankByNodeID(layers)

            if layers.count > 1 {
                for layerIndex in 1 ..< layers.count {
                    layers[layerIndex].sort { lhs, rhs in
                        compareByNeighbors(
                            lhs,
                            rhs,
                            neighborIDs: parentsById,
                            ranks: ranks,
                        )
                    }
                    updateRanks(for: layers[layerIndex], in: &ranks)
                }
            }

            if layers.count > 1 {
                for layerIndex in stride(from: layers.count - 2, through: 0, by: -1) {
                    layers[layerIndex].sort { lhs, rhs in
                        compareByNeighbors(
                            lhs,
                            rhs,
                            neighborIDs: childrenById,
                            ranks: ranks,
                        )
                    }
                    updateRanks(for: layers[layerIndex], in: &ranks)
                }
            }
        }
    }

    static func rankByNodeID(
        _ layers: [[ModDependencyGraph.Node]],
    ) -> [String: Double] {
        var ranks: [String: Double] = [:]
        for layer in layers {
            updateRanks(for: layer, in: &ranks)
        }
        return ranks
    }

    static func updateRanks(
        for layer: [ModDependencyGraph.Node],
        in ranks: inout [String: Double],
    ) {
        for (index, node) in layer.enumerated() {
            ranks[node.id] = Double(index)
        }
    }

    static func compareByNeighbors(
        _ lhs: ModDependencyGraph.Node,
        _ rhs: ModDependencyGraph.Node,
        neighborIDs: [String: [String]],
        ranks: [String: Double],
    ) -> Bool {
        let lhsRank = barycenter(for: lhs.id, neighborIDs: neighborIDs, ranks: ranks)
        let rhsRank = barycenter(for: rhs.id, neighborIDs: neighborIDs, ranks: ranks)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        return titleOrder(lhs, rhs)
    }

    static func barycenter(
        for id: String,
        neighborIDs: [String: [String]],
        ranks: [String: Double],
    ) -> Double {
        let neighborRanks = (neighborIDs[id] ?? []).compactMap { ranks[$0] }
        guard !neighborRanks.isEmpty else {
            return .greatestFiniteMagnitude
        }
        return neighborRanks.reduce(0, +) / Double(neighborRanks.count)
    }

}
