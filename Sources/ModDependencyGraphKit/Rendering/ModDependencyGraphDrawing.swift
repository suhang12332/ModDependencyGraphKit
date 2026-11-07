//
//  ModDependencyGraphDrawing.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import CoreGraphics
import SwiftUI

private struct DependencyConnectionPaths {
    var rootConnections = Path()
    var modConnections = Path()
    var rootArrows = Path()
    var modArrows = Path()
}

/// Draws dependency connections for both the live canvas and image export.
func drawModDependencyConnections(
    edges: [ModDependencyGraphLayout.Edge],
    frames: [String: CGRect],
    in context: inout GraphicsContext,
) {
    let paths = dependencyConnectionPaths(
        edges: edges,
        frames: frames,
    )
    let lineStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
    context.stroke(paths.rootConnections, with: .color(.accentColor.opacity(0.5)), style: lineStyle)
    context.stroke(paths.modConnections, with: .color(.secondary.opacity(0.42)), style: lineStyle)
    context.fill(paths.rootArrows, with: .color(.accentColor.opacity(0.8)))
    context.fill(paths.modArrows, with: .color(.secondary.opacity(0.65)))
}

private func dependencyConnectionPaths(
    edges: [ModDependencyGraphLayout.Edge],
    frames: [String: CGRect],
) -> DependencyConnectionPaths {
    var paths = DependencyConnectionPaths()

    for edge in edges {
        let isRootEdge = edge.from == ModDependencyGraphLayout.gameNodeID
        let source = frames[edge.from]!
        let target = frames[edge.to]!

        let isRightward = target.midX >= source.midX
        let start = CGPoint(
            x: isRightward ? source.maxX : source.minX,
            y: source.midY,
        )
        let end = CGPoint(
            x: isRightward ? target.minX : target.maxX,
            y: target.midY,
        )
        let bend = max(36, abs(end.x - start.x) * 0.45)
        let control1 = CGPoint(
            x: isRightward ? start.x + bend : start.x - bend,
            y: start.y,
        )
        let control2 = CGPoint(
            x: isRightward ? end.x - bend : end.x + bend,
            y: end.y,
        )

        if isRootEdge {
            paths.rootConnections.move(to: start)
            paths.rootConnections.addCurve(to: end, control1: control1, control2: control2)
            appendModDependencyArrowhead(at: end, control: control2, to: &paths.rootArrows)
        } else {
            paths.modConnections.move(to: start)
            paths.modConnections.addCurve(to: end, control1: control1, control2: control2)
            appendModDependencyArrowhead(at: end, control: control2, to: &paths.modArrows)
        }
    }
    return paths
}

private func appendModDependencyArrowhead(
    at end: CGPoint,
    control: CGPoint,
    to arrow: inout Path,
) {
    let angle = atan2(end.y - control.y, end.x - control.x)

    let length: CGFloat = 7
    let width: CGFloat = 4
    let base = CGPoint(
        x: end.x - length * cos(angle),
        y: end.y - length * sin(angle),
    )
    let left = CGPoint(
        x: base.x - width * sin(angle),
        y: base.y + width * cos(angle),
    )
    let right = CGPoint(
        x: base.x + width * sin(angle),
        y: base.y - width * cos(angle),
    )

    arrow.move(to: end)
    arrow.addLine(to: left)
    arrow.addLine(to: right)
    arrow.closeSubpath()
}
