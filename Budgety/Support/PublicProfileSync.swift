//
//  PublicProfileSync.swift
//  Budgety
//
//  全ユーザーのプロフィール (displayName + photo) を CloudKit Public DB に保存する。
//  従来は per-sheet の ParticipantProfile (CKShare zone) に書いていたが、これだと
//  クロスデバイス整合性とシート毎の二重管理が問題になっていた。Public DB に置けば
//  単一の source of truth になり、相手のプロフィールも 1 回 fetch すれば全シートで使える。
//
//  キー: `userRecordID.recordName` (URN)。Apple ID あたり 1 レコード。
//  プライバシー: Public DB は同 container 利用者全員から読み取り可能 (オンボーディングで合意取得済み)。
//
//  Phase 1: このサービスは displayName と photo のみを担当する。canonical ID 体系
//  (Expense.payerProfileID 等) は別フェーズで URN ベースに統一する。
//

import Foundation
import Combine
import CloudKit
import os.log

@MainActor
final class PublicProfileSync: ObservableObject {
    static let shared = PublicProfileSync()

    private static let log = Logger(subsystem: "com.tento.budgety", category: "PublicProfileSync")

    /// CloudKit Public DB の record type 名。Dashboard で同名のレコードを deploy する必要がある。
    static let recordType = "PublicProfile"
    private static let fieldDisplayName = "displayName"
    private static let fieldPhoto = "photo"
    private static let fieldUpdatedAt = "updatedAt"

    private let containerID = "iCloud.com.tento.budgety"
    private var container: CKContainer { CKContainer(identifier: containerID) }
    private var publicDB: CKDatabase { container.publicCloudDatabase }

    /// キャッシュ済みプロフィール。Published で View に変更通知する。
    /// key = URN, value = (displayName, photoData, updatedAt, fetchedAt)。
    @Published private(set) var cache: [String: CachedProfile] = [:]

    /// fetch / upload 中フラグ (UI でローディング表示する用)。
    @Published private(set) var isBusy: Bool = false

    /// 直前のエラー (デバッグ表示用)
    @Published private(set) var lastError: String?

    /// キャッシュ TTL。これより古い fetchedAt のものは再 fetch する。
    /// (= 同セッション中は再 fetch しない、ただし app foreground 化や手動 refresh は強制)
    private static let cacheTTL: TimeInterval = 60 * 30   // 30 min

    /// キャッシュ persistence (起動間で保持) のための UserDefaults キー
    private static let udCacheKey = "publicProfile.cache.v1"

    struct CachedProfile: Codable, Equatable {
        let displayName: String
        let photoData: Data?
        let updatedAt: Date
        let fetchedAt: Date
    }

    private init() {
        self.cache = Self.loadCacheFromDisk()
    }

    // MARK: - Disk-backed cache

    private static func loadCacheFromDisk() -> [String: CachedProfile] {
        guard let data = UserDefaults.standard.data(forKey: udCacheKey) else { return [:] }
        return (try? JSONDecoder().decode([String: CachedProfile].self, from: data)) ?? [:]
    }

    private func saveCacheToDisk() {
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: Self.udCacheKey)
        }
    }

    // MARK: - Lookup

    /// キャッシュからの即時参照 (fetch しない)。表示時の高頻度呼び出し用。
    func cachedProfile(for urn: String) -> CachedProfile? {
        guard !urn.isEmpty else { return nil }
        return cache[urn]
    }

    /// キャッシュにあれば即返し、無いか TTL 切れなら背景 fetch をキック。
    /// 表示中に裏で取得するイメージ。
    @discardableResult
    func profileOrPrefetch(for urn: String) -> CachedProfile? {
        guard !urn.isEmpty else { return nil }
        let existing = cache[urn]
        let needsRefresh: Bool = {
            guard let existing else { return true }
            return Date().timeIntervalSince(existing.fetchedAt) > Self.cacheTTL
        }()
        if needsRefresh {
            Task { await fetchProfiles(forURNs: [urn]) }
        }
        return existing
    }

    // MARK: - Fetch others

    /// 複数 URN のプロフィールをまとめて取得し、キャッシュに格納する。
    func fetchProfiles(forURNs urns: [String]) async {
        let cleaned = urns
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return }
        let ids = cleaned.map { CKRecord.ID(recordName: $0) }
        do {
            isBusy = true
            defer { isBusy = false }
            let result = try await publicDB.records(for: ids)
            var anyChange = false
            let now = Date()
            for (rid, recordRes) in result {
                switch recordRes {
                case .success(let rec):
                    let dn = (rec[Self.fieldDisplayName] as? String) ?? ""
                    var photoData: Data? = nil
                    if let asset = rec[Self.fieldPhoto] as? CKAsset, let url = asset.fileURL {
                        photoData = try? Data(contentsOf: url)
                    }
                    let updatedAt = (rec[Self.fieldUpdatedAt] as? Date) ?? rec.modificationDate ?? now
                    let cached = CachedProfile(
                        displayName: dn,
                        photoData: photoData,
                        updatedAt: updatedAt,
                        fetchedAt: now
                    )
                    if cache[rid.recordName] != cached {
                        cache[rid.recordName] = cached
                        anyChange = true
                    }
                case .failure(let error):
                    // unknown item は正常 (= 相手がまだ Public profile を書いていない)
                    if let ck = error as? CKError, ck.code == .unknownItem {
                        // do nothing
                    } else {
                        Self.log.debug("fetch \(rid.recordName, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                    }
                }
            }
            if anyChange { saveCacheToDisk() }
        } catch {
            lastError = error.localizedDescription
            Self.log.error("fetchProfiles failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Upload own

    /// 自分の URN + displayName + photoData を Public DB に upsert する。
    /// 写真は CKAsset として一時ファイルから upload する。
    func uploadOwnProfile(urn: String, displayName: String, photoData: Data?) async {
        let trimmedURN = urn.trimmingCharacters(in: .whitespaces)
        guard !trimmedURN.isEmpty else { return }
        let recordID = CKRecord.ID(recordName: trimmedURN)
        do {
            isBusy = true
            defer { isBusy = false }

            // 既存があれば取得して同じ recordID に upsert (modify)、無ければ create。
            let record: CKRecord
            do {
                record = try await publicDB.record(for: recordID)
            } catch let error as CKError where error.code == .unknownItem {
                record = CKRecord(recordType: Self.recordType, recordID: recordID)
            }
            record[Self.fieldDisplayName] = displayName as CKRecordValue
            record[Self.fieldUpdatedAt]   = Date() as CKRecordValue

            // 写真: photoData があれば CKAsset、無ければクリア
            if let data = photoData, !data.isEmpty {
                let tmpURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("public-profile-\(UUID().uuidString).jpg")
                try data.write(to: tmpURL, options: .atomic)
                record[Self.fieldPhoto] = CKAsset(fileURL: tmpURL)
            } else {
                record[Self.fieldPhoto] = nil
            }

            _ = try await publicDB.save(record)

            // 自分のキャッシュも更新
            let now = Date()
            let cached = CachedProfile(
                displayName: displayName,
                photoData: photoData,
                updatedAt: now,
                fetchedAt: now
            )
            cache[trimmedURN] = cached
            saveCacheToDisk()
        } catch {
            lastError = error.localizedDescription
            Self.log.error("uploadOwnProfile failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Convenience

    /// すべてのキャッシュをクリアする (デバッグ / 「全データ削除」用)。
    func clearCache() {
        cache.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.udCacheKey)
    }
}
