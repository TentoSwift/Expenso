//
//  QuickAddExpenseIntent.swift
//  Expenso
//
//  MCP / Shortcuts CLI から非対話で支出追加するための単純化インテント。
//  単一の JSON 文字列パラメータを受け取り、内部でパースする。
//
//  入力例: {"amount": 350, "title": "スターバックス"}
//  シートは省略可 (= 一番古いシートに記録)。
//

import AppIntents
import CoreData
import Foundation

struct QuickAddExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "クイック支出追加"
    static let description = IntentDescription(
        "JSON 形式で支出を 1 件追加します (例: {\"amount\": 500, \"title\": \"ランチ\"})。MCP / 自動化からの呼び出し向け。"
    )
    static let openAppWhenRun: Bool = false

    @Parameter(title: "入力 (JSON)",
               description: "amount と title を含む JSON。例: {\"amount\":500,\"title\":\"ランチ\"}")
    var payload: String

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$payload) を追加")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let input = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = input.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .result(value: "Error: payload must be JSON like {\"amount\":500,\"title\":\"ランチ\"}")
        }

        // amount: number か string で受け取る
        let amount: Double
        if let v = parsed["amount"] as? Double { amount = v }
        else if let v = parsed["amount"] as? Int { amount = Double(v) }
        else if let s = parsed["amount"] as? String, let v = Double(s) { amount = v }
        else { return .result(value: "Error: amount required") }
        guard amount > 0 else { return .result(value: "Error: amount must be > 0") }

        let title = (parsed["title"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else { return .result(value: "Error: title required") }

        let sheetName = parsed["sheet"] as? String

        // date: ISO8601 文字列 (例: "2026-05-08T15:00:00Z") か秒単位の epoch number
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

        let pc = PersistenceController.shared
        let ctx = pc.container.viewContext

        // シート決定: name 指定 → 一致 / 無ければ一番古いシート
        let sheet: ExpenseSheet
        let sheetReq = NSFetchRequest<ExpenseSheet>(entityName: "ExpenseSheet")
        if let name = sheetName, !name.isEmpty {
            sheetReq.predicate = NSPredicate(format: "name == %@", name)
            sheetReq.fetchLimit = 1
            if let found = (try? ctx.fetch(sheetReq))?.first {
                sheet = found
            } else {
                sheetReq.predicate = nil
                sheetReq.sortDescriptors = [NSSortDescriptor(keyPath: \ExpenseSheet.createdAt, ascending: true)]
                guard let fallback = (try? ctx.fetch(sheetReq))?.first else {
                    return .result(value: "Error: no sheet found")
                }
                sheet = fallback
            }
        } else {
            sheetReq.sortDescriptors = [NSSortDescriptor(keyPath: \ExpenseSheet.createdAt, ascending: true)]
            sheetReq.fetchLimit = 1
            guard let first = (try? ctx.fetch(sheetReq))?.first else {
                return .result(value: "Error: no sheet found")
            }
            sheet = first
        }

        // カテゴリ決定: シートの最初の支出カテゴリ
        let categories = (sheet.categories as? Set<ExpenseCategory>) ?? []
        let firstExpenseCategory = categories
            .filter { $0.kind == .expense }
            .sorted { $0.sortOrder < $1.sortOrder }
            .first

        let expense = Expense(context: ctx)
        if let store = sheet.objectID.persistentStore {
            ctx.assign(expense, to: store)
        }
        expense.amount = NSDecimalNumber(value: amount)
        expense.currencyCode = sheet.resolvedDefaultCurrencyCode
        expense.kindRaw = TransactionKind.expense.rawValue
        expense.date = date
        expense.title = title
        expense.note = ""
        expense.createdAt = .now
        expense.sheet = sheet
        expense.category = firstExpenseCategory

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
            return .result(value: "Error: save failed - \(error.localizedDescription)")
        }

        let summary: [String: Any] = [
            "ok": true,
            "amount": amount,
            "title": title,
            "sheet": sheet.displayName,
            "category": firstExpenseCategory?.name ?? ""
        ]
        let outData = try JSONSerialization.data(
            withJSONObject: summary,
            options: [.sortedKeys]
        )
        return .result(value: String(data: outData, encoding: .utf8) ?? "OK")
    }
}
