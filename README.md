# ModDependencyGraphKit

A Swift Package for building, laying out, and rendering mod dependency graphs. Data sources are injected through closures, so the package has no dependency on a specific launcher or Modrinth types. This package is used by [Swift Craft Launcher](https://github.com/suhang12332/Swift-Craft-Launcher).

## Features

- Dependency graph building and deduplication
- Deterministic automatic layout
- SwiftUI canvas with zoom, selection, and PNG export
- Asynchronous icon loading
- Built-in localization resources

## Entry Points

- `ModDependencyGraphService`: scans and builds the dependency graph
- `ModDependencyGraphLayout`: computes the layout
- `ModDependencyGraphCanvasView`: renders the graph canvas
- `ModDependencyGraphWindowView`: complete window content
- `ModDependencyGraphViewModel`: loading and state management

## Requirements

- macOS 14+
- Swift 6
