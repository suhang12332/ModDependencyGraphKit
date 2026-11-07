//
//  ModDependencyGraphCards.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftUI

/// Root card showing the game and its loader information.
struct ModDependencyGraphGameCard: View {
    let game: ModDependencyGraphGame

    var body: some View {
        HStack(spacing: 8) {
            DependencyIcon(
                image: game.icon,
                fallbackSymbol: "gamecontroller.fill",
                size: 32,
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(game.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if !game.detail.isEmpty {
                    Text(game.detail)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(7)
        .frame(
            width: ModDependencyGraphLayout.gameCardSize.width,
            height: ModDependencyGraphLayout.gameCardSize.height,
            alignment: .leading,
        )
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor)),
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
        }
    }
}

/// Card showing one installed (or missing) mod and its dependency metadata.
struct ModDependencyGraphModCard: View {
    let node: ModDependencyGraph.Node
    let icon: NSImage?
    var isSelected: Bool = false

    private var fileNameText: String {
        node.fileName ?? String(localized: "mod.dependency_graph.not_installed", bundle: .module)
    }

    private var borderColor: Color {
        if node.isCycle {
            return .purple.opacity(0.65)
        }
        return .secondary.opacity(0.3)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            DependencyIcon(
                image: icon,
                fallbackSymbol: node.isInstalled ? "puzzlepiece.extension.fill" : "questionmark.folder",
                size: 32,
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(node.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(fileNameText)
                    .font(.system(size: 9))
                    .foregroundStyle(node.isInstalled ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.red))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Match the local resource list's 50% opacity for disabled mod content.
        .opacity(node.isEnabled ? 1 : 0.5)
        .padding(7)
        .frame(
            width: ModDependencyGraphLayout.nodeSize.width,
            height: ModDependencyGraphLayout.nodeSize.height,
            alignment: .leading,
        )
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor)),
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : borderColor,
                    lineWidth: isSelected ? 2.2 : 1,
                )
        }
    }
}

private struct DependencyIcon: View {
    let image: NSImage?
    let fallbackSymbol: String
    let size: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(nsColor: .quaternaryLabelColor).opacity(0.2)
                    Image(systemName: fallbackSymbol)
                        .font(.system(size: size * 0.42))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
    }
}
