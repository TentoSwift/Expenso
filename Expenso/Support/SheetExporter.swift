//
//  SheetExporter.swift
//  Expenso
//
//  シート 1 つ分の Expense をエクスポートするサービス。
//  CSV (RFC 4180 風) と PDF (PDFKit) を提供。
//  どちらも Premium 機能なので、UI 側で `PurchaseManager.isPremium` を
//  ゲートしてから呼ぶ。
//

import Foundation
import CoreData
import PDFKit
import UIKit

enum SheetExporter {
    // MARK: - CSV

    /// シート配下の Expense を 1 行 1 件で CSV 化する。
    /// 列: date, kind, title, category, payer, amount, currency, note
    /// 改行・カンマ・ダブルクォートを含む値はクォートし、内部の `"` を `""` にエスケープ。
    static func makeCSV(for sheet: ExpenseSheet) -> Data {
        let header = ["date", "kind", "title", "category", "payer", "amount", "currency", "note"]
        var rows: [[String]] = [header]

        let expenses = ((sheet.expenses as? Set<Expense>) ?? [])
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"

        for e in expenses {
            rows.append([
                df.string(from: e.date ?? .now),
                e.kind == .income ? "income" : "expense",
                e.displayTitle,
                e.categoryDisplayName,
                e.displayPaidBy,
                NSDecimalNumber(decimal: e.amountDecimal).stringValue,
                e.resolvedCurrencyCode,
                e.note ?? ""
            ])
        }

        let csv = rows.map { line in
            line.map(escape).joined(separator: ",")
        }.joined(separator: "\r\n")
        // BOM を付けると Excel で UTF-8 が正しく開ける。
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(csv.data(using: .utf8) ?? Data())
        return data
    }

    private static func escape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }

    /// 一時ディレクトリに CSV を書いて URL を返す。共有シート用。
    static func writeCSV(for sheet: ExpenseSheet) -> URL? {
        let data = makeCSV(for: sheet)
        let dir = FileManager.default.temporaryDirectory
        let safe = sheet.displayName
            .components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|"))
            .joined()
        let url = dir.appendingPathComponent("Expenso-\(safe).csv")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            #if DEBUG
            print("⚠️ writeCSV: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - PDF

    /// シートの月別サマリレポート PDF を生成。
    /// - 1 ページ目: 表紙 (シート名 / 期間 / 総合計)
    /// - 以降: 月ごとに 支出/収入 合計 + カテゴリ別内訳
    static func writePDF(for sheet: ExpenseSheet) -> URL? {
        let dir = FileManager.default.temporaryDirectory
        let safe = sheet.displayName
            .components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|"))
            .joined()
        let url = dir.appendingPathComponent("Expenso-\(safe).pdf")

        // A4 (72dpi 換算)
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: UIGraphicsPDFRendererFormat())

        do {
            try renderer.writePDF(to: url) { ctx in
                drawPDF(into: ctx, sheet: sheet, pageRect: pageRect)
            }
            return url
        } catch {
            #if DEBUG
            print("⚠️ writePDF: \(error)")
            #endif
            return nil
        }
    }

    private static func drawPDF(
        into ctx: UIGraphicsPDFRendererContext,
        sheet: ExpenseSheet,
        pageRect: CGRect
    ) {
        let margin: CGFloat = 36
        let contentWidth = pageRect.width - margin * 2
        let code = sheet.resolvedDefaultCurrencyCode

        let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
        let h2Font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        let bodyFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        let subFont = UIFont.systemFont(ofSize: 11, weight: .regular)

        let expenses = ((sheet.expenses as? Set<Expense>) ?? [])
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }

        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP")
        df.dateFormat = "yyyy/MM/dd"

        // ===== Page 1: 表紙 =====
        ctx.beginPage()
        var y: CGFloat = margin

        let title = sheet.displayName as NSString
        title.draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: [.font: titleFont, .foregroundColor: UIColor.label]
        )
        y += titleFont.lineHeight + 8

        let subtitle = "Expenso レポート (\(df.string(from: .now)) 出力)" as NSString
        subtitle.draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: [.font: subFont, .foregroundColor: UIColor.secondaryLabel]
        )
        y += subFont.lineHeight + 24

        let totalExpense = expenses.filter { $0.kind == .expense }
            .reduce(Decimal(0)) { $0 + $1.amountDecimal }
        let totalIncome = expenses.filter { $0.kind == .income }
            .reduce(Decimal(0)) { $0 + $1.amountDecimal }
        let net = totalIncome - totalExpense

        for (label, value) in [
            ("支出合計", totalExpense),
            ("収入合計", totalIncome),
            ("差引",   net)
        ] {
            let line = "\(label):  \(CurrencyCatalog.format(value, code: code))" as NSString
            line.draw(
                at: CGPoint(x: margin, y: y),
                withAttributes: [.font: bodyFont, .foregroundColor: UIColor.label]
            )
            y += bodyFont.lineHeight + 6
        }

        // ===== Page 2+: 月別 =====
        let cal = Calendar.current
        let byMonth = Dictionary(grouping: expenses) { e -> DateComponents in
            let d = e.date ?? .now
            return cal.dateComponents([.year, .month], from: d)
        }
        let sortedKeys = byMonth.keys.sorted { (a, b) in
            (a.year ?? 0, a.month ?? 0) > (b.year ?? 0, b.month ?? 0)
        }

        let monthHeader = DateFormatter()
        monthHeader.locale = Locale(identifier: "ja_JP")
        monthHeader.dateFormat = "yyyy 年 M 月"

        for comps in sortedKeys {
            ctx.beginPage()
            var py: CGFloat = margin

            let monthDate = cal.date(from: comps) ?? .now
            let h = monthHeader.string(from: monthDate) as NSString
            h.draw(
                at: CGPoint(x: margin, y: py),
                withAttributes: [.font: h2Font, .foregroundColor: UIColor.label]
            )
            py += h2Font.lineHeight + 12

            let items = byMonth[comps] ?? []
            let mExp = items.filter { $0.kind == .expense }.reduce(Decimal(0)) { $0 + $1.amountDecimal }
            let mInc = items.filter { $0.kind == .income }.reduce(Decimal(0)) { $0 + $1.amountDecimal }

            let sum = "支出 \(CurrencyCatalog.format(mExp, code: code))    収入 \(CurrencyCatalog.format(mInc, code: code))" as NSString
            sum.draw(
                at: CGPoint(x: margin, y: py),
                withAttributes: [.font: bodyFont, .foregroundColor: UIColor.secondaryLabel]
            )
            py += bodyFont.lineHeight + 16

            // カテゴリ別内訳 (支出のみ、合計の降順)
            let byCategory = Dictionary(grouping: items.filter { $0.kind == .expense }) { $0.categoryDisplayName }
            let rows = byCategory.map { (name, items) -> (String, Decimal, Int) in
                let sum = items.reduce(Decimal(0)) { $0 + $1.amountDecimal }
                return (name, sum, items.count)
            }.sorted { $0.1 > $1.1 }

            ("カテゴリ別 (支出):" as NSString).draw(
                at: CGPoint(x: margin, y: py),
                withAttributes: [.font: bodyFont, .foregroundColor: UIColor.label]
            )
            py += bodyFont.lineHeight + 4

            for (name, total, count) in rows {
                guard py < pageRect.height - margin - bodyFont.lineHeight else { break }
                let line = "  \(name):  \(CurrencyCatalog.format(total, code: code))  (\(count) 件)" as NSString
                line.draw(
                    at: CGPoint(x: margin, y: py),
                    withAttributes: [.font: subFont, .foregroundColor: UIColor.label]
                )
                py += subFont.lineHeight + 2
            }

            // 横線で区切り
            UIColor.separator.setStroke()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: margin, y: py + 8))
            path.addLine(to: CGPoint(x: margin + contentWidth, y: py + 8))
            path.lineWidth = 0.5
            path.stroke()
        }
    }
}
