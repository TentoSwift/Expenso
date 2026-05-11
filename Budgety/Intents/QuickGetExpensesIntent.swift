//
//  QuickGetExpensesIntent.swift
//  Budgety
//
//  MCP / Shortcuts CLI から非対話で支出取得するための単純化インテント。
//  単一の JSON 文字列パラメータを受け取り、内部でパースする。
//
//  入力例:
//    {"period": "thisMonth"}
//    {"period": "allTime", "sheet": "家計簿"}
//    {"period": "thisYear", "kind": "income"}
//    {"from": "2026-04-01T00:00:00+09:00", "to": "2026-04-30T23:59:59+09:00"}
//
//  返り値: JSON 文字列 (period, from, to, count, expenses 配列)
//

import AppIntents
import CoreData
import Foundation

struct QuickGetExpensesIntent: AppIntent {
    static let title: LocalizedStringResource = "クイック支出取得"
    static let description = IntentDescription(
        "JSON 形式で支出/収入を取得します。MCP / 自動化からの呼び出し向け。"
    )
    static let openAppWhenRun: Bool = false

    @Parameter(title: "入力 (JSON)",
               description: "period などのフィルタを含む JSON。例: {\"period\":\"thisMonth\"}")
    var payload: String

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$payload) で支出取得")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let input = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed: [String: Any] = {
            guard let data = input.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return [:] }
            return obj
        }()

        // 期間決定: from/to 明示指定が最優先、次に period
        let dateRange: (start: Date, end: Date) = {
            if let fromStr = parsed["from"] as? String,
               let toStr   = parsed["to"]   as? String,
               let from    = Self.parseISO(fromStr),
               let to      = Self.parseISO(toStr) {
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
            NSPredicate(format: "sheet != nil")  // 孤児支出を除外
        ]

        // sheet 名フィルタ (任意)
        if let sheetName = (parsed["sheet"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !sheetName.isEmpty {
            predicates.append(NSPredicate(format: "sheet.name == %@", sheetName))
        }

        // kind フィルタ: "expense" / "income" (任意)
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

        let summary: [String: Any] = [
            "period": periodLabel,
            "from": ISO8601DateFormatter().string(from: dateRange.start),
            "to":   ISO8601DateFormatter().string(from: dateRange.end),
            "count": payloadOut.count,
            "expenses": payloadOut
        ]
        let data = try JSONSerialization.data(
            withJSONObject: summary,
            options: [.sortedKeys]
        )
        return .result(value: String(data: data, encoding: .utf8) ?? "{}")
    }

    /// ISO8601 (with or without fractional seconds) を Date に変換。
    private static func parseISO(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}
