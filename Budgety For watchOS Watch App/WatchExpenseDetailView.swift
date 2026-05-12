//
//  WatchExpenseDetailView.swift
//  Budgety Watch
//
//  支出 1 件の詳細 (= タイトル / 金額 / 日時 / カテゴリ) + 削除アクション。
//

import SwiftUI
import CoreData

struct WatchExpenseDetailView: View {
    @ObservedObject var expense: Expense
    let sheet: ExpenseSheet

    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                categoryBadge
                amountText
                metaRow
                if let note = expense.note, !note.isEmpty {
                    noteCard(note)
                }
                deleteButton
            }
            .padding(.horizontal, 6)
        }
        .containerBackground(sheet.tint.gradient, for: .navigation)
        .navigationTitle {
            Text("詳細")
                .foregroundStyle(sheet.tint)
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("削除しますか?", isPresented: $showDeleteConfirm) {
            Button("削除", role: .destructive) { delete() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この支出を削除します。元に戻せません。")
        }
    }

    @ViewBuilder
    private var categoryBadge: some View {
        if let cat = expense.category {
            HStack(spacing: 6) {
                Image(systemName: cat.symbol ?? "tag.fill")
                    .font(.caption.weight(.semibold))
                Text(cat.name ?? "")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(.white.opacity(0.20)))
        }
    }

    private var amountText: some View {
        Text(formatAmount(expense.amountDecimal))
            .font(.system(size: 38, weight: .heavy, design: .rounded).monospacedDigit())
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private var metaRow: some View {
        VStack(spacing: 4) {
            if let title = expense.title, !title.isEmpty {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            Text(formatDate(expense.date ?? Date()))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }

    private func noteCard(_ note: String) -> some View {
        Text(note)
            .font(.caption2)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.12))
            )
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Label("削除", systemImage: "trash")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.red.opacity(0.85))
                )
        }
        .buttonStyle(.plain)
    }

    private func delete() {
        ctx.delete(expense)
        try? ctx.save()
        WKInterfaceDevice.current().play(.success)
        dismiss()
    }

    private func formatAmount(_ d: Decimal) -> String {
        CurrencyCatalog.format(d, code: expense.resolvedCurrencyCode)
    }

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d (EEE) HH:mm"
        return f.string(from: d)
    }
}
