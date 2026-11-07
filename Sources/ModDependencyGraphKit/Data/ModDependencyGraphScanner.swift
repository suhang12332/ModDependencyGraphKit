//
//  ModDependencyGraphScanner.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Scans a `mods` directory and resolves every file to a lightweight local
/// record. Required dependency IDs are extracted immediately, so the full
/// version payload does not stay alive during graph construction.
public struct ModDependencyGraphScanner: Sendable {
    public enum LogLevel: Sendable {
        case debug
        case error
    }

    public typealias LogHandler = @Sendable (LogLevel, String) -> Void
    public typealias FileLister = @Sendable (URL) async throws -> [URL]
    public typealias DetailProvider = @Sendable (URL) async throws
        -> (project: ModDependencyGraphProject, hash: String)?
    public typealias VersionsProvider = @Sendable (String) async throws -> [ModDependencyGraphVersion]

    public let fileLister: FileLister
    public let detailProvider: DetailProvider
    public let versionsProvider: VersionsProvider
    public let maxConcurrentTasks: Int

    private let logger: LogHandler

    public init(
        fileLister: @escaping FileLister,
        detailProvider: @escaping DetailProvider,
        versionsProvider: @escaping VersionsProvider,
        maxConcurrentTasks: Int,
        logger: @escaping LogHandler = { _, _ in },
    ) {
        self.fileLister = fileLister
        self.detailProvider = detailProvider
        self.versionsProvider = versionsProvider
        self.maxConcurrentTasks = min(8, max(1, maxConcurrentTasks))
        self.logger = logger
    }

    /// Scans all mod files in `modsDirectory` and returns their resolved local
    /// records.
    public func scan(modsDirectory: URL) async throws -> [ModDependencyGraphItem] {
        let files = try await fileLister(modsDirectory)

        let semaphore = GraphAsyncSemaphore(value: maxConcurrentTasks)

        return await withTaskGroup(of: ModDependencyGraphItem?.self) { group in
            for file in files {
                group.addTask {
                    await semaphore.wait()
                    let mod = await scanFile(file)
                    await semaphore.signal()
                    return mod
                }
            }

            var results: [ModDependencyGraphItem] = []
            results.reserveCapacity(files.count)
            for await mod in group {
                if let mod {
                    results.append(mod)
                }
            }
            return results
        }
    }

    private func scanFile(_ fileURL: URL) async -> ModDependencyGraphItem? {
        let project: ModDependencyGraphProject
        let hash: String
        do {
            guard let resolved = try await detailProvider(fileURL) else {
                logger(.debug, "Skipping mod file without resolved detail: \(fileURL.lastPathComponent)")
                return nil
            }
            project = resolved.project
            hash = resolved.hash
        } catch {
            logger(
                .error,
                "Failed to resolve mod detail for \(fileURL.lastPathComponent): \(error.localizedDescription)",
            )
            return nil
        }

        var installedVersion: ModDependencyGraphVersion?

        // Fallback details use a synthetic file-based project ID and have no
        // remote version to query.
        if !project.isLocalFallback {
            do {
                let versions = try await versionsProvider(project.projectId)
                installedVersion = ModDependencyGraphBuilder.installedVersion(
                    matching: hash,
                    in: versions,
                )
            } catch {
                logger(
                    .debug,
                    "Failed to resolve installed version for \(project.projectId): \(error.localizedDescription)",
                )
            }
        }

        return ModDependencyGraphItem(
            project: project,
            installedVersion: installedVersion,
            fileName: fileURL.lastPathComponent,
            isEnabled: !fileURL.lastPathComponent.lowercased().hasSuffix(".disable"),
        )
    }
}
