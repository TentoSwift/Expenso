//
//  NetworkMonitor.swift
//  Expenso
//
//  ネットワーク到達可否を監視するシングルトン。
//  Free tier のシート作成ゲートで、iCloud 同期不可状態のオフライン作成を
//  防ぐために使う (= multi-device race window を縮小)。
//

import Foundation
import Network
import Combine

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isOnline: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.tento.Expenso.NetworkMonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            DispatchQueue.main.async {
                guard let self else { return }
                if self.isOnline != online {
                    self.isOnline = online
                }
            }
        }
        monitor.start(queue: queue)
    }
}
