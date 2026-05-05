//
//  Member+Extensions.swift
//  Expenso
//

import Foundation
import CoreData
import SwiftUI

extension Member {
    var displayName: String { name?.isEmpty == false ? name! : "メンバー" }
    var displayColorHex: String { colorHex ?? "#5B8DEF" }
    var displaySymbol: String { symbol?.isEmpty == false ? symbol! : "person.fill" }
    var tint: Color { Color(hex: displayColorHex) ?? .blue }

    var initial: String {
        guard let first = displayName.first else { return "?" }
        return String(first)
    }
}
