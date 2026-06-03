import Combine
import Foundation
import Network

// Observes network reachability via NWPathMonitor. `isConnected` starts true so
// the UI doesn't flash the offline screen before the first path update arrives.
@MainActor
final class NetworkMonitor: ObservableObject {
    @Published var isConnected = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor in self?.isConnected = connected }
        }
        monitor.start(queue: queue)
    }

    // Forces an immediate re-evaluation against the monitor's current path. Used by the
    // offline screen's "Coba Lagi" button so a tap re-checks connectivity instead of
    // waiting for the next passive path update (which may never come if the path didn't
    // change from the monitor's point of view).
    func recheck() {
        isConnected = monitor.currentPath.status == .satisfied
    }

    deinit {
        monitor.cancel()
    }
}
