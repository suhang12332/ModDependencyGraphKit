//
//  ModDependencyGraphBuilder.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Builds the flattened dependency graph directly from scanned local mods.
///
/// Shared dependencies are stored once, so the builder never expands repeated
/// subtrees or keeps an intermediate tree.
public struct ModDependencyGraphBuilder: Sendable {
    public struct Input {
        public let localMods: [ModDependencyGraphItem]
        public let missingProjectIds: [String]
        public let externalProjects: [String: ModDependencyGraphProject]

        public init(
            localMods: [ModDependencyGraphItem],
            missingProjectIds: [String],
            externalProjects: [String: ModDependencyGraphProject] = [:],
        ) {
            self.localMods = localMods
            self.missingProjectIds = missingProjectIds
            self.externalProjects = externalProjects
        }
    }

    public init() { }

    public func build(_ input: Input) -> ModDependencyGraph {
        let localMods = Self.normalizedLocalMods(input.localMods)

        var indexByProjectId: [String: Int] = [:]
        indexByProjectId.reserveCapacity(localMods.count)
        for (index, mod) in localMods.enumerated() {
            indexByProjectId[mod.projectId] = index
        }

        let cycleProjectIds = Self.cycleProjectIds(
            localMods: localMods,
            indexByProjectId: indexByProjectId,
        )

        var nodes: [ModDependencyGraph.Node] = []
        nodes.reserveCapacity(localMods.count + input.missingProjectIds.count)
        var edges: [ModDependencyGraph.Edge] = []
        edges.reserveCapacity(localMods.reduce(0) { $0 + $1.dependencyProjectIds.count })

        for mod in localMods {
            nodes.append(ModDependencyGraph.Node(
                projectId: mod.projectId,
                title: mod.title,
                iconUrl: mod.iconUrl,
                fileName: mod.fileName,
                isEnabled: mod.isEnabled,
                isCycle: cycleProjectIds.contains(mod.projectId),
            ))

            for childProjectId in mod.dependencyProjectIds {
                edges.append(ModDependencyGraph.Edge(
                    from: mod.projectId,
                    to: childProjectId,
                ))
            }
        }

        for projectId in input.missingProjectIds {
            let project = input.externalProjects[projectId]
            nodes.append(ModDependencyGraph.Node(
                projectId: projectId,
                title: project?.title ?? projectId,
                iconUrl: project?.iconUrl,
                fileName: nil,
                isEnabled: false,
                isCycle: false,
            ))
        }

        return ModDependencyGraph(
            nodes: nodes,
            edges: edges,
        )
    }

    /// Returns required dependency IDs that are not installed locally.
    public static func missingDependencyProjectIds(
        in mods: [ModDependencyGraphItem],
    ) -> Set<String> {
        let mods = normalizedLocalMods(mods)
        let localProjectIds = Set(mods.lazy.map(\.projectId))
        var missingProjectIds: Set<String> = []

        for mod in mods {
            for projectId in mod.dependencyProjectIds where !localProjectIds.contains(projectId) {
                missingProjectIds.insert(projectId)
            }
        }

        return missingProjectIds
    }

    /// Finds the version whose primary file matches `sha1`, falling back to any
    /// file in the version when the primary file does not match.
    public static func installedVersion(
        matching sha1: String,
        in versions: [ModDependencyGraphVersion],
    ) -> ModDependencyGraphVersion? {
        let hash = sha1.lowercased()

        func matches(_ file: ModDependencyGraphVersion.File) -> Bool {
            file.sha1.lowercased() == hash
        }

        if let primary = versions.first(where: { version in
            version.files.contains { $0.isPrimary && matches($0) }
        }) {
            return primary
        }

        return versions.first { $0.files.contains(where: matches) }
    }

    private static func normalizedLocalMods(
        _ mods: [ModDependencyGraphItem],
    ) -> [ModDependencyGraphItem] {
        var byProjectId: [String: ModDependencyGraphItem] = [:]
        byProjectId.reserveCapacity(mods.count)
        var order: [String] = []
        order.reserveCapacity(mods.count)

        for mod in mods {
            if let existing = byProjectId[mod.projectId] {
                if prefers(mod, over: existing) {
                    byProjectId[mod.projectId] = mod
                }
            } else {
                byProjectId[mod.projectId] = mod
                order.append(mod.projectId)
            }
        }

        return order.compactMap { byProjectId[$0] }
    }

    /// Prefers the enabled copy of a project, then a stable file-name order so
    /// duplicate files cannot make the graph depend on scan completion order.
    private static func prefers(
        _ candidate: ModDependencyGraphItem,
        over current: ModDependencyGraphItem,
    ) -> Bool {
        if candidate.isEnabled != current.isEnabled {
            return candidate.isEnabled
        }
        return candidate.fileName < current.fileName
    }

    private static func cycleProjectIds(
        localMods: [ModDependencyGraphItem],
        indexByProjectId: [String: Int],
    ) -> Set<String> {
        var visiting: Set<String> = []
        var visited: Set<String> = []
        var stack: [String] = []
        var cycleProjectIds: Set<String> = []

        func visit(_ projectId: String) {
            if visited.contains(projectId) {
                return
            }
            if visiting.contains(projectId) {
                if let start = stack.firstIndex(of: projectId) {
                    cycleProjectIds.formUnion(stack[start...])
                }
                return
            }

            visiting.insert(projectId)
            stack.append(projectId)
            if let index = indexByProjectId[projectId] {
                for childProjectId in localMods[index].dependencyProjectIds {
                    visit(childProjectId)
                }
            }
            stack.removeLast()
            visiting.remove(projectId)
            visited.insert(projectId)
        }

        for mod in localMods {
            visit(mod.projectId)
        }

        return cycleProjectIds
    }
}
