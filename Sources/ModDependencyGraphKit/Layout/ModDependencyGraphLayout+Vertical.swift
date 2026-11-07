//
//  ModDependencyGraphLayout+Vertical.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import CoreGraphics
import Foundation

extension ModDependencyGraphLayout {
    /// Relaxes the vertical coordinates so every node sits near the average of its
    /// parents and children. The PAVA projection keeps nodes in order while
    /// enforcing a minimum gap, which avoids overlaps without creating the large
    /// empty gaps of a purely greedy placement.
    static func verticalPositions(
        layers: [[ModDependencyGraph.Node]],
        parentsById: [String: [String]],
        childrenById: [String: [String]],
    ) -> [String: CGFloat] {
        let spacing = nodeSize.height + verticalSpacing
        var positions: [String: CGFloat] = [:]

        for layer in layers {
            let start = -CGFloat(layer.count - 1) * spacing / 2
            for (index, node) in layer.enumerated() {
                positions[node.id] = start + CGFloat(index) * spacing
            }
        }

        for _ in 0 ..< 24 {
            var next = positions

            for layer in layers {
                let desired = layer.map { node -> CGFloat in
                    let current = positions[node.id]!
                    let neighborIDs = (parentsById[node.id] ?? []) + (childrenById[node.id] ?? [])
                    let neighborYs = neighborIDs.map { positions[$0]! }
                    guard !neighborYs.isEmpty else {
                        return current
                    }
                    let average = neighborYs.reduce(0, +) / CGFloat(neighborYs.count)
                    return current * 0.35 + average * 0.65
                }

                let projected = project(desired, spacing: spacing)
                for (index, node) in layer.enumerated() {
                    next[node.id] = projected[index]
                }
            }

            positions = next
        }

        return positions
    }

    /// Projection onto the set of ordered values separated by `spacing`.
    static func project(
        _ desired: [CGFloat],
        spacing: CGFloat,
    ) -> [CGFloat] {
        var values: [CGFloat] = []
        var counts: [Int] = []

        for (index, value) in desired.enumerated() {
            values.append(value - CGFloat(index) * spacing)
            counts.append(1)

            while values.count > 1, values[values.count - 2] > values[values.count - 1] {
                let lastValue = values.removeLast()
                let lastCount = counts.removeLast()
                let previousValue = values.removeLast()
                let previousCount = counts.removeLast()
                let count = lastCount + previousCount
                values.append((lastValue * CGFloat(lastCount) + previousValue * CGFloat(previousCount)) / CGFloat(count))
                counts.append(count)
            }
        }

        var projected: [CGFloat] = []
        for (value, count) in zip(values, counts) {
            projected.append(contentsOf: repeatElement(value, count: count))
        }

        return projected.enumerated().map { index, value in
            value + CGFloat(index) * spacing
        }
    }

}
