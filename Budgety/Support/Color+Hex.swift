//
//  Color+Hex.swift
//  Expenso
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Cross-platform system color shims

extension Color {
    /// iOS の `Color(.systemBackground)` / macOS の `Color(.windowBackgroundColor)` の互換 wrapper。
    /// watchOS には system 色がほぼ無いので一律 `.black` フォールバック。
    static var platformSystemBackground: Color {
        #if os(watchOS)
        return .black
        #elseif canImport(UIKit)
        return Color(.systemBackground)
        #elseif canImport(AppKit)
        return Color(.windowBackgroundColor)
        #else
        return Color(white: 1)
        #endif
    }

    static var platformSecondarySystemBackground: Color {
        #if os(watchOS)
        return Color.gray.opacity(0.15)
        #elseif canImport(UIKit)
        return Color(.secondarySystemBackground)
        #elseif canImport(AppKit)
        return Color(.underPageBackgroundColor)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }

    static var platformSecondarySystemGroupedBackground: Color {
        #if os(watchOS)
        return Color.gray.opacity(0.15)
        #elseif canImport(UIKit)
        return Color(.secondarySystemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(.windowBackgroundColor)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }

    static var platformSystemGroupedBackground: Color {
        #if os(watchOS)
        return .black
        #elseif canImport(UIKit)
        return Color(.systemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(.windowBackgroundColor)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }

    static var platformTertiarySystemBackground: Color {
        #if os(watchOS)
        return Color.gray.opacity(0.2)
        #elseif canImport(UIKit)
        return Color(.tertiarySystemBackground)
        #elseif canImport(AppKit)
        return Color(.controlBackgroundColor)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }
}

extension Color {
    /// 文字列から決定的に色を生成。同じ文字列なら常に同じ色を返す。
    /// プロフィール写真未設定時のアバター背景色 (= 名前から自動) に使う。
    /// パレットは Material Design の比較的鮮やかな 14 色からハッシュで選ぶ。
    static func deterministic(from string: String) -> Color {
        let palette: [String] = [
            "#5B8DEF", "#34C759", "#FF9500", "#FF3B30",
            "#AF52DE", "#FF2D55", "#5AC8FA", "#FFCC00",
            "#FF6B6B", "#1DD1A1", "#7D3C98", "#54A0FF",
            "#E84393", "#27AE60"
        ]
        let key = string.trimmingCharacters(in: .whitespaces).isEmpty ? "?" : string
        let hash = abs(key.unicodeScalars.reduce(into: 0) { acc, s in
            acc = acc &* 31 &+ Int(s.value)
        })
        let hex = palette[hash % palette.count]
        return Color(hex: hex) ?? .blue
    }

    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt64(s, radix: 16) else { return nil }
        let r = Double((value & 0xFF0000) >> 16) / 255.0
        let g = Double((value & 0x00FF00) >> 8) / 255.0
        let b = Double(value & 0x0000FF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
