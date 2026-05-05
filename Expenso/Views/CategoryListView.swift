//
//  CategoryListView.swift
//  Expenso
//

import SwiftUI
import CoreData

struct CategoryListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var record: ExpenseSheet

    @FetchRequest private var categories: FetchedResults<ExpenseCategory>

    @State private var editingCategory: ExpenseCategory?
    @State private var showingNew = false

    init(record: ExpenseSheet) {
        self.record = record
        _categories = FetchRequest<ExpenseCategory>(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \ExpenseCategory.sortOrder, ascending: true),
                NSSortDescriptor(keyPath: \ExpenseCategory.createdAt, ascending: true)
            ],
            predicate: NSPredicate(format: "sheet == %@", record),
            animation: .default
        )
    }

    private var expenseCategories: [ExpenseCategory] {
        categories.filter { $0.kind == .expense }
    }
    private var incomeCategories: [ExpenseCategory] {
        categories.filter { $0.kind == .income }
    }

    var body: some View {
        List {
            section(title: TransactionKind.expense.label, items: expenseCategories)
            section(title: TransactionKind.income.label, items: incomeCategories)
        }
        .navigationTitle("\(record.displayName) のカテゴリ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNew = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editingCategory) { cat in
            EditCategoryView(mode: .edit(category: cat))
        }
        .sheet(isPresented: $showingNew) {
            EditCategoryView(mode: .create(record: record))
        }
    }

    @ViewBuilder
    private func section(title: String, items: [ExpenseCategory]) -> some View {
        Section {
            ForEach(items, id: \.objectID) { cat in
                Button {
                    editingCategory = cat
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(cat.tint.opacity(0.18))
                                .frame(width: 36, height: 36)
                            Image(systemName: cat.displaySymbol)
                                .foregroundStyle(cat.tint)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cat.displayName)
                                .foregroundStyle(.primary)
                            if cat.isBuiltIn {
                                Text("デフォルト")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .swipeActions {
                    if !cat.isBuiltIn {
                        Button(role: .destructive) {
                            viewContext.delete(cat)
                            PersistenceController.shared.save()
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
            .onMove { source, destination in
                moveCategories(items: items, from: source, to: destination)
            }
        } header: {
            Text(title)
        }
    }

    private func moveCategories(items: [ExpenseCategory], from source: IndexSet, to destination: Int) {
        var reordered = items
        reordered.move(fromOffsets: source, toOffset: destination)
        let baseSort = items.map(\.sortOrder).min() ?? 0
        for (i, cat) in reordered.enumerated() {
            cat.sortOrder = Int32(i) + baseSort
        }
        PersistenceController.shared.save()
    }
}
