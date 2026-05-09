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
    /// 引数で渡された原寸サイズ。スケール上限の計算に使う。
    private let baseSize: CGFloat
    /// `@ScaledMetric` で Dynamic Type に追従するが、`.body` だと AX5 で 3.5x
    /// まで伸びてアイコンが巨大化するので、`displaySize` で上限を掛ける。
    @ScaledMetric private var scaledSize: CGFloat

    /// 表示用サイズ。base の 1.5 倍で頭打ち。
    private var displaySize: CGFloat {
        min(scaledSize, baseSize * 1.5)
    }

    init(symbol: String, tint: Color, size: CGFloat = 36) {
        self.symbol = symbol
        self.tint = tint
        self.baseSize = size
        self._scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    init(category: ExpenseCategory, size: CGFloat = 36) {
        self.symbol = category.displaySymbol
        self.tint = category.tint
        self.baseSize = size
        self._scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    /// `Expense.categoryTint` / `categorySymbol` (ParticipantProfile 解決対応版) を表示する。
    init(expense: Expense, size: CGFloat = 36) {
        self.symbol = expense.categorySymbol
        self.tint = expense.categoryTint
        self.baseSize = size
        self._scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        ZStack {
            Circle().fill(tint.gradient)
            Image(systemName: symbol)
                .foregroundStyle(.white)
                .font(.system(size: displaySize * 0.42, weight: .semibold))
        }
        .frame(width: displaySize, height: displaySize)
    }
}
