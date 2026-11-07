//
//  ModDependencyGraph.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Flattened dependency graph used by the drawing layer.
///
/// Each project appears exactly once. Edges point from a mod to its required
/// dependency.
public struct ModDependencyGraph: Sendable {
    public struct Node: Identifiable, Sendable {
        public let projectId: String
        public let title: String
        public let iconUrl: String?
        public let fileName: String?
        public let isEnabled: Bool
        public let isCycle: Bool

        public var id: String { projectId }
        public var isInstalled: Bool { fileName != nil }

        public init(
            projectId: String,
            title: String,
            iconUrl: String?,
            fileName: String?,
            isEnabled: Bool,
            isCycle: Bool,
        ) {
            self.projectId = projectId
            self.title = title
            self.iconUrl = iconUrl
            self.fileName = fileName
            self.isEnabled = isEnabled
            self.isCycle = isCycle
        }
    }

    public struct Edge: Sendable, Hashable {
        public let from: String
        public let to: String

        public init(from: String, to: String) {
            self.from = from
            self.to = to
        }
    }

    public let nodes: [Node]
    public let edges: [Edge]

    public init(nodes: [Node], edges: [Edge]) {
        self.nodes = nodes
        self.edges = edges
    }
}
