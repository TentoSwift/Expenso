//
//  UserProfileStore.swift
//  Expenso
//
//  ShareCalendarApp の UserProfileStore を参考に、ユーザーのアイコンと名前を
//  端末/アカウント単位で保持する。シートとは独立。
//

import Foundation
import SwiftUI
import Combine
import CoreData
import CloudKit

@MainActor
final class UserProfileStore: ObservableObject {
    static let shared = UserProfileStore()

    private enum Keys {
        static let displayName  = "userProfile.displayName"
        static let iconSymbol   = "userProfile.iconSymbol"
        static let colorHex     = "userProfile.colorHex"
        static let selfMemberID = "userProfile.selfMemberID"
    }

    @Published var displayName: String {
        didSet {
            UserDefaults.standard.set(displayName, forKey: Keys.displayName)
            UserDefaults.standard.set(displayName, forKey: "displayName") // 後方互換
        }
    }

    @Published var iconSymbol: String {
        didSet { UserDefaults.standard.set(iconSymbol, forKey: Keys.iconSymbol) }
    }

    @Published var colorHex: String {
        didSet { UserDefaults.standard.set(colorHex, forKey: Keys.colorHex) }
    }

    @Published private(set) var selfMemberID: UUID? {
        didSet {
            UserDefaults.standard.set(selfMemberID?.uuidString, forKey: Keys.selfMemberID)
        }
    }

    var tint: Color { Color(hex: colorHex) ?? .blue }

    var resolvedDisplayName: String {
        displayName.isEmpty ? "自分" : displayName
    }

    private init() {
        let ud = UserDefaults.standard
        self.displayName = ud.string(forKey: Keys.displayName)
            ?? ud.string(forKey: "displayName") // 古いキーから移行
            ?? ""
        self.iconSymbol = ud.string(forKey: Keys.iconSymbol) ?? "person.fill"
        self.colorHex   = ud.string(forKey: Keys.colorHex) ?? "#5B8DEF"
        if let str = ud.string(forKey: Keys.selfMemberID), let id = UUID(uuidString: str) {
            self.selfMemberID = id
        } else {
            self.selfMemberID = nil
        }
    }

    /// Settings 編集後に呼ぶ。selfMemberID に対応する Member エンティティを
    /// 作成または更新して、プロフィールを反映する。
    func applyToSelfMember(in ctx: NSManagedObjectContext) {
        let resolvedID: UUID
        if let id = selfMemberID {
            resolvedID = id
        } else {
            resolvedID = UUID()
            selfMemberID = resolvedID
        }

        // 既存検索
        let req = NSFetchRequest<Member>(entityName: "Member")
        req.predicate = NSPredicate(format: "id == %@", resolvedID as CVarArg)
        req.fetchLimit = 1
        let member: Member
        if let existing = (try? ctx.fetch(req))?.first {
            member = existing
        } else {
            // 既存メンバー (旧スキーマからの移行) で名前一致するものを探す
            let nameReq = NSFetchRequest<Member>(entityName: "Member")
            nameReq.predicate = NSPredicate(format: "name == %@", resolvedDisplayName)
            nameReq.sortDescriptors = [NSSortDescriptor(keyPath: \Member.createdAt, ascending: true)]
            nameReq.fetchLimit = 1
            if let nameMatch = (try? ctx.fetch(nameReq))?.first {
                member = nameMatch
                // ID を上書きして profile に紐付け
                member.id = resolvedID
            } else {
                member = Member(context: ctx)
                member.id = resolvedID
                member.createdAt = .now
                member.sortOrder = 0
            }
        }

        member.name     = resolvedDisplayName
        member.colorHex = colorHex
        member.symbol   = iconSymbol

        try? ctx.save()
    }

    /// Settings の起動時に呼ぶ。Member が無く、Profile に未保存の場合にデフォルトを生成する。
    func ensureSelfMemberExists(in ctx: NSManagedObjectContext) {
        if selfMemberID != nil { return }
        applyToSelfMember(in: ctx)
    }

    // MARK: - CloudKit Public DB sync

    private static let containerID = "iCloud.com.tento.Expenso"
    private static let recordType = "UserProfile"

    /// 自分のプロフィールを CloudKit Public DB に保存する。
    /// recordName 形式: `profile_<userRecordName>` で他デバイスからフェッチ可能。
    func saveToCloudKit() async {
        let container = CKContainer(identifier: Self.containerID)
        do {
            let userID = try await container.userRecordID()
            let profileID = CKRecord.ID(recordName: "profile_\(userID.recordName)")
            let record: CKRecord
            if let existing = try? await container.publicCloudDatabase.record(for: profileID),
               existing.recordType == Self.recordType {
                record = existing
            } else {
                record = CKRecord(recordType: Self.recordType, recordID: profileID)
            }
            record["displayName"] = resolvedDisplayName as CKRecordValue
            record["iconSymbol"]  = iconSymbol as CKRecordValue
            record["colorHex"]    = colorHex as CKRecordValue
            _ = try await container.publicCloudDatabase.save(record)
        } catch {
            // 失敗しても致命的ではない (オフライン等)。次回再試行。
        }
    }

    /// 起動時に Public DB から自分のプロフィールを取得して、ローカルが空なら反映する。
    /// (他デバイスでセットアップ済みのプロフィールを引き継ぐため)
    func refreshFromCloudKit() async {
        let container = CKContainer(identifier: Self.containerID)
        do {
            let userID = try await container.userRecordID()
            let profileID = CKRecord.ID(recordName: "profile_\(userID.recordName)")
            guard let record = try? await container.publicCloudDatabase.record(for: profileID),
                  record.recordType == Self.recordType else { return }
            await MainActor.run {
                if displayName.isEmpty, let n = record["displayName"] as? String, !n.isEmpty {
                    displayName = n
                }
                if iconSymbol == "person.fill", let s = record["iconSymbol"] as? String, !s.isEmpty {
                    iconSymbol = s
                }
                if colorHex == "#5B8DEF", let c = record["colorHex"] as? String, !c.isEmpty {
                    colorHex = c
                }
            }
        } catch {
            // 失敗時はローカルのまま続行
        }
    }
}
