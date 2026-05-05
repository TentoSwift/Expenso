//
//  ExpenseCategory+Extensions.swift
//  Expenso
//

import Foundation
import CoreData
import SwiftUI

extension ExpenseCategory {
    var displayName: String { name?.isEmpty == false ? name! : "未分類" }
    var displayColorHex: String { colorHex ?? "#888888" }
    var displaySymbol: String { symbol?.isEmpty == false ? symbol! : "ellipsis.circle" }
    var tint: Color { Color(hex: displayColorHex) ?? .gray }
}
