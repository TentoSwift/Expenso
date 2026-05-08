//
//  TemplateListView.swift
//  Expenso
//

import SwiftUI
import CoreData

struct TemplateListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var record: ExpenseSheet

    @FetchRequest private var templates: FetchedResults<ExpenseTemplate>

    @State private var editingTemplate: ExpenseTemplate?
    @State private var showingNew: Bool = false

    init(record: ExpenseSheet) {
        self.record = record
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
        Group {
            if templates.isEmpty {
                ContentUnavailableView {
                    Label("テンプレがありません", systemImage: "doc.text")
                } description: {
                    Text("よく使う支出を保存しておけば、ワンタップで入力フォームに展開できます。\n支出追加画面の「テンプレに保存」からも作成できます。")
                } actions: {
                    Button {
                        showingNew = true
                    } label: {
                        Label("追加", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    section(title: TransactionKind.expense.label, items: expenseTemplates)
                    section(title: TransactionKind.income.label, items: incomeTemplates)
                }
            }
        }
        .navigationTitle("テンプレ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNew = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editingTemplate) { tpl in
            EditTemplateView(mode: .edit(template: tpl))
        }
        .sheet(isPresented: $showingNew) {
            EditTemplateView(mode: .create(record: record))
        }
    }

    @ViewBuilder
    private func section(title: String, items: [ExpenseTemplate]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { tpl in
                    Button {
                        editingTemplate = tpl
                    } label: {
                        TemplateRow(template: tpl, sheet: record)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    deleteTemplates(items: items, at: offsets)
                }
            }
        }
    }

    private func deleteTemplates(items: [ExpenseTemplate], at offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)
            PersistenceController.shared.save()
            Haptics.warning()
        }
    }
}

private struct TemplateRow: View {
    @ObservedObject var template: ExpenseTemplate
    let sheet: ExpenseSheet

    private var icon: some View {
        Group {
            if let cat = template.resolvedCategory {
                CategoryIconView(category: cat, size: 36)
            } else {
                CategoryIconView(symbol: "doc.text", tint: .gray, size: 36)
            }
        }
    }

    private var categoryName: String {
        template.resolvedCategory?.displayName
            ?? (template.categoryRaw?.isEmpty == false ? template.categoryRaw! : "未分類")
    }

    var body: some View {
        HStack(spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                Text(template.displayTitle).font(.body)
                Text(categoryName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(template.formattedAmount)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(template.kind == .income ? .green : .primary)
        }
        .padding(.vertical, 2)
    }
}
