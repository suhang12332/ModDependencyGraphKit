//
//  ModDependencyGraphServiceTests.swift
//  ModDependencyGraphKitTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import ModDependencyGraphKit
import XCTest

final class ModDependencyGraphServiceTests: ModDependencyGraphTestCase {
    // MARK: - Service

    func testServiceScansAndFetchesMissingDependencies() async throws {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let projectB = Self.makeDetail(id: "project-b", title: "Remote Library")

        let scanner = ModDependencyGraphScanner(
            fileLister: { _ in [URL(fileURLWithPath: "/tmp/mods/a.jar")] },
            detailProvider: { _ in (projectA, "hash-a") },
            versionsProvider: { _ in
                [
                    Self.makeVersion(
                        projectId: projectA.id,
                        versionId: "a-1",
                        sha1: "hash-a",
                        dependencies: [Self.dependency(projectB.id, type: "required")],
                    ),
                ]
            },
            maxConcurrentTasks: 2,
        )
        let service = ModDependencyGraphService(scanner: scanner, externalProjectProvider: { projectId in
            projectId == projectB.id ? projectB : nil
        })

        let graph = try await service.buildGraph(modsDirectory: Self.modsDirectory)
        let nodeA = graph.nodes.first { $0.projectId == projectA.id }
        let nodeB = graph.nodes.first { $0.projectId == projectB.id }

        XCTAssertEqual(graph.nodes.count, 2)
        XCTAssertEqual(graph.edges.count, 1)
        XCTAssertEqual(nodeA?.fileName, "a.jar")
        XCTAssertEqual(nodeB?.isInstalled, false)
    }
}
