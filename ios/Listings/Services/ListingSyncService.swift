import Foundation

/// Background service component: while the app is active, it periodically
/// refreshes listings from the Go API so new posts show up without a manual refresh.
/// Started and stopped by `RootView` as the app moves between foreground and background.
@MainActor
final class ListingSyncService {
    private var task: Task<Void, Never>?
    private let interval: Duration

    init(interval: Duration = .seconds(30)) {
        self.interval = interval
    }

    var isRunning: Bool { task != nil }

    func start(refresh: @escaping @MainActor () async -> Void) {
        guard task == nil else { return }
        let interval = interval
        task = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                if Task.isCancelled { break }
                await refresh()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
