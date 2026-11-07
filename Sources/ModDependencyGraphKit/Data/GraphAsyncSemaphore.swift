//
//  GraphAsyncSemaphore.swift
//  ModDependencyGraphKit
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A semaphore that integrates with Swift's structured concurrency.
actor GraphAsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.value = value
    }

    func wait() async {
        if value > 0 {
            value -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if !waiters.isEmpty {
            let continuation = waiters.removeFirst()
            continuation.resume()
        } else {
            value += 1
        }
    }
}
