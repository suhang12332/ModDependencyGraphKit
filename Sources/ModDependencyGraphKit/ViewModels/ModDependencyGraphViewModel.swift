//
//  ModDependencyGraphViewModel.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import Foundation
import Observation

/// Loads a dependency graph and resolves the icons shown by the graph view.
@MainActor
@Observable
public final class ModDependencyGraphViewModel {
    public enum Phase {
        case idle
        case loading
        case ready(ModDependencyGraphLayout)
        case failed(String)
    }

    public typealias GraphProvider = @MainActor () async throws -> ModDependencyGraph
    public typealias GameIconProvider = @MainActor () async -> NSImage?

    public private(set) var phase: Phase = .idle
    public private(set) var projectIcons: [String: NSImage] = [:]
    public private(set) var gameIcon: NSImage?

    @ObservationIgnored private let graphProvider: GraphProvider
    @ObservationIgnored private let gameIconProvider: GameIconProvider
    @ObservationIgnored private var loadedGameID: String?
    @ObservationIgnored private var loadGeneration = 0

    public init(
        graphProvider: @escaping GraphProvider,
        gameIconProvider: @escaping GameIconProvider = { nil },
    ) {
        self.graphProvider = graphProvider
        self.gameIconProvider = gameIconProvider
    }

    public var isLoading: Bool {
        if case .loading = phase {
            return true
        }
        return false
    }

    public var isReady: Bool {
        if case .ready = phase {
            return true
        }
        return false
    }

    public func clear() {
        loadGeneration &+= 1
        phase = .idle
        projectIcons = [:]
        gameIcon = nil
        loadedGameID = nil
    }

    public func load(gameID: String, force: Bool = false) async {
        guard force || loadedGameID != gameID || !isReady else {
            return
        }

        loadGeneration &+= 1
        let generation = loadGeneration
        phase = .loading
        projectIcons = [:]
        gameIcon = nil

        do {
            let prepared = try await preparePresentation()
            guard !Task.isCancelled, generation == loadGeneration else {
                return
            }
            let icons = await ModDependencyIconLoader.load(iconURLs: prepared.iconURLs)
            let gameIcon = await gameIconProvider()

            guard !Task.isCancelled, generation == loadGeneration else {
                return
            }

            projectIcons = icons
            self.gameIcon = gameIcon
            loadedGameID = gameID
            phase = .ready(prepared.layout)
        } catch {
            guard !Task.isCancelled, generation == loadGeneration else {
                return
            }
            phase = .failed(error.localizedDescription)
        }
    }

    /// Builds the lightweight render model and icon URL list in a short-lived
    /// scope so the source graph can be released before image downloads begin.
    private func preparePresentation() async throws
        -> (layout: ModDependencyGraphLayout, iconURLs: [String: URL])
    {
        let (nodes, edges, iconURLs) = try await buildRenderData()

        // Graph layout is pure CPU work; keep it off the main actor so opening
        // the window does not block the UI while the graph is being arranged.
        let layout = await Task.detached(priority: .userInitiated) {
            ModDependencyGraphLayout(nodes: nodes, edges: edges)
        }.value

        return (layout, iconURLs)
    }

    /// Extracts only the data needed for rendering.
    private func buildRenderData() async throws
        -> (
            nodes: [ModDependencyGraph.Node],
            edges: [ModDependencyGraph.Edge],
            iconURLs: [String: URL]
        )
    {
        let graph = try await graphProvider()
        return (
            graph.nodes,
            graph.edges,
            ModDependencyIconLoader.iconURLs(for: graph),
        )
    }
}
