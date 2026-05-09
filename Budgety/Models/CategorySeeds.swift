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

    /// 無料ユーザーが選べる SF Symbol カタログ。シート初期 seed と日常用途を網羅。
    static let freeSymbols: [String] = [
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

    /// Premium ユーザーだけが選べる追加 SF Symbol。
    /// 無料カタログとの重複は無し。
    static let premiumSymbols: [String] = [
        // 食・飲み物の追加
        "takeoutbag.and.cup.and.straw.fill", "popcorn.fill", "fish.fill", "frying.pan.fill",
        "mug.fill", "cup.and.heat.waves.fill",
        // 移動・乗り物
        "tram.tunnel.fill", "ferry.fill", "sailboat.fill", "scooter", "fuelpump.arrowtriangle.left.fill",
        "parkingsign.circle.fill", "engine.combustion.fill",
        // 住居・公共
        "building.2.fill", "building.columns.fill", "lightswitch.on", "key.horizontal.fill",
        "shower.fill", "washer.fill", "refrigerator.fill", "spigot.fill",
        // 買い物・お金
        "basket.fill", "creditcard.viewfinder", "banknote.fill", "wallet.bifold.fill",
        "chart.line.uptrend.xyaxis", "chart.pie.fill", "percent",
        // 趣味・エンタメ
        "guitars.fill", "music.mic", "theatermasks.fill", "ticket.fill", "popcorn",
        "puzzlepiece.fill", "die.face.5.fill", "play.tv.fill",
        // 健康・スポーツ
        "stethoscope", "heart.text.clipboard.fill", "figure.yoga", "figure.surfing",
        "figure.basketball", "figure.american.football", "figure.skiing.downhill",
        "bicycle.circle.fill",
        // 学習・仕事
        "books.vertical.fill", "newspaper.fill", "doc.fill", "paperclip",
        "briefcase.fill", "case.fill", "laptopcomputer", "keyboard.fill",
        // ペット・自然
        "dog.fill", "cat.fill", "bird.fill", "ant.fill", "ladybug.fill",
        "tree.fill", "tortoise.fill", "snowflake",
        // ファッション・美容
        "shoe.fill", "sunglasses.fill", "comb.fill", "lipstick", "eyeglasses",
        // 工具・DIY・家事
        "screwdriver.fill", "paintbrush.fill", "wrench.fill", "level.fill",
        // コミュニケーション
        "message.fill", "video.fill", "bubble.left.and.bubble.right.fill",
        // 旅行・宿泊
        "suitcase.fill", "tent.fill", "map.fill", "binoculars.fill",
        // 子供・家族
        "stroller.fill", "teddybear.fill", "carseat.left.fill",
        // 季節・記念日
        "snowman.fill", "balloon.fill", "party.popper.fill", "calendar.badge.plus",
        // 其他
        "globe.asia.australia.fill", "moon.stars.fill", "umbrella.fill", "shield.lefthalf.filled"
    ]

    /// 全アイコン (= 無料 + Premium)。グリッド表示順は free 優先 + premium 後追加。
    static let allSymbols: [String] = freeSymbols + premiumSymbols

    /// アイコン文字列が Premium 限定かどうか。
    static func isPremiumSymbol(_ symbol: String) -> Bool {
        premiumSymbols.contains(symbol)
    }

    /// 旧名互換 (= まだ参照しているコード向け)。
    @available(*, deprecated, renamed: "freeSymbols")
    static var availableSymbols: [String] { freeSymbols }

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
