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
    var size: CGFloat = 36

    init(symbol: String, tint: Color, size: CGFloat = 36) {
        self.symbol = symbol
        self.tint = tint
        self.size = size
    }

    init(category: ExpenseCategory, size: CGFloat = 36) {
        self.symbol = category.displaySymbol
        self.tint = category.tint
        self.size = size
    }

    /// `Expense.categoryTint` / `categorySymbol` (ParticipantProfile 解決対応版) を表示する。
    init(expense: Expense, size: CGFloat = 36) {
        self.symbol = expense.categorySymbol
        self.tint = expense.categoryTint
        self.size = size
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
