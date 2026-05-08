//
//  DismissConfirmDemoView.swift
//  Expenso
//
//  https://qiita.com/Ten_Swift/items/f7f2ca57aa3900969767 のサンプルを
//  そのまま再現したデバッグ用画面。
//  AddExpenseView の確認ダイアログ実装が動かない切り分けに使う。
//

import SwiftUI

struct DismissConfirmDemoView: View {
    @State private var isSheetPresented = false
    @State private var showConfirm = false
    @State private var requireConfirm = true

    var body: some View {
        Button("Show sheet") { isSheetPresented = true }
            .buttonStyle(.borderedProminent)
            .sheet(isPresented: $isSheetPresented) {
                DismissConfirmDemoSheet(
                    isSheetPresented: $isSheetPresented,
                    showConfirm: $showConfirm,
                    requireConfirm: $requireConfirm,
                    closeNow: { isSheetPresented = false }
                )
                .onAttemptToDismiss(
                    shouldAllowDismiss: { !requireConfirm },
                    onAttempt: {
                        showConfirm = true
                    }
                )
            }
    }
}

private struct DismissConfirmDemoSheet: View {
    @Binding var isSheetPresented: Bool
    @Binding var showConfirm: Bool
    @Binding var requireConfirm: Bool
    var closeNow: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Toggle("閉じる前に確認する", isOn: $requireConfirm)
                    .padding(.horizontal)
                Text(requireConfirm
                     ? "スワイプで閉じようとするとダイアログが表示されます。"
                     : "スワイプで確認なしで閉じられます。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("シート")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if requireConfirm { showConfirm = true } else { closeNow() }
                    } label: { Image(systemName: "xmark") }
                        .confirmationDialog("", isPresented: $showConfirm) {
                            Button("閉じる", role: .destructive) { isSheetPresented = false }
                            Button("キャンセル", role: .cancel) {}
                        } message: {
                            Text("本当に閉じますか?")
                        }
                }
            }
        }
    }
}
