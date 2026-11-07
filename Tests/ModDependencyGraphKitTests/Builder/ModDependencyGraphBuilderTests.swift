//
//  ModDependencyGraphBuilderTests.swift
//  ModDependencyGraphKitTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import ModDependencyGraphKit
import XCTest

final class ModDependencyGraphBuilderTests: ModDependencyGraphTestCase {
    // MARK: - Graph shape

    func testBuild_withNoModsReturnsEmptyGraph() {
        let graph = builder.build(makeInput(localMods: []))

        XCTAssertTrue(graph.nodes.isEmpty)
        XCTAssertTrue(graph.edges.isEmpty)
    }

    func testBuild_buildsEdgeForRequiredLocalDependency() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let projectB = Self.makeDetail(id: "project-b", title: "B Library")

        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(
                projectId: projectA.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [
                    Self.dependency(projectB.id, type: "required"),
                    Self.dependency("project-optional", type: "optional"),
                    Self.dependency("project-embedded", type: "embedded"),
                ],
            ),
        )
        let modB = Self.makeLocalMod(
            project: projectB,
            version: Self.makeVersion(projectId: projectB.id, versionId: "b-1", sha1: "hash-b"),
        )

        let graph = builder.build(makeInput(localMods: [modA, modB]))
        let aID = projectA.id
        let bID = projectB.id
        let nodeB = graph.nodes.first { $0.projectId == projectB.id }

        XCTAssertEqual(graph.nodes.count, 2)
        XCTAssertEqual(graph.edges.count, 1)
        XCTAssertEqual(graph.edges.first?.from, aID)
        XCTAssertEqual(graph.edges.first?.to, bID)
        XCTAssertEqual(nodeB?.fileName, "project-b.jar")
        XCTAssertEqual(nodeB?.isInstalled, true)
    }

    func testBuild_ignoresOptionalAndEmbeddedDependencies() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(
                projectId: projectA.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [
                    Self.dependency("project-optional", type: "optional"),
                    Self.dependency("project-embedded", type: "embedded"),
                    Self.dependency("project-incompatible", type: "incompatible"),
                ],
            ),
        )

        let graph = builder.build(makeInput(localMods: [modA]))

        XCTAssertEqual(graph.nodes.count, 1)
        XCTAssertTrue(graph.edges.isEmpty)
    }

    func testBuild_missingDependencyUsesExternalDetail() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let projectB = Self.makeDetail(id: "project-b", title: "Remote Library")
        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(
                projectId: projectA.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [Self.dependency(projectB.id, type: "required")],
            ),
        )

        let graph = builder.build(makeInput(
            localMods: [modA],
            externalProjects: [projectB.id: projectB],
        ))
        let nodeB = graph.nodes.first { $0.projectId == projectB.id }

        XCTAssertEqual(nodeB?.title, "Remote Library")
        XCTAssertEqual(nodeB?.isInstalled, false)
        XCTAssertNil(nodeB?.fileName)
    }

    func testBuild_missingDependencyWithoutDetailUsesPlaceholder() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(
                projectId: projectA.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [Self.dependency("project-missing", type: "required")],
            ),
        )

        let graph = builder.build(makeInput(localMods: [modA]))
        let node = graph.nodes.first { $0.projectId == "project-missing" }

        XCTAssertEqual(node?.title, "project-missing")
        XCTAssertEqual(node?.isInstalled, false)
    }

    func testBuild_sharedDependencyIsStoredOnce() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let projectB = Self.makeDetail(id: "project-b", title: "B Mod")
        let shared = Self.makeDetail(id: "project-shared", title: "Shared Library")

        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(
                projectId: projectA.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [Self.dependency(shared.id, type: "required")],
            ),
        )
        let modB = Self.makeLocalMod(
            project: projectB,
            version: Self.makeVersion(
                projectId: projectB.id,
                versionId: "b-1",
                sha1: "hash-b",
                dependencies: [Self.dependency(shared.id, type: "required")],
            ),
        )
        let sharedMod = Self.makeLocalMod(
            project: shared,
            version: Self.makeVersion(projectId: shared.id, versionId: "shared-1", sha1: "hash-shared"),
        )

        let graph = builder.build(makeInput(
            localMods: [modA, modB, sharedMod],
        ))
        let sharedID = shared.id

        XCTAssertEqual(graph.nodes.count, 3)
        XCTAssertEqual(graph.nodes.filter { $0.projectId == shared.id }.count, 1)
        XCTAssertEqual(graph.edges.count, 2)
        XCTAssertEqual(graph.edges.filter { $0.to == sharedID }.count, 2)
    }

    func testBuild_detectsDependencyCycle() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let projectB = Self.makeDetail(id: "project-b", title: "B Mod")

        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(
                projectId: projectA.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [Self.dependency(projectB.id, type: "required")],
            ),
        )
        let modB = Self.makeLocalMod(
            project: projectB,
            version: Self.makeVersion(
                projectId: projectB.id,
                versionId: "b-1",
                sha1: "hash-b",
                dependencies: [Self.dependency(projectA.id, type: "required")],
            ),
        )

        let graph = builder.build(makeInput(localMods: [modA, modB]))

        XCTAssertEqual(graph.nodes.count, 2)
        XCTAssertEqual(graph.edges.count, 2)
        XCTAssertTrue(graph.nodes.allSatisfy(\.isCycle))
    }

    func testBuild_prefersEnabledFileWhenProjectIsInstalledTwice() {
        let project = Self.makeDetail(id: "project-a", title: "A Mod")
        let enabled = Self.makeLocalMod(
            project: project,
            version: Self.makeVersion(projectId: project.id, versionId: "a-1", sha1: "hash-a"),
            fileName: "a.jar",
            isEnabled: true,
        )
        let disabled = Self.makeLocalMod(
            project: project,
            version: Self.makeVersion(projectId: project.id, versionId: "a-1", sha1: "hash-a"),
            fileName: "a.jar.disable",
            isEnabled: false,
        )

        let graph = builder.build(makeInput(localMods: [disabled, enabled]))

        XCTAssertEqual(graph.nodes.count, 1)
        XCTAssertEqual(graph.nodes.first?.fileName, "a.jar")
        XCTAssertEqual(graph.nodes.first?.isEnabled, true)
    }

    func testBuild_duplicateEnabledFilesUseStableOrder() {
        let project = Self.makeDetail(id: "project-a", title: "A Mod")
        let fileB = Self.makeLocalMod(
            project: project,
            version: Self.makeVersion(
                projectId: project.id,
                versionId: "a-2",
                sha1: "hash-b",
                dependencies: [Self.dependency("project-b", type: "required")],
            ),
            fileName: "b.jar",
            isEnabled: true,
        )
        let fileA = Self.makeLocalMod(
            project: project,
            version: Self.makeVersion(
                projectId: project.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [Self.dependency("project-a-dep", type: "required")],
            ),
            fileName: "a.jar",
            isEnabled: true,
        )

        let firstGraph = builder.build(makeInput(localMods: [fileB, fileA]))
        let secondGraph = builder.build(makeInput(localMods: [fileA, fileB]))
        let firstEdges = firstGraph.edges.map { "\($0.from)->\($0.to)" }
        let secondEdges = secondGraph.edges.map { "\($0.from)->\($0.to)" }

        XCTAssertEqual(firstGraph.nodes.first { $0.projectId == project.id }?.fileName, "a.jar")
        XCTAssertEqual(firstEdges, secondEdges)
        XCTAssertEqual(firstEdges, ["project-a->project-a-dep"])
    }

    func testBuild_carriesDisabledState() {
        let project = Self.makeDetail(id: "project-a", title: "A Mod")
        let mod = Self.makeLocalMod(
            project: project,
            version: Self.makeVersion(projectId: project.id, versionId: "a-1", sha1: "hash-a"),
            fileName: "a.jar.disable",
            isEnabled: false,
        )

        let graph = builder.build(makeInput(localMods: [mod]))

        XCTAssertEqual(graph.nodes.first?.isEnabled, false)
    }
}
