//
//  Currency.swift
//  Expenso
//

import Foundation

struct CurrencyOption: Identifiable, Hashable {
    let code: String
    let displayName: String
    let symbol: String

    var id: String { code }
}

enum CurrencyCatalog {
    /// アプリで選択可能な通貨。先頭は JPY。
    static let all: [CurrencyOption] = [
        .init(code: "JPY", displayName: "日本円",     symbol: "¥"),
        .init(code: "USD", displayName: "米ドル",     symbol: "$"),
        .init(code: "EUR", displayName: "ユーロ",     symbol: "€"),
        .init(code: "GBP", displayName: "英ポンド",   symbol: "£"),
        .init(code: "CHF", displayName: "スイスフラン", symbol: "CHF"),
        .init(code: "CNY", displayName: "人民元",     symbol: "¥"),
        .init(code: "KRW", displayName: "韓国ウォン",  symbol: "₩"),
        .init(code: "TWD", displayName: "台湾ドル",   symbol: "NT$"),
        .init(code: "HKD", displayName: "香港ドル",   symbol: "HK$"),
        .init(code: "SGD", displayName: "シンガポールドル", symbol: "S$"),
        .init(code: "AUD", displayName: "豪ドル",     symbol: "A$"),
        .init(code: "CAD", displayName: "加ドル",     symbol: "C$"),
        .init(code: "NZD", displayName: "NZドル",     symbol: "NZ$"),
        .init(code: "THB", displayName: "タイバーツ",  symbol: "฿"),
        .init(code: "VND", displayName: "ベトナムドン", symbol: "₫"),
        .init(code: "IDR", displayName: "インドネシアルピア", symbol: "Rp"),
        .init(code: "INR", displayName: "インドルピー", symbol: "₹"),
        .init(code: "PHP", displayName: "フィリピンペソ", symbol: "₱"),
        .init(code: "MXN", displayName: "メキシコペソ", symbol: "$"),
        .init(code: "BRL", displayName: "ブラジルレアル", symbol: "R$")
    ]

    /// ユーザーの地域から自動判定したデフォルト通貨コード。
    /// `Locale.current.currency?.identifier` が catalog 内にあれば採用、
    /// なければ JPY にフォールバック。
    static var defaultCode: String {
        let supported = Set(all.map(\.code))
        if let id = Locale.current.currency?.identifier, supported.contains(id) {
            return id
        }
        return "JPY"
    }

    static func option(for code: String) -> CurrencyOption {
        all.first { $0.code == code } ?? .init(code: code, displayName: code, symbol: code)
    }

    static func format(_ amount: Decimal, code: String) -> String {
        amount.formatted(.currency(code: code).locale(Locale.current))
    }

    static func formatPlain(_ amount: Decimal, code: String) -> String {
        let opt = option(for: code)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "ja_JP")
        let n = f.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
        return "\(opt.symbol)\(n)"
    }
}
