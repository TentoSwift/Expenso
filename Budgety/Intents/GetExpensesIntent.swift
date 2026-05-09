//
//  GetExpensesIntent.swift
//  Expenso
//
//  Shortcuts / Siri / Spotlight 経由で支出データを取得するための AppIntent。
//  Claude (Mac / Web) と連携する時の典型的な使い方:
//  1. Shortcuts.app で「Budgety で支出を取得」を実行 → JSON が出力
//  2. その JSON を Claude にコピペ or Shortcuts で「クリップボードにコピー」
//  3. Claude に「この JSON を分析して」と頼む
//
//  もしくは Claude on Mac から直接:
//    osascript -e 'tell application "Shortcuts" to run shortcut named "Budgety で支出を取得"'
//

import Foundation
import AppIntents
import CoreData

struct GetExpensesIntent: AppIntent {
    static let title: LocalizedStringResource = "支出を取得"
    static let description = IntentDescription(
        "指定期間の支出 / 収入データを JSON 形式で返します。Claude などの AI に分析を依頼する用途を想定。"
    )

    @Parameter(title: "期間", description: "取得する期間",
               default: PeriodOption.thisMonth,
               requestValueDialog: IntentDialog("期間は?"))
    var period: PeriodOption

    @Parameter(title: "シート", description: "取得するシート (任意)")
    var sheet: ExpenseSheetEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$period) の \(\.$sheet) 支出を取得")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let ctx = PersistenceController.shared.container.viewContext
        let req = NSFetchRequest<Expense>(entityName: "Expense")

        let dateRange = period.dateRange()
        var predicates: [NSPredicate] = []
        predicates.append(NSPredicate(format: "date >= %@ AND date <= %@",
                                      dateRange.start as NSDate,
                                      dateRange.end as NSDate))
        // 孤児支出 (= シート紐付け切れ、CloudKit race の残留物) を除外
        predicates.append(NSPredicate(format: "sheet != nil"))
        if let sheetEntity = sheet {
            let sheetReq = NSFetchRequest<ExpenseSheet>(entityName: "ExpenseSheet")
            sheetReq.predicate = NSPredicate(format: "self == %@", sheetEntity.id)
            sheetReq.fetchLimit = 1
            if let s = (try? ctx.fetch(sheetReq))?.first {
                predicates.append(NSPredicate(format: "sheet == %@", s))
            }
        }
        req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        req.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: true)]

        let expenses = (try? ctx.fetch(req)) ?? []
        let payload = expenses.map { e -> [String: Any] in
            return [
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

        let summary: [String: Any] = [
            "period": period.label,
            "from": ISO8601DateFormatter().string(from: dateRange.start),
            "to": ISO8601DateFormatter().string(from: dateRange.end),
            "count": payload.count,
            "expenses": payload
        ]

        let data = try JSONSerialization.data(
            withJSONObject: summary,
            options: [.prettyPrinted, .sortedKeys]
        )
        let json = String(data: data, encoding: .utf8) ?? "{}"
        return .result(value: json)
    }
}

// MARK: - Period option

enum PeriodOption: String, AppEnum {
    case today
    case yesterday
    case thisWeek
    case thisMonth
    case lastMonth
    case thisYear
    case last30Days

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "期間")
    static let caseDisplayRepresentations: [PeriodOption: DisplayRepresentation] = [
        .today: "今日",
        .yesterday: "昨日",
        .thisWeek: "今週",
        .thisMonth: "今月",
        .lastMonth: "先月",
        .thisYear: "今年",
        .last30Days: "直近 30 日"
    ]

    var label: String {
        Self.caseDisplayRepresentations[self]?.title.key ?? rawValue
    }

    func dateRange() -> (start: Date, end: Date) {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .today:
            let s = cal.startOfDay(for: now)
            let e = cal.date(byAdding: .day, value: 1, to: s)!
            return (s, e)
        case .yesterday:
            let today = cal.startOfDay(for: now)
            let s = cal.date(byAdding: .day, value: -1, to: today)!
            return (s, today)
        case .thisWeek:
            let s = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (s, now)
        case .thisMonth:
            let s = cal.dateInterval(of: .month, for: now)?.start ?? now
            return (s, now)
        case .lastMonth:
            let thisMonthStart = cal.dateInterval(of: .month, for: now)?.start ?? now
            let s = cal.date(byAdding: .month, value: -1, to: thisMonthStart)!
            return (s, thisMonthStart)
        case .thisYear:
            let s = cal.dateInterval(of: .year, for: now)?.start ?? now
            return (s, now)
        case .last30Days:
            let s = cal.date(byAdding: .day, value: -30, to: now)!
            return (s, now)
        }
    }
}
