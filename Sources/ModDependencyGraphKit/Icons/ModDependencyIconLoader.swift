//
//  ModDependencyIconLoader.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import Foundation
import ImageIO

/// Loads dependency-graph icons before rendering so node cards can display them
/// synchronously.
public enum ModDependencyIconLoader {
    public static let maxConcurrentDownloads = 8

    /// Resolves the icon URLs needed by a graph.
    @MainActor
    public static func iconURLs(for graph: ModDependencyGraph) -> [String: URL] {
        var iconURLs: [String: URL] = [:]
        for node in graph.nodes {
            if let url = iconURL(from: node.iconUrl) {
                iconURLs[node.projectId] = url
            }
        }
        return iconURLs
    }

    @MainActor
    public static func load(iconURLs: [String: URL]) async -> [String: NSImage] {
        let semaphore = GraphAsyncSemaphore(value: maxConcurrentDownloads)
        var projectIcons: [String: NSImage] = [:]
        await withTaskGroup(of: (String, CGImage?).self) { group in
            for (projectId, url) in iconURLs {
                group.addTask {
                    await semaphore.wait()
                    let data = await loadData(from: url)
                    await semaphore.signal()
                    return (projectId, data.flatMap { thumbnail(from: $0) })
                }
            }

            for await (projectId, cgImage) in group {
                if let cgImage {
                    projectIcons[projectId] = NSImage(
                        cgImage: cgImage,
                        size: NSSize(width: cgImage.width, height: cgImage.height),
                    )
                }
            }
        }

        return projectIcons
    }

    @MainActor
    public static func loadImage(from url: URL) async -> NSImage? {
        guard let data = await loadData(from: url) else {
            return nil
        }
        return NSImage(data: data)
    }

    private static func iconURL(from iconUrl: String?) -> URL? {
        guard let iconUrl else {
            return nil
        }
        if iconUrl.hasPrefix("data:image") {
            return URL(string: iconUrl)
        }
        if let url = URL(string: iconUrl), url.scheme != nil {
            return url
        }
        return URL(string: "data:image/png;base64,\(iconUrl)")
    }

    private static func loadData(from url: URL) async -> Data? {
        if url.scheme?.lowercased() == "data" {
            return dataFromDataURL(url)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .returnCacheDataElseLoad
        return try? await URLSession.shared.data(for: request).0
    }

    private static func dataFromDataURL(_ url: URL) -> Data? {
        let value = url.absoluteString
        guard let comma = value.firstIndex(of: ",") else {
            return nil
        }
        let payload = String(value[value.index(after: comma)...])
        let decoded = payload.removingPercentEncoding ?? payload
        return Data(base64Encoded: decoded)
    }

    /// Graph cards display icons at 32 points, so retaining full-resolution
    /// project art wastes memory. Decode each response directly to a small
    /// thumbnail and discard the source data immediately.
    private static func thumbnail(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        return CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 64,
                kCGImageSourceCreateThumbnailWithTransform: true,
            ] as CFDictionary,
        )
    }
}
