//
//  ModDependencyGraphItem.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Project metadata needed while building a dependency graph.
public struct ModDependencyGraphProject: Identifiable, Sendable, Equatable {
    public let projectId: String
    public let title: String
    public let iconUrl: String?
    /// Fallback projects created from a local file name have no remote version
    /// metadata to query.
    public let isLocalFallback: Bool

    public var id: String { projectId }

    public init(
        projectId: String,
        title: String,
        iconUrl: String?,
        isLocalFallback: Bool = false,
    ) {
        self.projectId = projectId
        self.title = title
        self.iconUrl = iconUrl
        self.isLocalFallback = isLocalFallback
    }
}

/// Version metadata needed to resolve a file and its required dependencies.
public struct ModDependencyGraphVersion: Sendable, Equatable {
    public struct Dependency: Sendable, Equatable {
        public let projectId: String?
        public let type: String

        public init(projectId: String?, type: String) {
            self.projectId = projectId
            self.type = type
        }
    }

    public struct File: Sendable, Equatable {
        public let sha1: String
        public let isPrimary: Bool

        public init(sha1: String, isPrimary: Bool) {
            self.sha1 = sha1
            self.isPrimary = isPrimary
        }
    }

    public let dependencies: [Dependency]
    public let files: [File]

    public init(
        dependencies: [Dependency] = [],
        files: [File] = [],
    ) {
        self.dependencies = dependencies
        self.files = files
    }
}

/// Lightweight record for a mod file found in a `mods` directory.
public struct ModDependencyGraphItem: Sendable, Equatable {
    public static let requiredDependencyType = "required"

    public let projectId: String
    public let title: String
    public let iconUrl: String?
    public let dependencyProjectIds: [String]
    public let fileName: String
    public let isEnabled: Bool

    public init(
        project: ModDependencyGraphProject,
        installedVersion: ModDependencyGraphVersion?,
        fileName: String,
        isEnabled: Bool,
    ) {
        projectId = project.projectId
        title = project.title
        iconUrl = project.iconUrl
        self.fileName = fileName
        self.isEnabled = isEnabled

        var dependencies: [String] = []
        var seenProjectIds: Set<String> = []
        for dependency in installedVersion?.dependencies ?? []
            where dependency.type == Self.requiredDependencyType {
            guard let dependencyId = dependency.projectId,
                  dependencyId != project.projectId,
                  seenProjectIds.insert(dependencyId).inserted
            else {
                continue
            }
            dependencies.append(dependencyId)
        }
        dependencyProjectIds = dependencies
    }

    public init(
        projectId: String,
        title: String,
        iconUrl: String?,
        dependencyProjectIds: [String],
        fileName: String,
        isEnabled: Bool,
    ) {
        self.projectId = projectId
        self.title = title
        self.iconUrl = iconUrl
        self.dependencyProjectIds = dependencyProjectIds
        self.fileName = fileName
        self.isEnabled = isEnabled
    }
}
