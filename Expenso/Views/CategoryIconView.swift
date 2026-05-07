//
//  CategoryIconView.swift
//  Expenso
//
//  カテゴリのアイコン表示の共通コンポーネント。
//  シート詳細 (`ExpenseRowView`) のスタイル: 単色グラデーション円 + 白アイコン。
//

import SwiftUI

struct CategoryIconView: View {
    let symbol: String
    let tint: Color
    /// `@ScaledMetric` で Dynamic Type に追従。
    /// 引数で渡した `size` をベースに、AX サイズでは比例して大きくなる。
    @ScaledMetric private var size: CGFloat

    init(symbol: String, tint: Color, size: CGFloat = 36) {
        self.symbol = symbol
        self.tint = tint
        self._size = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    init(category: ExpenseCategory, size: CGFloat = 36) {
        self.symbol = category.displaySymbol
        self.tint = category.tint
        self._size = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    /// `Expense.categoryTint` / `categorySymbol` (ParticipantProfile 解決対応版) を表示する。
    init(expense: Expense, size: CGFloat = 36) {
        self.symbol = expense.categorySymbol
        self.tint = expense.categoryTint
        self._size = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        ZStack {
            Circle().fill(tint.gradient)
            Image(systemName: symbol)
                .foregroundStyle(.white)
                .font(.system(size: size * 0.42, weight: .semibold))
        }
        .frame(width: size, height: size)
    }
}
