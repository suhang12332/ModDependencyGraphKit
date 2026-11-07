//
//  ModDependencyGraphService.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Scans a local mods directory and builds its dependency graph in one step.
public struct ModDependencyGraphService: Sendable {
    public enum Error: Swift.Error, Sendable {
        case noMods
    }

    public typealias ExternalProjectProvider = @Sendable (String) async -> ModDependencyGraphProject?

    public let scanner: ModDependencyGraphScanner
    public let builder: ModDependencyGraphBuilder
    public let externalProjectProvider: ExternalProjectProvider

    public init(
        scanner: ModDependencyGraphScanner,
        builder: ModDependencyGraphBuilder = ModDependencyGraphBuilder(),
        externalProjectProvider: @escaping ExternalProjectProvider,
    ) {
        self.scanner = scanner
        self.builder = builder
        self.externalProjectProvider = externalProjectProvider
    }

    /// Scans every mod in `modsDirectory` and returns the dependency graph.
    public func buildGraph(modsDirectory: URL) async throws -> ModDependencyGraph {
        let localMods = try await scanner.scan(modsDirectory: modsDirectory)
        guard !localMods.isEmpty else {
            throw Error.noMods
        }

        let missingProjectIds = ModDependencyGraphBuilder.missingDependencyProjectIds(in: localMods)
        let externalProjects = await fetchExternalProjects(ids: missingProjectIds)

        return builder.build(
            ModDependencyGraphBuilder.Input(
                localMods: localMods,
                missingProjectIds: missingProjectIds.sorted(),
                externalProjects: externalProjects,
            ),
        )
    }

    private func fetchExternalProjects(
        ids: Set<String>,
    ) async -> [String: ModDependencyGraphProject] {
        guard !ids.isEmpty else {
            return [:]
        }

        let semaphore = GraphAsyncSemaphore(value: scanner.maxConcurrentTasks)

        return await withTaskGroup(of: (String, ModDependencyGraphProject?).self) { group in
            for projectId in ids {
                group.addTask {
                    await semaphore.wait()
                    let detail = await externalProjectProvider(projectId)
                    await semaphore.signal()
                    return (projectId, detail)
                }
            }

            var results: [String: ModDependencyGraphProject] = [:]
            results.reserveCapacity(ids.count)
            for await (projectId, detail) in group {
                if let detail {
                    results[projectId] = detail
                }
            }
            return results
        }
    }
}
