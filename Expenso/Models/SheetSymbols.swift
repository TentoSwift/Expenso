//
//  SheetSymbols.swift
//  Expenso
//
//  シート (= グループ・予算) のアイコン選択肢。
//  カテゴリの SF Symbol とは別に、シートの性格に合うものをキュレーション。
//

import Foundation

enum SheetSymbols {
    static let options: [String] = [
        // 人・グループ系
        "person.2.fill",
        "person.3.fill",
        "person.crop.circle.fill",
        "heart.fill",
        // 家・建物
        "house.fill",
        "building.2.fill",
        "bed.double.fill",
        "fork.knife",
        // 旅行・移動
        "airplane",
        "car.fill",
        "tram.fill",
        "map.fill",
        // 仕事・勉強
        "briefcase.fill",
        "graduationcap.fill",
        "books.vertical.fill",
        "laptopcomputer",
        // ライフスタイル
        "cart.fill",
        "gift.fill",
        "gamecontroller.fill",
        "music.note",
        // お金
        "creditcard.fill",
        "yensign.circle.fill",
        "banknote.fill",
        "dollarsign.circle.fill",
        // その他
        "star.fill",
        "calendar",
        "tag.fill",
        "sparkles"
    ]
}
