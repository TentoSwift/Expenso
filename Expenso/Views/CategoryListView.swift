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

    var body: some View {
        List {
            Section {
                ForEach(categories) { cat in
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
                .onMove(perform: moveCategories)
            } footer: {
                Text("行を長押しすると並び替えできます。スワイプでカスタムカテゴリを削除できます。")
                    .font(.caption2)
            }
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

    private func moveCategories(from source: IndexSet, to destination: Int) {
        var items = Array(categories)
        items.move(fromOffsets: source, toOffset: destination)
        for (i, cat) in items.enumerated() {
            cat.sortOrder = Int32(i)
        }
        PersistenceController.shared.save()
    }
}
