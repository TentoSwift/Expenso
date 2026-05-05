//
//  ExpenseSheet+Extensions.swift
//  Expenso
//

import Foundation
import CoreData
import SwiftUI

extension ExpenseSheet {
    var displayName: String { name ?? "" }
    var displayColorHex: String { colorHex ?? "#5B8DEF" }

    /// シートのアクセントカラー (UI 全体の差し色として使う)
    var tint: SwiftUI.Color {
        SwiftUI.Color(hex: displayColorHex) ?? .indigo
    }

    var resolvedDefaultCurrencyCode: String {
        if let c = defaultCurrencyCode, !c.isEmpty { return c }
        return CurrencyCatalog.defaultCode
    }

    /// このシートが Private ストアにあれば所有者、Shared ストアにあれば参加者。
    var isOwnedByCurrentUser: Bool {
        let pc = PersistenceController.shared
        guard let privateStore = pc.privateStore,
              let currentStore = objectID.persistentStore else {
            return true // 判定できなければ所有者扱い (新規作成時など)
        }
        return currentStore == privateStore
    }

    var sortedExpenses: [Expense] {
        let set = (expenses as? Set<Expense>) ?? []
        return set.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    // MARK: - 換算合計 (FX レートを使って既定通貨に統一)

    /// 全期間 + 全通貨を既定通貨に換算した合計 (支出, 収入)。
    /// レートが見つからない通貨は除外する。
    @MainActor
    func convertedTotals(_ filter: (Expense) -> Bool = { _ in true }) -> (expense: Decimal, income: Decimal, missing: Set<String>) {
        let target = resolvedDefaultCurrencyCode
        let fx = FXRatesService.shared
        var expenseSum: Decimal = 0
        var incomeSum: Decimal = 0
        var missing: Set<String> = []
        let set = (expenses as? Set<Expense>) ?? []
        for e in set where filter(e) {
            let from = e.resolvedCurrencyCode
            guard let converted = fx.convert(e.amountDecimal, from: from, to: target) else {
                missing.insert(from)
                continue
            }
            switch e.kind {
            case .expense: expenseSum += converted
            case .income:  incomeSum += converted
            }
        }
        return (expenseSum, incomeSum, missing)
    }

    @MainActor
    func convertedMonthlyTotals(month: Date = .now) -> (expense: Decimal, income: Decimal, missing: Set<String>) {
        let cal = Calendar.current
        return convertedTotals { e in
            cal.isDate(e.date ?? .distantPast, equalTo: month, toGranularity: .month)
        }
    }

}
