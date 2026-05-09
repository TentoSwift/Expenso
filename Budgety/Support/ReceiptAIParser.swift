//
//  ReceiptAIParser.swift
//  Expenso
//
//  Apple `FoundationModels` (iOS 26+) のオンデバイス LLM で、OCR テキストから
//  支出メタデータを構造化抽出する。利用できない場合は ReceiptParser (regex) に
//  フォールバックする。
//

import Foundation
import FoundationModels

/// LLM が返す構造化レシートデータ。`@Generable` を付けることで
/// FoundationModels がスキーマに沿った JSON を生成し型安全に受け取れる。
@Generable
struct ReceiptAIOutput {
    @Guide(description: "店舗 (お店) の名前。住所や電話番号ではなく屋号。不明なら空文字。")
    var storeName: String

    @Guide(description: "合計金額。通貨記号やカンマを含まない数字のみ。例: 1580 / 24.50。不明なら 0。")
    var totalAmount: Double

    @Guide(description: "通貨の ISO 4217 コード。例: JPY, USD, EUR, GBP, KRW。不明なら空文字。")
    var currencyCode: String

    @Guide(description: "レシートに記載された日付 (yyyy-MM-dd 形式)。複数あればレシート発行日。不明なら空文字。")
    var dateString: String
}

enum ReceiptAIParser {
    /// FoundationModels が現在の端末で利用可能か。
    /// (Apple Intelligence 対応端末 + iOS 26+ で true)
    static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    /// OCR テキスト行群を LLM に渡してパースし、ReceiptParseResult に変換する。
    /// - Parameter lines: OCR の生テキスト
    /// - Returns: 抽出結果。LLM 失敗時は ReceiptParser (regex) にフォールバック
    static func parse(lines: [String]) async -> ReceiptParseResult {
        guard isAvailable else {
            return ReceiptParser.parse(lines: lines)
        }

        let raw = lines.joined(separator: "\n")
        // 大量のノイズで context を圧迫しないよう適度に切り詰める
        let truncated = raw.count > 4000 ? String(raw.prefix(4000)) : raw

        let instructions = """
        あなたはレシートのテキストを解析するアシスタントです。
        与えられたレシートの OCR テキストから「店舗名」「合計金額」「通貨」「日付」を抽出します。
        合計は「合計」「総合計」「お会計」「TOTAL」などのキーワードを優先的に参照してください。
        不明な項目は空文字または 0 を返してください。
        """

        let prompt = """
        以下はレシートを OCR したテキストです。指定された形式で情報を抽出してください。

        ---
        \(truncated)
        ---
        """

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt, generating: ReceiptAIOutput.self)
            return convert(response.content, fallbackLines: lines)
        } catch {
            #if DEBUG
            print("⚠️ ReceiptAIParser: LLM failed, falling back to regex: \(error)")
            #endif
            return ReceiptParser.parse(lines: lines)
        }
    }

    private static func convert(_ ai: ReceiptAIOutput, fallbackLines: [String]) -> ReceiptParseResult {
        var result = ReceiptParseResult()

        let trimmedName = ai.storeName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            result.title = trimmedName
        }

        if ai.totalAmount > 0 {
            result.amount = Decimal(ai.totalAmount)
        }

        let trimmedCode = ai.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !trimmedCode.isEmpty, trimmedCode.count == 3 {
            result.currencyCode = trimmedCode
        }

        let dateStr = ai.dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !dateStr.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let d = formatter.date(from: dateStr) {
                result.date = d
            }
        }

        // LLM が漏らした項目があれば regex で補完
        if result.title == nil || result.amount == nil || result.currencyCode == nil || result.date == nil {
            let fallback = ReceiptParser.parse(lines: fallbackLines)
            result.title = result.title ?? fallback.title
            result.amount = result.amount ?? fallback.amount
            result.currencyCode = result.currencyCode ?? fallback.currencyCode
            result.date = result.date ?? fallback.date
        }
        return result
    }
}
