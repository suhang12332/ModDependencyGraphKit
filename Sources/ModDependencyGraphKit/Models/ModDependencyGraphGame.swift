//
//  ModDependencyGraphGame.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit

/// Display data for the root card of a dependency graph.
public struct ModDependencyGraphGame {
    public let title: String
    public let detail: String
    public let icon: NSImage?

    public init(
        title: String,
        detail: String = "",
        icon: NSImage? = nil,
    ) {
        self.title = title
        self.detail = detail
        self.icon = icon
    }
}
