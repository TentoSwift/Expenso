//
//  ExpenseCategoryEntity.swift
//  Expenso
//
//  AppIntents で「カテゴリ」を選ぶための AppEntity ラッパー。
//  Core Data の `ExpenseCategory` を objectID URI で安定識別する。
//  Shortcuts 編集時にユーザーが任意で選べるようにし、未指定なら
//  FoundationModels で推測する経路に流す。
//

import AppIntents
import CoreData
import UIKit
import SwiftUI

struct ExpenseCategoryEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "カテゴリ")
    }
    static var defaultQuery = ExpenseCategoryEntityQuery()

    var id: String
    var name: String
    var sheetName: String
    var kindRaw: String
    var symbol: String
    var colorHex: String
    /// カテゴリの色付き SF Symbol を事前にラスタライズした PNG データ。
    /// `displayRepresentation` から毎回呼ばれるたびに描画するのを避けるため pre-render する。
    var iconData: Data?

    var displayRepresentation: DisplayRepresentation {
        let image: DisplayRepresentation.Image? = {
            if let data = iconData { return DisplayRepresentation.Image(data: data) }
            return DisplayRepresentation.Image(systemName: symbol)
        }()
        return DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(sheetName)",
            image: image
        )
    }
}

struct ExpenseCategoryEntityQuery: EntityQuery {
    @MainActor
    func suggestedEntities() async throws -> [ExpenseCategoryEntity] {
        let ctx = PersistenceController.shared.container.viewContext
        let req = NSFetchRequest<ExpenseCategory>(entityName: "ExpenseCategory")
        req.sortDescriptors = [
            NSSortDescriptor(keyPath: \ExpenseCategory.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \ExpenseCategory.createdAt, ascending: true)
        ]
        // 支出カテゴリのみを候補として表示 (= AddExpenseIntent は支出専用)
        req.predicate = NSPredicate(format: "kindRaw == %@ OR kindRaw == nil OR kindRaw == ''",
                                    TransactionKind.expense.rawValue)
        let cats = (try? ctx.fetch(req)) ?? []
        return cats.map { ExpenseCategoryEntity.from($0) }
    }

    @MainActor
    func entities(for identifiers: [String]) async throws -> [ExpenseCategoryEntity] {
        let pc = PersistenceController.shared
        let ctx = pc.container.viewContext
        var result: [ExpenseCategoryEntity] = []
        for idStr in identifiers {
            guard let url = URL(string: idStr),
                  let oid = pc.container.persistentStoreCoordinator
                    .managedObjectID(forURIRepresentation: url),
                  let cat = try? ctx.existingObject(with: oid) as? ExpenseCategory
            else { continue }
            result.append(ExpenseCategoryEntity.from(cat))
        }
        return result
    }
}

extension ExpenseCategoryEntity {
    @MainActor
    static func from(_ cat: ExpenseCategory) -> ExpenseCategoryEntity {
        let colorHex = cat.displayColorHex
        // 通常のカテゴリは subtitle を空 (= シート名は表示しない)
        return ExpenseCategoryEntity(
            id: cat.objectID.uriRepresentation().absoluteString,
            name: cat.displayName,
            sheetName: "",
            kindRaw: cat.kindRaw ?? TransactionKind.expense.rawValue,
            symbol: cat.displaySymbol,
            colorHex: colorHex,
            iconData: renderColoredSymbol(cat.displaySymbol, colorHex: colorHex)
        )
    }

    /// CategoryIconView と同じ見た目 (= カテゴリ色のグラデ円 + 白の SF Symbol) を
    /// PNG Data として返す。
    @MainActor
    static func renderColoredSymbol(_ name: String, colorHex: String) -> Data? {
        renderBadge(symbol: name, colorHex: colorHex)
    }

    /// AI 提案用: 「色付き円 + 白 symbol」のバッジ + その隣に apple.intelligence を
    /// 横並びで合成した PNG Data を返す。
    @MainActor
    static func renderAISuggestionSymbol(_ name: String, colorHex: String) -> Data? {
        let badgeSize: CGFloat = 96
        guard let badge = renderBadgeImage(symbol: name, colorHex: colorHex, size: badgeSize)
        else { return renderColoredSymbol(name, colorHex: colorHex) }

        let aiCfg = UIImage.SymbolConfiguration(pointSize: badgeSize * 0.72, weight: .semibold)
        guard let ai = UIImage(systemName: "apple.intelligence", withConfiguration: aiCfg)?
            .withTintColor(.systemPurple, renderingMode: .alwaysOriginal)
        else { return badge.pngData() }

        let gap: CGFloat = 12
        let canvasW = badge.size.width + gap + ai.size.width
        let canvasH = max(badge.size.height, ai.size.height)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasW, height: canvasH))
        return renderer.image { _ in
            badge.draw(at: CGPoint(x: 0, y: (canvasH - badge.size.height) / 2))
            ai.draw(at: CGPoint(x: badge.size.width + gap, y: (canvasH - ai.size.height) / 2))
        }.pngData()
    }

    /// 「色付き円 + 白 symbol」バッジを `UIImage` として描画。
    @MainActor
    private static func renderBadgeImage(symbol: String, colorHex: String, size: CGFloat = 96) -> UIImage? {
        let color = UIColor(Color(hex: colorHex) ?? .blue)
        let cfg = UIImage.SymbolConfiguration(pointSize: size * 0.45, weight: .semibold)
        guard let symbolImg = UIImage(systemName: symbol, withConfiguration: cfg)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        else { return nil }

        let canvas = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: canvas)
        return renderer.image { ctx in
            // SwiftUI の Color.gradient と同じ感覚で、上が明るく下が暗いグラデ円。
            let cg = ctx.cgContext
            cg.saveGState()
            cg.addEllipse(in: CGRect(origin: .zero, size: canvas))
            cg.clip()
            let lighter = color.adjustingBrightness(by: 0.10)
            let darker  = color.adjustingBrightness(by: -0.10)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: [lighter.cgColor, darker.cgColor] as CFArray,
                locations: [0.0, 1.0]
            ) {
                cg.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: canvas.width / 2, y: 0),
                    end:   CGPoint(x: canvas.width / 2, y: canvas.height),
                    options: []
                )
            } else {
                color.setFill()
                UIBezierPath(ovalIn: CGRect(origin: .zero, size: canvas)).fill()
            }
            cg.restoreGState()

            let p = CGPoint(
                x: (canvas.width  - symbolImg.size.width)  / 2,
                y: (canvas.height - symbolImg.size.height) / 2
            )
            symbolImg.draw(at: p)
        }
    }

    /// バッジ (= 色付き円 + 白 symbol) を PNG として返すラッパー。
    @MainActor
    private static func renderBadge(symbol: String, colorHex: String, size: CGFloat = 96) -> Data? {
        renderBadgeImage(symbol: symbol, colorHex: colorHex, size: size)?.pngData()
    }
}

private extension UIColor {
    /// HSB の brightness に `delta` を加算した新しい色を返す。
    /// `delta` は -1.0…1.0、ガード付き。
    func adjustingBrightness(by delta: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        let nb = max(0, min(1, b + delta))
        return UIColor(hue: h, saturation: s, brightness: nb, alpha: a)
    }
}
