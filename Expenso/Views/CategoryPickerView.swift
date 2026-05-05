//
//  CategoryPickerView.swift
//  Expenso
//

import SwiftUI
import CoreData

struct CategoryPickerView: View {
    @Binding var selected: ExpenseCategory?
    let record: ExpenseSheet
    @Environment(\.dismiss) private var dismiss

    @FetchRequest private var categories: FetchedResults<ExpenseCategory>

    @State private var showingNew = false

    init(selected: Binding<ExpenseCategory?>, record: ExpenseSheet) {
        self._selected = selected
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
            ForEach(categories) { cat in
                Button {
                    selected = cat
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(cat.tint.opacity(0.18))
                                .frame(width: 36, height: 36)
                            Image(systemName: cat.displaySymbol)
                                .foregroundStyle(cat.tint)
                        }
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
            EditCategoryView(mode: .create(record: record)) { newCat in
                selected = newCat
                dismiss()
            }
        }
    }
}
