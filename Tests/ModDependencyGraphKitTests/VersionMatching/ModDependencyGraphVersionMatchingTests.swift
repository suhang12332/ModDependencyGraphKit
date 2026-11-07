//
//  ModDependencyGraphVersionMatchingTests.swift
//  ModDependencyGraphKitTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import ModDependencyGraphKit
import XCTest

final class ModDependencyGraphVersionMatchingTests: ModDependencyGraphTestCase {
    // MARK: - Version matching

    func testInstalledVersionMatchingPrefersPrimaryFile() {
        let primary = Self.makeVersion(projectId: "project-a", versionId: "primary", sha1: "HASH-A")
        let secondary = Self.makeVersion(
            projectId: "project-a",
            versionId: "secondary",
            sha1: "hash-a",
            primary: false,
        )

        let match = ModDependencyGraphBuilder.installedVersion(
            matching: "hash-a",
            in: [secondary, primary],
        )

        XCTAssertEqual(match, primary)
    }

    func testInstalledVersionMatchingFallsBackToAnyFile() {
        let version = Self.makeVersion(
            projectId: "project-a",
            versionId: "a-1",
            sha1: "hash-a",
            primary: false,
        )

        let match = ModDependencyGraphBuilder.installedVersion(matching: "HASH-A", in: [version])

        XCTAssertEqual(match, version)
    }
}
