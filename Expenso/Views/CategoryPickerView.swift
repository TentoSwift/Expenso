//
//  CategoryPickerView.swift
//  Expenso
//

import SwiftUI
import CoreData

struct CategoryPickerView: View {
    @Binding var selected: ExpenseCategory?
    let record: ExpenseSheet
    let kind: TransactionKind
    @Environment(\.dismiss) private var dismiss

    @FetchRequest private var categories: FetchedResults<ExpenseCategory>

    @State private var showingNew = false

    init(selected: Binding<ExpenseCategory?>, record: ExpenseSheet, kind: TransactionKind = .expense) {
        self._selected = selected
        self.record = record
        self.kind = kind
        // kindRaw 未設定の旧カテゴリは支出扱いに含める
        let predicate: NSPredicate = {
            if kind == .expense {
                return NSPredicate(
                    format: "sheet == %@ AND (kindRaw == %@ OR kindRaw == nil OR kindRaw == '')",
                    record, kind.rawValue
                )
            } else {
                return NSPredicate(format: "sheet == %@ AND kindRaw == %@", record, kind.rawValue)
            }
        }()
        _categories = FetchRequest<ExpenseCategory>(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \ExpenseCategory.sortOrder, ascending: true),
                NSSortDescriptor(keyPath: \ExpenseCategory.createdAt, ascending: true)
            ],
            predicate: predicate,
            animation: .default
        )
    }

    var body: some View {
        List {
            ForEach(categories) { cat in
                Button {
                    selected = cat
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        CategoryIconView(category: cat, size: 36)
                        Text(cat.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selected?.objectID == cat.objectID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Section {
                Button {
                    showingNew = true
                } label: {
                    Label("新しいカテゴリを追加", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("カテゴリを選択")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingNew) {
            EditCategoryView(mode: .create(record: record), defaultKind: kind) { newCat in
                selected = newCat
                dismiss()
            }
        }
    }
}
