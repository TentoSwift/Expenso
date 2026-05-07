//
//  ShareSheet.swift
//  Expenso
//
//  UIActivityViewController を SwiftUI から使うための薄いラッパー。
//  CSV / PDF など Data や URL を共有 sheet で渡したい時に使う。
//

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// `.sheet(item:)` 経由で共有 sheet を出すためのラッパー (URL を Identifiable に)。
struct ExportShareItem: Identifiable {
    let id = UUID()
    let url: URL
    /// 表示用 (デバッグやログ用)
    let kind: ExportKind
}

enum ExportKind {
    case csv
    case pdf
}
