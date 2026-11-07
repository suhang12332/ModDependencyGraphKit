//
//  ModDependencyGraphScannerTests.swift
//  ModDependencyGraphKitTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import ModDependencyGraphKit
import XCTest

final class ModDependencyGraphScannerTests: ModDependencyGraphTestCase {
    // MARK: - Scanner

    func testScannerResolvesVersionAndEnabledState() async throws {
        let fileEnabled = URL(fileURLWithPath: "/tmp/mods/alpha.jar")
        let fileDisabled = URL(fileURLWithPath: "/tmp/mods/beta.jar.disable")

        let scanner = ModDependencyGraphScanner(
            fileLister: { _ in [fileEnabled, fileDisabled] },
            detailProvider: { url in
                let id = url.lastPathComponent.hasPrefix("alpha") ? "project-alpha" : "project-beta"
                let hash = url.lastPathComponent.hasPrefix("alpha") ? "hash-alpha" : "hash-beta"
                return (Self.makeDetail(id: id, title: id), hash)
            },
            versionsProvider: { projectId in
                let hash = projectId == "project-alpha" ? "hash-alpha" : "hash-beta"
                return [Self.makeVersion(projectId: projectId, versionId: "\(projectId)-1", sha1: hash)]
            },
            maxConcurrentTasks: 2,
        )

        let mods = try await scanner.scan(modsDirectory: Self.modsDirectory)
        let byName = Dictionary(uniqueKeysWithValues: mods.map { ($0.fileName, $0) })

        XCTAssertEqual(byName["alpha.jar"]?.projectId, "project-alpha")
        XCTAssertEqual(byName["alpha.jar"]?.isEnabled, true)
        XCTAssertEqual(byName["beta.jar.disable"]?.projectId, "project-beta")
        XCTAssertEqual(byName["beta.jar.disable"]?.isEnabled, false)
    }
}
