//
//  QuickIntentLogic.swift
//  Budgety
//
//  Quick{Add,Get,Budget}Intent から呼ばれる共通ロジック。
//  どの AppIntent でも `[String: Any]` (= JSON パース結果) → `[String: Any]`
//  (= JSON 化される結果) という同じ I/F で実行する。
//

import CoreData
import Foundation

enum QuickIntentLogic {

    // MARK: - Add (支出 / 収入の追加)

    @MainActor
    static func add(parsed: [String: Any]) async -> [String: Any] {
        // amount: Double / Int / String
        let amount: Double = {
            if let v = parsed["amount"] as? Double { return v }
            if let v = parsed["amount"] as? Int    { return Double(v) }
            if let s = parsed["amount"] as? String, let v = Double(s) { return v }
            return -1
        }()
        guard amount > 0 else {
            return ["ok": false, "error": "amount required (positive number)"]
        }

        let title = (parsed["title"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else {
            return ["ok": false, "error": "title required"]
        }

        // kind: "expense" (既定) / "income"
        let kind: TransactionKind = {
            if (parsed["kind"] as? String)?.lowercased() == "income" { return .income }
            return .expense
        }()

        // date: ISO8601 / epoch
        let date: Date = {
            if let iso = parsed["date"] as? String {
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let d = f.date(from: iso) { return d }
                f.formatOptions = [.withInternetDateTime]
                if let d = f.date(from: iso) { return d }
            }
            if let epoch = parsed["date"] as? Double { return Date(timeIntervalSince1970: epoch) }
            if let epoch = parsed["date"] as? Int    { return Date(timeIntervalSince1970: TimeInterval(epoch)) }
            return .now
        }()

        // 未来日付の拒否: AppIntent の意図は「実際に発生した支出/収入の記録」なので、
        // 現在時刻より未来の date はエラーで弾く。タイムゾーン差を考慮して 5 分の猶予あり。
        let nowWithBuffer = Date().addingTimeInterval(5 * 60)
        if date > nowWithBuffer {
            let isoNow = ISO8601DateFormatter().string(from: Date())
            let isoDate = ISO8601DateFormatter().string(from: date)
            return [
                "ok": false,
                "error": "future date not allowed. now=\(isoNow), requested=\(isoDate). Use a past or current date."
            ]
        }

        let sheetName = parsed["sheet"] as? String

        let pc = PersistenceController.shared
        let ctx = pc.container.viewContext

        // シート決定 (= 最古シート優先、同名衝突は warning)
        var nameCollisionCount: Int = 0
        let sheet: ExpenseSheet
        let sheetReq = NSFetchRequest<ExpenseSheet>(entityName: "ExpenseSheet")
        sheetReq.sortDescriptors = [NSSortDescriptor(keyPath: \ExpenseSheet.createdAt, ascending: true)]
        if let name = sheetName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            sheetReq.predicate = NSPredicate(format: "name == %@", name)
            let matches = (try? ctx.fetch(sheetReq)) ?? []
            if let first = matches.first {
                sheet = first
                if matches.count > 1 { nameCollisionCount = matches.count }
            } else {
                sheetReq.predicate = nil
                sheetReq.fetchLimit = 1
                guard let fallback = (try? ctx.fetch(sheetReq))?.first else {
                    return ["ok": false, "error": "no sheet found"]
                }
                sheet = fallback
            }
        } else {
            sheetReq.fetchLimit = 1
            guard let first = (try? ctx.fetch(sheetReq))?.first else {
                return ["ok": false, "error": "no sheet found"]
            }
            sheet = first
        }

        // カテゴリ決定 (= kind に応じて AI 提案 / 最初の同 kind カテゴリ)
        let allKindCats = ((sheet.categories as? Set<ExpenseCategory>) ?? [])
            .filter { $0.kind == kind }
            .sorted { $0.sortOrder < $1.sortOrder }
        var aiSuggested: ExpenseCategory? = nil
        if CategoryAISuggestor.isAvailable {
            let names = allKindCats.map { $0.displayName }
            if !names.isEmpty,
               let suggestedName = await CategoryAISuggestor.suggest(
                title: title,
                kind: kind,
                categories: names
               ) {
                aiSuggested = allKindCats.first(where: { $0.displayName == suggestedName })
            }
        }
        let firstCategory = aiSuggested ?? allKindCats.first

        // 永続化
        let expense = Expense(context: ctx)
        if let store = sheet.objectID.persistentStore {
            ctx.assign(expense, to: store)
        }
        expense.amount = NSDecimalNumber(value: amount)
        expense.currencyCode = sheet.resolvedDefaultCurrencyCode
        expense.kindRaw = kind.rawValue
        expense.date = date
        expense.title = title
        expense.note = ""
        expense.createdAt = .now
        expense.sheet = sheet
        expense.category = firstCategory

        let profile = UserProfileStore.shared
        if let rn = profile.userRecordName, !rn.isEmpty {
            expense.payerProfileID = rn
            expense.paidBy = profile.resolvedDisplayName
        }
        if let memberID = profile.selfMemberID {
            expense.payerMemberID = memberID
        }

        do {
            try ctx.save()
        } catch {
            return ["ok": false, "error": "save failed: \(error.localizedDescription)"]
        }

        var summary: [String: Any] = [
            "ok": true,
            "amount": amount,
            "title": title,
            "sheet": sheet.displayName,
            "kind": kind == .income ? "income" : "expense",
            "category": firstCategory?.name ?? ""
        ]
        if nameCollisionCount > 1 {
            summary["warning"] = "name_collision: \(nameCollisionCount) sheets named \"\(sheet.displayName)\". Using oldest by createdAt."
        }
        return summary
    }

    // MARK: - Get (支出 / 収入の取得)

    @MainActor
    static func get(parsed: [String: Any]) -> [String: Any] {
        let dateRange: (start: Date, end: Date) = {
            if let fromStr = parsed["from"] as? String,
               let toStr   = parsed["to"]   as? String,
               let from    = parseISO(fromStr),
               let to      = parseISO(toStr) {
                return (from, to)
            }
            let periodStr = (parsed["period"] as? String) ?? "thisMonth"
            let option = PeriodOption(rawValue: periodStr) ?? .thisMonth
            return option.dateRange()
        }()

        let ctx = PersistenceController.shared.container.viewContext
        let req = NSFetchRequest<Expense>(entityName: "Expense")
        var predicates: [NSPredicate] = [
            NSPredicate(format: "date >= %@ AND date <= %@",
                        dateRange.start as NSDate,
                        dateRange.end   as NSDate),
            NSPredicate(format: "sheet != nil")
        ]
        if let sheetName = (parsed["sheet"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !sheetName.isEmpty {
            predicates.append(NSPredicate(format: "sheet.name == %@", sheetName))
        }
        if let kindStr = (parsed["kind"] as? String)?.lowercased(),
           ["expense", "income"].contains(kindStr) {
            let raw = (kindStr == "income"
                       ? TransactionKind.income
                       : TransactionKind.expense).rawValue
            predicates.append(NSPredicate(format: "kindRaw == %@", raw))
        }
        req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        req.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: true)]

        let expenses = (try? ctx.fetch(req)) ?? []
        let payloadOut: [[String: Any]] = expenses.map { e in
            [
                "date": ISO8601DateFormatter().string(from: e.date ?? Date()),
                "title": e.displayTitle,
                "amount": NSDecimalNumber(decimal: e.amountDecimal).doubleValue,
                "currency": e.resolvedCurrencyCode,
                "kind": e.kind == .income ? "income" : "expense",
                "category": e.category?.name ?? "",
                "categoryColor": e.category?.colorHex ?? "",
                "sheet": e.sheet?.name ?? "",
                "paidBy": e.displayPaidBy,
                "note": e.note ?? ""
            ]
        }

        let periodLabel: String = {
            if parsed["from"] != nil && parsed["to"] != nil { return "カスタム期間" }
            let periodStr = (parsed["period"] as? String) ?? "thisMonth"
            return PeriodOption(rawValue: periodStr)?.label ?? "今月"
        }()

        return [
            "period": periodLabel,
            "from": ISO8601DateFormatter().string(from: dateRange.start),
            "to":   ISO8601DateFormatter().string(from: dateRange.end),
            "count": payloadOut.count,
            "expenses": payloadOut
        ]
    }

    // MARK: - Helpers

    static func parseJSON(_ s: String) -> [String: Any] {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return obj
    }

    static func encodeJSON(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: dict,
            options: [.sortedKeys]
        ) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func parseISO(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}
