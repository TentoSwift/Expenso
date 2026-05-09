//
//  EditTemplateView.swift
//  Expenso
//

import SwiftUI
import CoreData

struct EditTemplateView: View {
    enum Mode {
        case create(record: ExpenseSheet)
        case edit(template: ExpenseTemplate)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var profile = UserProfileStore.shared

    let mode: Mode

    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var kind: TransactionKind = .expense
    @State private var currencyCode: String = "JPY"
    @State private var selectedCategory: ExpenseCategory?
    @State private var selectedPayer: Member?
    @State private var note: String = ""
    @State private var didLoad: Bool = false
    @State private var showDeleteConfirm: Bool = false

    private var contextSheet: ExpenseSheet? {
        switch mode {
        case .create(let r): return r
        case .edit(let t): return t.sheet
        }
    }

    /// Member に対応する per-sheet ParticipantProfile を引く。
    private func currentParticipantProfile(for member: Member) -> ParticipantProfile? {
        guard let rn = member.recordName, !rn.isEmpty,
              rn != "_defaultOwner_", rn != "__defaultOwner__",
              let sheet = contextSheet,
              let profiles = sheet.participantProfiles as? Set<ParticipantProfile> else { return nil }
        return profiles.first(where: { $0.recordName == rn })
    }

    private var amountDecimal: Decimal? {
        guard !amountText.isEmpty else { return nil }
        return Decimal(string: amountText)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var navTitle: String {
        switch mode {
        case .create: "テンプレを追加"
        case .edit:   "テンプレを編集"
        }
    }

    private var decimalKeypadNeeded: Bool {
        !["JPY", "KRW", "VND", "IDR"].contains(currencyCode)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("種別", selection: $kind) {
                        ForEach(TransactionKind.allCases) { k in
                            Label(k.label, systemImage: k.symbol).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { _, newKind in
                        if let cur = selectedCategory, cur.kind == newKind { return }
                        if let sheet = contextSheet {
                            let cats = (sheet.categories as? Set<ExpenseCategory>) ?? []
                            let filtered = cats.filter { c in
                                let raw = c.kindRaw ?? ""
                                return raw == newKind.rawValue || (newKind == .expense && raw.isEmpty)
                            }
                            selectedCategory = filtered.sorted { $0.sortOrder < $1.sortOrder }.first
                        }
                    }
                }

                Section("内容") {
                    TextField(kind == .expense ? "タイトル (例: コーヒー)" : "タイトル (例: 月給)", text: $title)
                    HStack(spacing: 6) {
                        Text(CurrencyCatalog.option(for: currencyCode).symbol)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 24, alignment: .leading)
                        TextField("0 (任意)", text: $amountText)
                            .keyboardType(decimalKeypadNeeded ? .decimalPad : .numberPad)
                            .monospacedDigit()
                            .onChange(of: amountText) { _, new in
                                let allowed = decimalKeypadNeeded
                                    ? new.filter { $0.isNumber || $0 == "." }
                                    : new.filter { $0.isNumber }
                                if allowed != new { amountText = allowed }
                            }
                    }
                    Picker("通貨", selection: $currencyCode) {
                        ForEach(CurrencyCatalog.all) { opt in
                            Text("\(opt.symbol)  \(opt.code) — \(opt.displayName)").tag(opt.code)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                if let sheet = contextSheet {
                    Section("カテゴリ") {
                        NavigationLink {
                            CategoryPickerView(selected: $selectedCategory, record: sheet, kind: kind)
                        } label: {
                            HStack {
                                Text("カテゴリ")
                                Spacer()
                                if let cat = selectedCategory {
                                    CategoryIconView(category: cat, size: 24)
                                    Text(cat.displayName).foregroundStyle(.secondary)
                                } else {
                                    Text("未選択").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Section(kind.partyLabel) {
                        NavigationLink {
                            MemberPickerView(selected: $selectedPayer, record: sheet, kind: kind)
                        } label: {
                            HStack {
                                Text(kind.partyLabel)
                                Spacer()
                                if let m = selectedPayer {
                                    if let pp = currentParticipantProfile(for: m) {
                                        ObservedParticipantProfileAvatar(profile: pp, size: 24)
                                        Text(pp.displayName?.isEmpty == false ? pp.displayName! : m.displayName)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        ObservedMemberAvatar(member: m, size: 24)
                                        Text(m.displayName).foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("未選択").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("メモ (任意)") {
                    TextField("詳細", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if case .edit(let tpl) = mode {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("削除", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                    } footer: {
                        Text("テンプレを削除しても、過去にテンプレから作った支出は残ります。")
                    }
                    .confirmationDialog("削除しますか?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                        Button("削除", role: .destructive) {
                            viewContext.delete(tpl)
                            PersistenceController.shared.save()
                            Haptics.warning()
                            dismiss()
                        }
                        Button("キャンセル", role: .cancel) {}
                    }
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.disabled(!canSave)
                }
            }
            .onAppear { loadIfNeeded() }
        }
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        switch mode {
        case .create(let record):
            currencyCode = record.resolvedDefaultCurrencyCode
            if selectedCategory == nil {
                let cats = (record.categories as? Set<ExpenseCategory>) ?? []
                let sorted = cats.sorted { $0.sortOrder < $1.sortOrder }
                selectedCategory = sorted.first(where: { $0.name == "食費" }) ?? sorted.first
            }
            if selectedPayer == nil, let id = profile.selfMemberID {
                let req = NSFetchRequest<Member>(entityName: "Member")
                req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                req.fetchLimit = 1
                selectedPayer = (try? viewContext.fetch(req))?.first
            }
        case .edit(let tpl):
            title = tpl.displayTitle == "(無題)" ? "" : tpl.displayTitle
            amountText = tpl.amountDecimal > 0
                ? NSDecimalNumber(decimal: tpl.amountDecimal).stringValue
                : ""
            kind = tpl.kind
            currencyCode = tpl.resolvedCurrencyCode
            selectedCategory = tpl.resolvedCategory
            note = tpl.note ?? ""
            if let mid = tpl.payerMemberID {
                let req = NSFetchRequest<Member>(entityName: "Member")
                req.predicate = NSPredicate(format: "id == %@", mid as CVarArg)
                req.fetchLimit = 1
                selectedPayer = (try? viewContext.fetch(req))?.first
            }
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        switch mode {
        case .create(let record):
            let tpl = ExpenseTemplate(context: viewContext)
            let sheetStore = record.objectID.persistentStore
            if let store = sheetStore { viewContext.assign(tpl, to: store) }
            tpl.id = UUID()
            tpl.createdAt = .now
            tpl.sortOrder = nextSortOrder(in: record)
            tpl.sheet = record
            apply(to: tpl, title: trimmed)
        case .edit(let tpl):
            apply(to: tpl, title: trimmed)
        }
        PersistenceController.shared.save()
        Haptics.success()
        dismiss()
    }

    private func apply(to tpl: ExpenseTemplate, title: String) {
        tpl.title = title
        if let amt = amountDecimal {
            tpl.amount = NSDecimalNumber(decimal: amt)
        } else {
            tpl.amount = 0
        }
        tpl.kindRaw = kind.rawValue
        tpl.currencyCode = currencyCode
        tpl.categoryRaw = selectedCategory?.name
        tpl.paidBy = selectedPayer?.name
        tpl.payerProfileID = selectedPayer?.profileID
        tpl.payerMemberID = selectedPayer?.id
        tpl.note = note
    }

    private func nextSortOrder(in sheet: ExpenseSheet) -> Int32 {
        let req = NSFetchRequest<ExpenseTemplate>(entityName: "ExpenseTemplate")
        req.predicate = NSPredicate(format: "sheet == %@", sheet)
        req.sortDescriptors = [NSSortDescriptor(keyPath: \ExpenseTemplate.sortOrder, ascending: false)]
        req.fetchLimit = 1
        if let last = (try? viewContext.fetch(req))?.first {
            return last.sortOrder + 1
        }
        return 0
    }
}
