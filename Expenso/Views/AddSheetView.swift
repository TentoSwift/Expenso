//
//  AddSheetView.swift
//  Expenso
//

import SwiftUI
import CoreData

struct AddSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var name: String = ""
    @State private var note: String = ""
    @State private var selectedColor: String = "#5B8DEF"
    @State private var defaultCurrencyCode: String = "JPY"

    private let palette: [String] = [
        "#5B8DEF", "#34C759", "#FF9500", "#FF3B30",
        "#AF52DE", "#FF2D55", "#5AC8FA", "#FFCC00"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("シート名") {
                    TextField("家族の家計、旅行など", text: $name)
                }

                Section("カラー") {
                    paletteRow
                }

                Section {
                    currencyPicker
                } header: {
                    Text("既定通貨")
                } footer: {
                    Text("このシートに支出を追加する時の初期通貨。各支出ごとに通貨を変更することもできます。")
                }

                Section("メモ (任意)") {
                    TextField("詳細", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("新しいシート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var currencyPicker: some View {
        Picker("通貨", selection: $defaultCurrencyCode) {
            ForEach(CurrencyCatalog.all) { opt in
                Text(opt.symbol + "  " + opt.code + " — " + opt.displayName).tag(opt.code)
            }
        }
        .pickerStyle(.navigationLink)
    }

    private var paletteRow: some View {
        HStack(spacing: 12) {
            ForEach(palette, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex) ?? .blue)
                    .frame(width: 32, height: 32)
                    .overlay {
                        if hex == selectedColor {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .onTapGesture { selectedColor = hex }
            }
        }
        .padding(.vertical, 4)
    }

    private func save() {
        let sheet = ExpenseSheet(context: viewContext)
        sheet.name = name.trimmingCharacters(in: .whitespaces)
        sheet.note = note
        sheet.colorHex = selectedColor
        sheet.defaultCurrencyCode = defaultCurrencyCode
        sheet.createdAt = .now
        PersistenceController.seedDefaultCategories(for: sheet, in: viewContext)
        PersistenceController.shared.save()
        Haptics.success()
        dismiss()
    }
}
