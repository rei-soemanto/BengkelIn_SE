//
//  NetworkMonitor.swift
//  BengkelIn
//
//  Created by Amadeus Eugene Dirgantara on 02/06/26.
//

import Combine
import Foundation
import Network

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

    func recheck() {
        isConnected = monitor.currentPath.status == .satisfied
    }

    deinit {
        monitor.cancel()
    }
}
