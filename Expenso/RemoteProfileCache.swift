//
//  RemoteProfileCache.swift
//  Expenso
//
//  ShareCalendarApp の ProfileCache を参考に、他ユーザーのプロフィール
//  (displayName / iconSymbol / colorHex) を CloudKit Public DB から取得し
//  Caches ディレクトリにキャッシュする。
//

import Foundation
import SwiftUI
import Combine
import CloudKit

@MainActor
final class RemoteProfileCache: ObservableObject {
    static let shared = RemoteProfileCache()

    struct CachedProfile: Codable, Equatable {
        var recordName: String
        var displayName: String?
        var iconSymbol: String?
        var colorHex: String?
        var lastFetched: Date

        func isStale(olderThan seconds: TimeInterval = 3600) -> Bool {
            Date().timeIntervalSince(lastFetched) > seconds
        }
    }

    @Published private(set) var entries: [String: CachedProfile] = [:]

    private let containerID = "iCloud.com.tento.Expenso"
    private static let cacheURL: URL = {
        let dir = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ExpensoProfiles", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("profiles.json")
    }()

    private var inFlight: Set<String> = []

    private init() {
        load()
    }

    // MARK: - Read

    func profile(for recordName: String) -> CachedProfile? {
        entries[recordName]
    }

    func displayName(for recordName: String) -> String? {
        entries[recordName]?.displayName
    }

    func iconSymbol(for recordName: String) -> String? {
        entries[recordName]?.iconSymbol
    }

    func tint(for recordName: String) -> Color? {
        guard let hex = entries[recordName]?.colorHex else { return nil }
        return Color(hex: hex)
    }

    // MARK: - Fetch

    func fetchIfStale(_ recordNames: [String]) async {
        let stale = recordNames.filter { name in
            guard !inFlight.contains(name) else { return false }
            guard let entry = entries[name] else { return true }
            return entry.isStale()
        }
        guard !stale.isEmpty else { return }
        await fetch(stale)
    }

    func fetch(_ recordNames: [String]) async {
        let targets = recordNames.filter { !inFlight.contains($0) }
        guard !targets.isEmpty else { return }
        targets.forEach { inFlight.insert($0) }
        defer { targets.forEach { inFlight.remove($0) } }

        let container = CKContainer(identifier: containerID)
        await withTaskGroup(of: CachedProfile?.self) { group in
            for recordName in targets {
                group.addTask {
                    let id = CKRecord.ID(recordName: "profile_\(recordName)")
                    guard let record = try? await container.publicCloudDatabase.record(for: id),
                          record.recordType == "UserProfile" else {
                        return nil
                    }
                    return CachedProfile(
                        recordName: recordName,
                        displayName: record["displayName"] as? String,
                        iconSymbol:  record["iconSymbol"] as? String,
                        colorHex:    record["colorHex"] as? String,
                        lastFetched: .now
                    )
                }
            }
            for await result in group {
                guard let profile = result else { continue }
                entries[profile.recordName] = profile
            }
        }
        persist()
    }

    func fetchIfStale(participants: [CKShare.Participant]) async {
        let recordNames: [String] = participants.compactMap { p in
            guard let rn = p.userIdentity.userRecordID?.recordName else { return nil }
            if rn.isEmpty || rn == "_defaultOwner_" || rn == "__defaultOwner__" { return nil }
            return rn
        }
        await fetchIfStale(recordNames)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: Self.cacheURL),
              let decoded = try? JSONDecoder().decode([String: CachedProfile].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: Self.cacheURL, options: .atomic)
    }
}
