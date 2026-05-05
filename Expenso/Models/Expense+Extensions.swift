//
//  Expense+Extensions.swift
//  Expenso
//

import Foundation
import CoreData
import SwiftUI

extension Expense {
    var displayTitle: String { title ?? "" }
    /// 表示名: 解決できた Profile の現在名 → ParticipantProfile の現在名 → 保存時の paidBy の順で fallback
    @MainActor
    var displayPaidBy: String {
        if let n = resolvedPayer?.displayName, !n.isEmpty { return n }
        if let n = resolvedParticipantProfile?.displayName, !n.isEmpty { return n }
        return paidBy ?? ""
    }
    @MainActor
    var payerTint: Color {
        resolvedPayer?.tint
            ?? Color(hex: resolvedParticipantProfile?.displayColorHex ?? "")
            ?? .secondary
    }
    /// Avatar 用: 解決できた Member / ParticipantProfile の写真
    @MainActor
    var payerPhotoData: Data? {
        resolvedPayer?.photoData ?? resolvedParticipantProfile?.photoData
    }

    /// `payerProfileID` (= Member.profileID) で Member を引く。Private ストアのみに存在。
    /// ID で見つからなければ `paidBy` 名前一致にフォールバック (旧データ向け)。
    @MainActor
    var resolvedPayer: Member? {
        let pc = PersistenceController.shared
        let ctx = managedObjectContext ?? pc.container.viewContext
        if !objectID.isTemporaryID,
           let store = objectID.persistentStore,
           store == pc.sharedStore {
            return nil
        }
        // 1) ID 一致 (UUID)
        if let pid = payerProfileID, !pid.isEmpty,
           let uuid = UUID(uuidString: pid) {
            let req = NSFetchRequest<Member>(entityName: "Member")
            req.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            req.fetchLimit = 1
            if let m = (try? ctx.fetch(req))?.first { return m }
        }
        // 2) ID 一致 (CK recordName == 自分の selfMember)
        if let pid = payerProfileID, !pid.isEmpty,
           let rn = UserProfileStore.shared.userRecordName, rn == pid,
           let selfID = UserProfileStore.shared.selfMemberID {
            let req = NSFetchRequest<Member>(entityName: "Member")
            req.predicate = NSPredicate(format: "id == %@", selfID as CVarArg)
            req.fetchLimit = 1
            if let m = (try? ctx.fetch(req))?.first { return m }
        }
        // 3) 名前一致 (旧データ移行用)
        guard let name = paidBy, !name.isEmpty else { return nil }
        let req = NSFetchRequest<Member>(entityName: "Member")
        req.predicate = NSPredicate(format: "name == %@", name)
        req.fetchLimit = 1
        return (try? ctx.fetch(req))?.first
    }

    /// `generatedFromRuleID` から元の RecurringRule を引く (定期から生成された支出のみ非 nil)。
    var relatedRule: RecurringRule? {
        guard let id = generatedFromRuleID else { return nil }
        let ctx = managedObjectContext ?? PersistenceController.shared.container.viewContext
        let req = NSFetchRequest<RecurringRule>(entityName: "RecurringRule")
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        return (try? ctx.fetch(req))?.first
    }

    /// 同シート配下の ParticipantProfile を引く。recordName 一致 → displayName 一致の順。
    var resolvedParticipantProfile: ParticipantProfile? {
        guard let sheet = sheet,
              let profiles = sheet.participantProfiles as? Set<ParticipantProfile> else { return nil }
        // 1) recordName 一致
        if let pid = payerProfileID, !pid.isEmpty,
           let pp = profiles.first(where: { $0.recordName == pid }) {
            return pp
        }
        // 2) displayName 一致 (旧データ移行用)
        guard let name = paidBy, !name.isEmpty else { return nil }
        return profiles.first(where: { $0.displayName == name })
    }

    var amountDecimal: Decimal {
        get { (amount ?? 0) as Decimal }
        set { amount = NSDecimalNumber(decimal: newValue) }
    }

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw ?? "") ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    /// 通貨コード (空なら親シートの既定 → JPY)
    var resolvedCurrencyCode: String {
        if let c = currencyCode, !c.isEmpty { return c }
        if let s = sheet?.resolvedDefaultCurrencyCode, !s.isEmpty { return s }
        return CurrencyCatalog.defaultCode
    }

    /// 通貨記号付きの金額表示 (符号は kind に応じて変える呼び出し元で扱う)
    var formattedAmount: String {
        CurrencyCatalog.format(amountDecimal, code: resolvedCurrencyCode)
    }

    /// 符号付き表示 (収入は正、支出は負として表現)
    var formattedSignedAmount: String {
        let sign = kind == .expense ? "-" : "+"
        return sign + formattedAmount
    }

    /// `category` リレーションが nil でも、`categoryRaw` (名前) とシートのカテゴリ集合から
    /// 一致するものを引いて返すフォールバック付きアクセサ。
    /// Shared/Private のクロスストアで linkage が外れたケースでも、表示が正しく出るようにする。
    var resolvedCategory: ExpenseCategory? {
        if let c = category { return c }
        guard let raw = categoryRaw, !raw.isEmpty,
              let sheet = sheet,
              let cats = sheet.categories as? Set<ExpenseCategory> else { return nil }
        return cats.first(where: { $0.name == raw })
    }

    var categoryDisplayName: String {
        resolvedCategory?.displayName ?? (categoryRaw?.isEmpty == false ? categoryRaw! : "未分類")
    }

    var categoryTint: Color {
        resolvedCategory?.tint ?? .gray
    }

    var categorySymbol: String {
        resolvedCategory?.displaySymbol ?? "ellipsis.circle"
    }
}
