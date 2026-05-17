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
