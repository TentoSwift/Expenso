//
//  RecurringRule+Extensions.swift
//  Expenso
//

import Foundation
import CoreData

enum RecurrenceFrequency: String, CaseIterable, Identifiable {
    case daily, weekly, monthly, yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily:   "毎日"
        case .weekly:  "毎週"
        case .monthly: "毎月"
        case .yearly:  "毎年"
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .daily:   .day
        case .weekly:  .weekOfYear
        case .monthly: .month
        case .yearly:  .year
        }
    }

    /// 例: "毎月 1 ヶ月ごと" → "毎月", "毎月 3 ヶ月ごと" → "3 ヶ月ごと"
    func summary(interval: Int) -> String {
        let n = max(1, interval)
        if n == 1 { return label }
        switch self {
        case .daily:   return "\(n) 日ごと"
        case .weekly:  return "\(n) 週ごと"
        case .monthly: return "\(n) ヶ月ごと"
        case .yearly:  return "\(n) 年ごと"
        }
    }
}

extension RecurringRule {
    var resolvedFrequency: RecurrenceFrequency {
        RecurrenceFrequency(rawValue: frequency ?? "monthly") ?? .monthly
    }

    var resolvedInterval: Int {
        max(1, Int(interval))
    }

    var amountDecimal: Decimal {
        get { (amount ?? 0) as Decimal }
        set { amount = NSDecimalNumber(decimal: newValue) }
    }

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw ?? "") ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var resolvedCurrencyCode: String {
        if let c = currencyCode, !c.isEmpty { return c }
        return sheet?.resolvedDefaultCurrencyCode ?? CurrencyCatalog.defaultCode
    }

    var displayTitle: String { title ?? "" }

    var formattedAmount: String {
        CurrencyCatalog.format(amountDecimal, code: resolvedCurrencyCode)
    }

    /// 次回予定日を計算する。`lastGeneratedDate` があれば次の occurrence、無ければ `startDate`。
    var nextOccurrence: Date? {
        let cal = Calendar.current
        let component = resolvedFrequency.calendarComponent
        let n = resolvedInterval
        if let last = lastGeneratedDate {
            return cal.date(byAdding: component, value: n, to: last)
        }
        return startDate
    }
}
