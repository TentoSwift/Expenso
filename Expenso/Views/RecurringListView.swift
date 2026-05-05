//
//  RecurringListView.swift
//  Expenso
//

import SwiftUI
import CoreData

struct RecurringListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var record: ExpenseSheet

    @FetchRequest private var rules: FetchedResults<RecurringRule>

    @State private var editingRule: RecurringRule?
    @State private var showingNew = false

    init(record: ExpenseSheet) {
        self.record = record
        _rules = FetchRequest<RecurringRule>(
            sortDescriptors: [NSSortDescriptor(keyPath: \RecurringRule.createdAt, ascending: true)],
            predicate: NSPredicate(format: "sheet == %@", record),
            animation: .default
        )
    }

    var body: some View {
        Group {
            if rules.isEmpty {
                ContentUnavailableView {
                    Label("定期項目がありません", systemImage: "repeat")
                } description: {
                    Text("家賃・サブスク・給料など、毎月や毎週に繰り返される支出/収入を登録すると、自動でシートに追加されます。")
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
                    ForEach(rules) { rule in
                        Button {
                            editingRule = rule
                        } label: {
                            RecurringRow(rule: rule)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteRules)
                }
            }
        }
        .navigationTitle("定期項目")
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
        .sheet(item: $editingRule) { rule in
            EditRecurringRuleView(mode: .edit(rule: rule))
        }
        .sheet(isPresented: $showingNew) {
            EditRecurringRuleView(mode: .create(record: record))
        }
    }

    private func deleteRules(at offsets: IndexSet) {
        withAnimation {
            offsets.map { rules[$0] }.forEach(viewContext.delete)
            PersistenceController.shared.save()
            Haptics.warning()
        }
    }
}

private struct RecurringRow: View {
    @ObservedObject var rule: RecurringRule

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(rule.kind == .income ? Color.green.opacity(0.18) : Color.red.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: "repeat")
                    .foregroundStyle(rule.kind == .income ? .green : .red)
                    .font(.callout.weight(.semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.displayTitle.isEmpty ? "(無題)" : rule.displayTitle)
                    .font(.body)
                HStack(spacing: 6) {
                    Text(rule.resolvedFrequency.summary(interval: rule.resolvedInterval))
                    if let next = rule.nextOccurrence {
                        Text("· 次回 \(formatted(next))")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(rule.formattedAmount)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(rule.kind == .income ? .green : .primary)
        }
        .padding(.vertical, 2)
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日"
        return f.string(from: date)
    }
}
