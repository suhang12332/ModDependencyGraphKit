//
//  ModDependencyGraphLayoutTests.swift
//  ModDependencyGraphKitTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import ModDependencyGraphKit
import XCTest

final class ModDependencyGraphLayoutTests: ModDependencyGraphTestCase {
    // MARK: - Layout

    func testLayout_connectsRequiredProjectToItsDependent() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let projectB = Self.makeDetail(id: "project-b", title: "B Library")
        let projectC = Self.makeDetail(id: "project-c", title: "C Core")

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
                dependencies: [Self.dependency(projectC.id, type: "required")],
            ),
        )
        let modC = Self.makeLocalMod(
            project: projectC,
            version: Self.makeVersion(projectId: projectC.id, versionId: "c-1", sha1: "hash-c"),
        )

        let graph = builder.build(makeInput(localMods: [modA, modB, modC]))
        let layout = makeLayout(graph)
        let rootTargets = Set(layout.edges
            .filter { $0.from == ModDependencyGraphLayout.gameNodeID }
            .map(\.to))

        XCTAssertEqual(rootTargets, [projectC.id])
        XCTAssertTrue(layout.edges.contains {
            $0.from == projectC.id
                && $0.to == projectB.id
        })
        XCTAssertTrue(layout.edges.contains {
            $0.from == projectB.id
                && $0.to == projectA.id
        })
        XCTAssertEqual(layout.edges.count, 3)
    }

    func testLayout_removesTransitiveDependencyEdges() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let projectB = Self.makeDetail(id: "project-b", title: "B Library")
        let projectC = Self.makeDetail(id: "project-c", title: "C Core")

        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(
                projectId: projectA.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [
                    Self.dependency(projectB.id, type: "required"),
                    Self.dependency(projectC.id, type: "required"),
                ],
            ),
        )
        let modB = Self.makeLocalMod(
            project: projectB,
            version: Self.makeVersion(
                projectId: projectB.id,
                versionId: "b-1",
                sha1: "hash-b",
                dependencies: [Self.dependency(projectC.id, type: "required")],
            ),
        )
        let modC = Self.makeLocalMod(
            project: projectC,
            version: Self.makeVersion(projectId: projectC.id, versionId: "c-1", sha1: "hash-c"),
        )

        let graph = builder.build(makeInput(localMods: [modA, modB, modC]))
        let layout = makeLayout(graph)
        let rootTargets = Set(layout.edges
            .filter { $0.from == ModDependencyGraphLayout.gameNodeID }
            .map(\.to))
        let cID = projectC.id
        let bID = projectB.id
        let aID = projectA.id

        XCTAssertEqual(rootTargets, [cID])
        XCTAssertFalse(layout.edges.contains { $0.from == cID && $0.to == aID })
        XCTAssertTrue(layout.edges.contains { $0.from == cID && $0.to == bID })
        XCTAssertTrue(layout.edges.contains { $0.from == bID && $0.to == aID })
    }

    func testLayout_sharedDependencyFansOutToDependents() {
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
        let layout = makeLayout(graph)
        let rootTargets = Set(layout.edges
            .filter { $0.from == ModDependencyGraphLayout.gameNodeID }
            .map(\.to))

        XCTAssertEqual(rootTargets, [shared.id])
        XCTAssertTrue(layout.edges.contains {
            $0.from == shared.id
                && $0.to == projectA.id
        })
        XCTAssertTrue(layout.edges.contains {
            $0.from == shared.id
                && $0.to == projectB.id
        })
    }

    func testLayout_pureCycleStillConnectsGameRoot() {
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
        let layout = makeLayout(graph)
        let rootTargets = layout.edges
            .filter { $0.from == ModDependencyGraphLayout.gameNodeID }
            .map(\.to)

        XCTAssertEqual(rootTargets.count, 1)
        XCTAssertTrue([projectA.id, projectB.id].contains(rootTargets[0]))
    }

    func testLayout_keepsDependencyEdgesWhenCycleHasShortcut() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let projectB = Self.makeDetail(id: "project-b", title: "B Mod")
        let projectC = Self.makeDetail(id: "project-c", title: "C Library")

        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(
                projectId: projectA.id,
                versionId: "a-1",
                sha1: "hash-a",
                dependencies: [
                    Self.dependency(projectB.id, type: "required"),
                    Self.dependency(projectC.id, type: "required"),
                ],
            ),
        )
        let modB = Self.makeLocalMod(
            project: projectB,
            version: Self.makeVersion(
                projectId: projectB.id,
                versionId: "b-1",
                sha1: "hash-b",
                dependencies: [
                    Self.dependency(projectA.id, type: "required"),
                    Self.dependency(projectC.id, type: "required"),
                ],
            ),
        )
        let modC = Self.makeLocalMod(
            project: projectC,
            version: Self.makeVersion(projectId: projectC.id, versionId: "c-1", sha1: "hash-c"),
        )

        let graph = builder.build(makeInput(localMods: [modA, modB, modC]))
        let layout = makeLayout(graph)

        XCTAssertTrue(layout.edges.contains { $0.from == projectC.id && $0.to == projectA.id })
        XCTAssertTrue(layout.edges.contains { $0.from == projectC.id && $0.to == projectB.id })
        XCTAssertTrue(layout.edges.contains { $0.from == projectB.id && $0.to == projectA.id })
        XCTAssertTrue(layout.edges.contains { $0.from == projectA.id && $0.to == projectB.id })
    }

    func testLayout_connectsEveryCycleOnlyComponentToGameRoot() {
        let projectA = Self.makeDetail(id: "project-a", title: "A Mod")
        let projectB = Self.makeDetail(id: "project-b", title: "B Mod")
        let projectC = Self.makeDetail(id: "project-c", title: "C Mod")
        let projectD = Self.makeDetail(id: "project-d", title: "D Mod")
        let projectE = Self.makeDetail(id: "project-e", title: "E Mod")

        let modA = Self.makeLocalMod(
            project: projectA,
            version: Self.makeVersion(projectId: projectA.id, versionId: "a-1", sha1: "hash-a"),
        )
        let modB = Self.makeLocalMod(
            project: projectB,
            version: Self.makeVersion(
                projectId: projectB.id,
                versionId: "b-1",
                sha1: "hash-b",
                dependencies: [Self.dependency(projectC.id, type: "required")],
            ),
        )
        let modC = Self.makeLocalMod(
            project: projectC,
            version: Self.makeVersion(
                projectId: projectC.id,
                versionId: "c-1",
                sha1: "hash-c",
                dependencies: [Self.dependency(projectB.id, type: "required")],
            ),
        )
        let modD = Self.makeLocalMod(
            project: projectD,
            version: Self.makeVersion(
                projectId: projectD.id,
                versionId: "d-1",
                sha1: "hash-d",
                dependencies: [Self.dependency(projectE.id, type: "required")],
            ),
        )
        let modE = Self.makeLocalMod(
            project: projectE,
            version: Self.makeVersion(
                projectId: projectE.id,
                versionId: "e-1",
                sha1: "hash-e",
                dependencies: [Self.dependency(projectD.id, type: "required")],
            ),
        )

        let graph = builder.build(makeInput(localMods: [modA, modB, modC, modD, modE]))
        let layout = makeLayout(graph)
        let rootTargets = Set(layout.edges
            .filter { $0.from == ModDependencyGraphLayout.gameNodeID }
            .map(\.to))

        XCTAssertEqual(rootTargets.count, 3)
        XCTAssertTrue(rootTargets.contains(projectA.id))
        XCTAssertEqual(rootTargets.intersection([projectB.id, projectC.id]).count, 1)
        XCTAssertEqual(rootTargets.intersection([projectD.id, projectE.id]).count, 1)
    }
}
