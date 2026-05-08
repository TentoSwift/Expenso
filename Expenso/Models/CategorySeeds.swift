//
//  CategorySeeds.swift
//  Expenso
//

import Foundation

struct CategorySeed {
    let name: String
    let colorHex: String
    let symbol: String
    var kind: TransactionKind = .expense
}

enum CategoryDefaults {
    /// 支出カテゴリ
    static let expenseSeeds: [CategorySeed] = [
        .init(name: "食費", colorHex: "#FF9500", symbol: "fork.knife"),
        .init(name: "交通", colorHex: "#5B8DEF", symbol: "car.fill"),
        .init(name: "住居", colorHex: "#A2845E", symbol: "house.fill"),
        .init(name: "光熱費", colorHex: "#FFCC00", symbol: "bolt.fill"),
        .init(name: "娯楽", colorHex: "#FF2D55", symbol: "gamecontroller.fill"),
        .init(name: "買い物", colorHex: "#AF52DE", symbol: "cart.fill"),
        .init(name: "医療", colorHex: "#FF3B30", symbol: "cross.case.fill"),
        .init(name: "教育", colorHex: "#5856D6", symbol: "book.fill"),
        .init(name: "旅行", colorHex: "#5AC8FA", symbol: "airplane"),
        .init(name: "その他", colorHex: "#8E8E93", symbol: "ellipsis.circle.fill")
    ]

    /// 収入カテゴリ
    static let incomeSeeds: [CategorySeed] = [
        .init(name: "給料", colorHex: "#34C759", symbol: "briefcase.fill", kind: .income),
        .init(name: "ボーナス", colorHex: "#30B0C7", symbol: "gift.fill", kind: .income),
        .init(name: "副業", colorHex: "#FF9500", symbol: "hammer.fill", kind: .income),
        .init(name: "投資", colorHex: "#5856D6", symbol: "chart.line.uptrend.xyaxis", kind: .income),
        .init(name: "その他収入", colorHex: "#8E8E93", symbol: "plus.circle.fill", kind: .income)
    ]

    /// 互換用 (旧コード参照)
    static let seeds: [CategorySeed] = expenseSeeds + incomeSeeds

    static let other = expenseSeeds.last!

    /// アイコンピッカーで選択可能な SF Symbol カタログ
    static let availableSymbols: [String] = [
        "fork.knife", "cup.and.saucer.fill", "wineglass.fill", "birthday.cake.fill", "carrot.fill",
        "car.fill", "bus.fill", "tram.fill", "airplane", "bicycle", "fuelpump.fill",
        "house.fill", "bed.double.fill", "lightbulb.fill", "drop.fill", "flame.fill", "bolt.fill",
        "cart.fill", "bag.fill", "tag.fill", "gift.fill", "creditcard.fill",
        "gamecontroller.fill", "tv.fill", "music.note", "film.fill", "headphones",
        "cross.case.fill", "pills.fill", "bandage.fill", "heart.fill",
        "book.fill", "graduationcap.fill", "pencil", "studentdesk",
        "dumbbell.fill", "figure.run", "tennis.racket", "soccerball",
        "pawprint.fill", "leaf.fill", "tshirt.fill", "scissors",
        "wrench.and.screwdriver.fill", "hammer.fill", "trash.fill",
        "yensign.circle.fill", "dollarsign.circle.fill", "creditcard.and.123",
        "phone.fill", "envelope.fill", "wifi", "globe",
        "person.fill", "person.2.fill", "figure.and.child.holdinghands",
        "ellipsis.circle.fill", "questionmark.circle.fill", "star.fill", "sparkles"
    ]

    /// カテゴリのカラーパレット (Hex)
    static let palette: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#5AC8FA", "#5B8DEF",
        "#5856D6", "#AF52DE", "#FF2D55", "#A2845E", "#8E8E93", "#000000"
    ]
}

enum MemberDefaults {
    /// メンバーアバターの背景色パレット (写真未設定時のフォールバック用)
    static let palette: [String] = CategoryDefaults.palette
}
