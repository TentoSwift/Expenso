//
//  ReceiptParser.swift
//  Expenso
//
//  OCR で取得したテキスト行群から (店名, 金額, 通貨, 日付) を推定する。
//  英日混在のレシートを対象。100% 正確である必要は無く、ユーザーが
//  AddExpenseView で確認・修正する前提のヒューリスティック。
//

import Foundation

struct ReceiptParseResult {
    var title: String?
    var amount: Decimal?
    var currencyCode: String?
    var date: Date?
}

enum ReceiptParser {
    /// 推定。
    /// - Parameter lines: OCR が出した行 (上から下、ノイズ含むあまり整っていない想定)
    static func parse(lines: [String]) -> ReceiptParseResult {
        var result = ReceiptParseResult()
        result.title = inferStoreName(from: lines)
        let (amount, currency) = inferAmount(from: lines)
        result.amount = amount
        result.currencyCode = currency
        result.date = inferDate(from: lines)
        return result
    }

    // MARK: - Store name

    /// 上から探して、数字主体でない・短すぎない・住所っぽくない最初の行を採用。
    private static func inferStoreName(from lines: [String]) -> String? {
        let addressKeywords = ["TEL", "Tel", "tel", "電話", "〒", "市", "区", "町", "丁目", "番地"]
        for raw in lines.prefix(8) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.count >= 2, line.count <= 40 else { continue }

            // 数字比率が高すぎる行は除外
            let digits = line.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }.count
            if Double(digits) / Double(line.count) > 0.4 { continue }

            // 住所っぽいキーワードを含む行は除外
            if addressKeywords.contains(where: { line.contains($0) }) { continue }

            // 「No.」「レシート」「receipt」だけの行は除外
            let lowered = line.lowercased()
            if ["receipt", "レシート", "領収書", "明細", "no."].contains(where: { lowered.contains($0) }) { continue }

            return line
        }
        return nil
    }

    // MARK: - Amount + currency

    /// 「合計 / total / 計 / お会計」キーワード付近の数値を最優先。無ければ最大の数値。
    /// 通貨記号 (¥, $, €, £) があれば currencyCode を併せて返す。
    private static func inferAmount(from lines: [String]) -> (Decimal?, String?) {
        let totalKeywords = ["合計", "総合計", "お会計", "計", "支払", "TOTAL", "Total", "total", "Subtotal"]

        // 1) キーワード付近を優先
        for line in lines {
            let lowered = line.lowercased()
            let hit = totalKeywords.contains { kw in
                line.contains(kw) || lowered.contains(kw.lowercased())
            }
            guard hit else { continue }
            if let (amount, currency) = extractAmount(in: line) {
                return (amount, currency)
            }
        }

        // 2) どのキーワードにも当たらなければ、レシート全体で最大の数値を採用
        var best: (Decimal, String?) = (0, nil)
        for line in lines {
            if let (amount, currency) = extractAmount(in: line), amount > best.0 {
                best = (amount, currency)
            }
        }
        return best.0 > 0 ? (best.0, best.1) : (nil, nil)
    }

    /// 行から最大の通貨額を抽出する。
    /// 例: "合計 ¥1,580", "Total: $24.50", "計 1500円"
    private static func extractAmount(in line: String) -> (Decimal, String?)? {
        // 通貨記号付きパターン (記号が前)
        let patterns: [(String, String)] = [
            (#"¥\s*([0-9][0-9,]*(?:\.[0-9]+)?)"#, "JPY"),
            (#"\$\s*([0-9][0-9,]*(?:\.[0-9]+)?)"#, "USD"),
            (#"€\s*([0-9][0-9,]*(?:\.[0-9]+)?)"#, "EUR"),
            (#"£\s*([0-9][0-9,]*(?:\.[0-9]+)?)"#, "GBP"),
            (#"₩\s*([0-9][0-9,]*(?:\.[0-9]+)?)"#, "KRW")
        ]
        for (pattern, code) in patterns {
            if let amount = firstAmount(matching: pattern, in: line) {
                return (amount, code)
            }
        }

        // 通貨記号無しの「数字 + 円」形式
        if let amount = firstAmount(matching: #"([0-9][0-9,]*)\s*円"#, in: line) {
            return (amount, "JPY")
        }

        // 通貨無し: 純粋な数値 (3 桁以上、カンマ区切りまたは小数点)
        if let amount = firstAmount(matching: #"\b([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]+)?|[0-9]{2,}(?:\.[0-9]{1,2})?)\b"#, in: line) {
            return (amount, nil)
        }
        return nil
    }

    private static func firstAmount(matching pattern: String, in text: String) -> Decimal? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else { return nil }
        let group = nsText.substring(with: match.range(at: 1))
        let cleaned = group.replacingOccurrences(of: ",", with: "")
        return Decimal(string: cleaned)
    }

    // MARK: - Date

    /// "2026/05/04", "2026-05-04", "2026年05月04日", "05/04" 等を Date に変換。
    private static func inferDate(from lines: [String]) -> Date? {
        let formatters: [(String, String)] = [
            ("yyyy/MM/dd", #"\b(\d{4}/\d{1,2}/\d{1,2})\b"#),
            ("yyyy-MM-dd", #"\b(\d{4}-\d{1,2}-\d{1,2})\b"#),
            ("yyyy.MM.dd", #"\b(\d{4}\.\d{1,2}\.\d{1,2})\b"#),
            ("yyyy年M月d日", #"(\d{4}年\d{1,2}月\d{1,2}日)"#)
        ]
        for line in lines {
            for (format, pattern) in formatters {
                if let raw = firstString(matching: pattern, in: line) {
                    let f = DateFormatter()
                    f.dateFormat = format
                    f.locale = Locale(identifier: "ja_JP")
                    if let date = f.date(from: raw) { return date }
                }
            }
        }
        return nil
    }

    private static func firstString(matching pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else { return nil }
        return nsText.substring(with: match.range(at: 1))
    }
}
