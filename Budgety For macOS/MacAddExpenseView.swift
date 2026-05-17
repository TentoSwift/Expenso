//
//  MacAddExpenseView.swift
//  Budgety For macOS
//
//  macOS 用のシンプルな支出追加・編集フォーム。visionOS 版とほぼ同じだが
//  Mac 向けに toolbar / sheet サイズを調整。
//

import SwiftUI
import CoreData

struct MacAddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    let sheet: ExpenseSheet
    let expense: Expense?

    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var date: Date = .now
    @State private var kind: TransactionKind = .expense
    @State private var note: String = ""
    @State private var selectedCategory: ExpenseCategory?
    @State private var didLoad: Bool = false
    @State private var showingDeleteConfirm: Bool = false

    private var categories: [ExpenseCategory] {
        let set = (sheet.categories as? Set<ExpenseCategory>) ?? []
        return set
            .filter { $0.kind == kind }
            .sorted { ($0.sortOrder, $0.displayName) < ($1.sortOrder, $1.displayName) }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
        && Decimal(string: amountText.replacingOccurrences(of: ",", with: "")) != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("種別", selection: $kind) {
                        Text("支出").tag(TransactionKind.expense)
                        Text("収入").tag(TransactionKind.income)
                    }
                    .pickerStyle(.segmented)
                }
                Section("タイトル") {
                    TextField("コンビニ、ランチ など", text: $title)
                }
                Section("金額 (\(sheet.resolvedDefaultCurrencyCode))") {
                    TextField("0", text: $amountText)
                }
                Section("日付") {
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                }
                Section("カテゴリ") {
                    Picker("カテゴリ", selection: $selectedCategory) {
                        Text("未選択").tag(ExpenseCategory?.none)
                        ForEach(categories, id: \.objectID) { c in
                            Text(c.displayName).tag(Optional(c))
                        }
                    }
                }
                Section("メモ (任意)") {
                    TextField("詳細", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
                if expense != nil {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Label("この支出を削除", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("キャンセル") { dismiss() }
                Spacer()
                Button("保存") { save() }
                    .keyboardShortcut(.return)
                    .disabled(!canSave)
            }
            .padding()
        }
        .frame(width: 520, height: 620)
        .confirmationDialog(
            "この支出を削除しますか？",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) { deleteExpense() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("元に戻せません。")
        }
        .onAppear { loadIfNeeded() }
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        if let e = expense {
            title = e.displayTitle
            amountText = NSDecimalNumber(decimal: e.amountDecimal).stringValue
            date = e.date ?? .now
            kind = e.kind
            note = e.note ?? ""
            selectedCategory = e.category
        } else {
            selectedCategory = categories.first
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard let amount = Decimal(string: amountText.replacingOccurrences(of: ",", with: "")) else { return }

        let profile = UserProfileStore.shared
        let share = ShareCoordinator.shared.existingShare(for: sheet)
        let selfPID = profile.canonicalSelfID(forShare: share)

        let target: Expense
        if let existing = expense {
            target = existing
        } else {
            target = Expense(context: viewContext)
            if let store = sheet.objectID.persistentStore {
                viewContext.assign(target, to: store)
            }
            target.sheet = sheet
            target.createdAt = .now
            if let pid = selfPID { target.payerProfileID = pid }
            if let mid = profile.selfMemberID { target.payerMemberID = mid }
        }
        target.title = trimmed
        target.amount = NSDecimalNumber(decimal: amount)
        target.kindRaw = kind.rawValue
        target.currencyCode = sheet.resolvedDefaultCurrencyCode
        target.date = date
        target.note = note
        target.categoryRaw = selectedCategory?.name
        if let cat = selectedCategory,
           cat.objectID.persistentStore == sheet.objectID.persistentStore {
            target.category = cat
        } else {
            target.category = nil
        }
        PersistenceController.shared.save()
        dismiss()
    }

    private func deleteExpense() {
        guard let e = expense else { return }
        viewContext.delete(e)
        PersistenceController.shared.save()
        dismiss()
    }
}
