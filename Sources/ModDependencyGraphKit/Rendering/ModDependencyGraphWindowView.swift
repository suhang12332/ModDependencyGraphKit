//
//  ModDependencyGraphWindowView.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Complete dependency-graph window content: loading, error, canvas, reload,
/// and PNG export.
public struct ModDependencyGraphWindowView: View {
    private let gameID: String
    private let gameName: String
    private let gameDetail: String
    private let onSaveError: @MainActor (String) -> Void

    @State private var viewModel: ModDependencyGraphViewModel
    @State private var isSaving = false

    public init(
        gameID: String,
        gameName: String,
        gameDetail: String,
        graphProvider: @escaping ModDependencyGraphViewModel.GraphProvider,
        gameIconProvider: @escaping ModDependencyGraphViewModel.GameIconProvider,
        onSaveError: @escaping @MainActor (String) -> Void = { _ in },
    ) {
        self.gameID = gameID
        self.gameName = gameName
        self.gameDetail = gameDetail
        self.onSaveError = onSaveError
        _viewModel = State(initialValue: ModDependencyGraphViewModel(
            graphProvider: graphProvider,
            gameIconProvider: gameIconProvider,
        ))
    }

    public var body: some View {
        Group {
            switch viewModel.phase {
            case .idle, .loading:
                loadingView
            case let .ready(layout):
                graphView(layout)
            case let .failed(message):
                errorView(message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: gameID) {
            await viewModel.load(gameID: gameID)
        }
        .onDisappear {
            viewModel.clear()
        }
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await viewModel.load(gameID: gameID, force: true) }
                } label: {
                    Label(String(localized: "mod.dependency_graph.reload", bundle: .module), systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }

            ToolbarItem {
                Button {
                    saveImage()
                } label: {
                    Label(String(localized: "common.save", bundle: .module), systemImage: "photo.badge.arrow.down")
                }
                .disabled(!viewModel.isReady || isSaving)
            }
        }
    }

    private var loadingView: some View {
        ProgressView()
            .controlSize(.small)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label(
                String(localized: "mod.dependency_graph.failed.title", bundle: .module),
                systemImage: "exclamationmark.triangle",
            )
        } description: {
            Text(message)
        } actions: {
            Button(String(localized: "mod.dependency_graph.reload", bundle: .module)) {
                Task { await viewModel.load(gameID: gameID, force: true) }
            }
        }
    }

    private func graphView(_ layout: ModDependencyGraphLayout) -> some View {
        ModDependencyGraphCanvasView(
            layout: layout,
            game: gameInfo,
            projectIcons: viewModel.projectIcons,
        )
    }

    private func saveImage() {
        guard case let .ready(layout) = viewModel.phase, !isSaving else {
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(sanitizedFileName)-mod-dependencies.png"

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        let projectIcons = viewModel.projectIcons
        let gameIcon = viewModel.gameIcon
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }

            let content = ModDependencyGraphExportView(
                layout: layout,
                game: ModDependencyGraphGame(
                    title: gameName,
                    detail: gameDetail,
                    icon: gameIcon,
                ),
                projectIcons: projectIcons,
            )
            let renderer = ImageRenderer(content: content)
            let maxDimension: CGFloat = 12000
            let longestSide = max(layout.size.width, layout.size.height)
            renderer.scale = min(3, maxDimension / longestSide)

            guard let image = renderer.cgImage else {
                reportImageSaveFailure(destinationURL)
                return
            }
            guard let destination = CGImageDestinationCreateWithURL(
                destinationURL as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil,
            ) else {
                reportImageSaveFailure(destinationURL)
                return
            }

            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else {
                reportImageSaveFailure(destinationURL)
                return
            }
        }
    }

    private var gameInfo: ModDependencyGraphGame {
        ModDependencyGraphGame(
            title: gameName,
            detail: gameDetail,
            icon: viewModel.gameIcon,
        )
    }

    private var sanitizedFileName: String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        return gameName
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func reportImageSaveFailure(_ destinationURL: URL) {
        onSaveError("Failed to write dependency graph PNG to \(destinationURL.path)")
    }
}
