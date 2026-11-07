//
//  ModDependencyGraphTestSupport.swift
//  ModDependencyGraphKitTests
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import ModDependencyGraphKit
import XCTest

class ModDependencyGraphTestCase: XCTestCase {
    let builder = ModDependencyGraphBuilder()

    func makeInput(
        localMods: [ModDependencyGraphItem],
        externalProjects: [String: ModDependencyGraphProject] = [:],
    ) -> ModDependencyGraphBuilder.Input {
        ModDependencyGraphBuilder.Input(
            localMods: localMods,
            missingProjectIds: ModDependencyGraphBuilder
                .missingDependencyProjectIds(in: localMods)
                .sorted(),
            externalProjects: externalProjects,
        )
    }

    func makeLayout(_ graph: ModDependencyGraph) -> ModDependencyGraphLayout {
        ModDependencyGraphLayout(nodes: graph.nodes, edges: graph.edges)
    }

    static let modsDirectory = URL(fileURLWithPath: "/tmp/mods")

    static func makeDetail(id: String, title: String) -> ModDependencyGraphProject {
        ModDependencyGraphProject(
            projectId: id,
            title: title,
            iconUrl: nil,
        )
    }

    static func makeVersion(
        projectId _: String,
        versionId _: String,
        sha1: String,
        dependencies: [ModDependencyGraphVersion.Dependency] = [],
        primary: Bool = true,
    ) -> ModDependencyGraphVersion {
        ModDependencyGraphVersion(
            dependencies: dependencies,
            files: [
                ModDependencyGraphVersion.File(
                    sha1: sha1,
                    isPrimary: primary,
                ),
            ],
        )
    }

    static func makeLocalMod(
        project: ModDependencyGraphProject,
        version: ModDependencyGraphVersion?,
        fileName: String? = nil,
        isEnabled: Bool = true,
    ) -> ModDependencyGraphItem {
        ModDependencyGraphItem(
            project: project,
            installedVersion: version,
            fileName: fileName ?? "\(project.projectId).jar",
            isEnabled: isEnabled,
        )
    }

    static func dependency(
        _ projectId: String,
        type: String,
    ) -> ModDependencyGraphVersion.Dependency {
        ModDependencyGraphVersion.Dependency(projectId: projectId, type: type)
    }
}
