//
//  UserProfileEditView.swift
//  Expenso
//

import SwiftUI
import CoreData

struct UserProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var profile = UserProfileStore.shared

    @State private var name: String = ""
    @State private var selectedColor: String = "#5B8DEF"
    @State private var selectedSymbol: String = "person.fill"
    @State private var customColor: Color = .blue
    @State private var didLoad: Bool = false

    private var previewColor: Color { Color(hex: selectedColor) ?? .blue }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(previewColor.gradient)
                                .frame(width: 64, height: 64)
                            Image(systemName: selectedSymbol)
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name.isEmpty ? "(名前未入力)" : name)
                                .font(.title3.bold())
                            Text("アカウント全体で使われるプロフィールです")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                Section("名前") {
                    TextField("自分", text: $name)
                }

                Section("カラー") {
                    paletteRow
                    ColorPicker("カスタムカラー", selection: $customColor, supportsOpacity: false)
                        .onChange(of: customColor) { _, newValue in
                            selectedColor = newValue.toHex() ?? selectedColor
                        }
                }

                Section("アイコン") {
                    iconGrid
                }
            }
            .navigationTitle("プロフィール")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                name = profile.displayName
                selectedColor = profile.colorHex
                selectedSymbol = profile.iconSymbol
                customColor = previewColor
            }
        }
    }

    private var paletteRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MemberDefaults.palette, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex) ?? .gray)
                        .frame(width: 32, height: 32)
                        .overlay {
                            if selectedColor == hex {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .onTapGesture {
                            selectedColor = hex
                            customColor = Color(hex: hex) ?? .gray
                        }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var iconGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(MemberDefaults.symbols, id: \.self) { sym in
                Button {
                    selectedSymbol = sym
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedSymbol == sym ? previewColor.opacity(0.22) : Color(.tertiarySystemBackground))
                            .frame(height: 44)
                        Image(systemName: sym)
                            .foregroundStyle(selectedSymbol == sym ? previewColor : .primary)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(selectedSymbol == sym ? previewColor : .clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func save() {
        profile.displayName = name.trimmingCharacters(in: .whitespaces)
        profile.colorHex    = selectedColor
        profile.iconSymbol  = selectedSymbol
        profile.applyToSelfMember(in: viewContext)
        Haptics.success()
        Task {
            await profile.saveToCloudKit()
        }
        dismiss()
    }
}

private extension Color {
    func toHex() -> String? {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let R = Int((r * 255).rounded())
        let G = Int((g * 255).rounded())
        let B = Int((b * 255).rounded())
        return String(format: "#%02X%02X%02X", R, G, B)
        #else
        return nil
        #endif
    }
}
