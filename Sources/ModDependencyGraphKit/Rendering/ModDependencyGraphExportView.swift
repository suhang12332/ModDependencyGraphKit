//
//  ModDependencyGraphExportView.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftUI

/// Immutable graph rendering used when saving a high-resolution image.
public struct ModDependencyGraphExportView: View {
    public let layout: ModDependencyGraphLayout
    public let game: ModDependencyGraphGame
    public let projectIcons: [String: NSImage]

    public init(
        layout: ModDependencyGraphLayout,
        game: ModDependencyGraphGame,
        projectIcons: [String: NSImage],
    ) {
        self.layout = layout
        self.game = game
        self.projectIcons = projectIcons
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                drawModDependencyConnections(
                    edges: layout.edges,
                    frames: layout.framesByNodeID,
                    in: &context,
                )
            }
            .frame(width: layout.size.width, height: layout.size.height)

            ModDependencyGraphGameCard(game: game)
                .position(x: layout.rootFrame.midX, y: layout.rootFrame.midY)

            ForEach(layout.nodes) { node in
                ModDependencyGraphModCard(
                    node: node.mod,
                    icon: projectIcons[node.mod.projectId],
                )
                .position(x: node.frame.midX, y: node.frame.midY)
            }
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.colorScheme, .light)
    }
}
