//
//  ModDependencyGraphLayout+Utilities.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import CoreGraphics
import Foundation

extension ModDependencyGraphLayout {
    static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    static func jitter(
        for id: String,
        salt: UInt64,
        range: ClosedRange<CGFloat>,
    ) -> CGFloat {
        let hash = stableHash(id) ^ salt
        let unit = CGFloat(hash % 1000) / 1000
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }

    static func parentsById(
        _ edges: [ModDependencyGraph.Edge],
    ) -> [String: [String]] {
        var parentsById: [String: [String]] = [:]
        for edge in edges {
            parentsById[edge.to, default: []].append(edge.from)
        }
        return parentsById
    }

    static func childrenById(
        _ edges: [ModDependencyGraph.Edge],
    ) -> [String: [String]] {
        var childrenById: [String: [String]] = [:]
        for edge in edges {
            childrenById[edge.from, default: []].append(edge.to)
        }
        return childrenById
    }

    static func titleOrder(
        _ lhs: ModDependencyGraph.Node,
        _ rhs: ModDependencyGraph.Node,
    ) -> Bool {
        let comparison = lhs.title.localizedStandardCompare(rhs.title)
        if comparison != .orderedSame {
            return comparison == .orderedAscending
        }
        return lhs.id < rhs.id
    }

}
