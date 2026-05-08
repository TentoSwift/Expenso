//
//  TemplatePickerView.swift
//  Expenso
//
//  AddExpenseView で「テンプレから入力」を選んだ時に出るピッカー。
//  選択したテンプレを onSelect で渡し、呼び出し側がフォームに展開する。
//

import SwiftUI
import CoreData

struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let record: ExpenseSheet
    let onSelect: (ExpenseTemplate) -> Void

    @FetchRequest private var templates: FetchedResults<ExpenseTemplate>

    init(record: ExpenseSheet, onSelect: @escaping (ExpenseTemplate) -> Void) {
        self.record = record
        self.onSelect = onSelect
        self._templates = FetchRequest<ExpenseTemplate>(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \ExpenseTemplate.sortOrder, ascending: true),
                NSSortDescriptor(keyPath: \ExpenseTemplate.createdAt, ascending: true)
            ],
            predicate: NSPredicate(format: "sheet == %@", record),
            animation: .default
        )
    }

    private var expenseTemplates: [ExpenseTemplate] {
        templates.filter { $0.kind == .expense }
    }
    private var incomeTemplates: [ExpenseTemplate] {
        templates.filter { $0.kind == .income }
    }

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    ContentUnavailableView(
                        "テンプレートがありません",
                        systemImage: "doc.text",
                        description: Text("先に「現在の内容をテンプレに保存」または「定期項目」メニュー → テンプレート管理から追加してください。")
                    )
                } else {
                    List {
                        section(title: TransactionKind.expense.label, items: expenseTemplates)
                        section(title: TransactionKind.income.label, items: incomeTemplates)
                    }
                }
            }
            .navigationTitle("テンプレートから入力")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func section(title: String, items: [ExpenseTemplate]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { tpl in
                    Button {
                        onSelect(tpl)
                        dismiss()
                    } label: {
                        row(tpl)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ tpl: ExpenseTemplate) -> some View {
        let cat = tpl.resolvedCategory
        HStack(spacing: 12) {
            if let cat {
                CategoryIconView(category: cat, size: 36)
            } else {
                CategoryIconView(symbol: "doc.text", tint: .gray, size: 36)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(tpl.displayTitle).font(.body)
                let parts: [String] = [
                    cat?.displayName ?? (tpl.categoryRaw?.isEmpty == false ? tpl.categoryRaw! : "未分類"),
                    tpl.paidBy?.isEmpty == false ? tpl.paidBy! : ""
                ].filter { !$0.isEmpty }
                if !parts.isEmpty {
                    Text(parts.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if tpl.amountDecimal > 0 {
                Text(tpl.formattedAmount)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(tpl.kind == .income ? .green : .primary)
            }
        }
        .padding(.vertical, 2)
    }
}
