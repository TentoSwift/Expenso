//
//  ExpenseSheetEntity.swift
//  Expenso
//
//  AppIntents で「シート」を選ぶための AppEntity ラッパー。
//  Core Data の `ExpenseSheet` は直接 AppEntity 化できないので、
//  objectID の URI 表現を id とした struct でブリッジする。
//

import AppIntents
import CoreData

struct ExpenseSheetEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "シート")
    }
    static var defaultQuery = ExpenseSheetEntityQuery()

    /// `ExpenseSheet.objectID.uriRepresentation().absoluteString` を識別子として使う。
    var id: String
    var name: String
    var symbol: String
    var colorHex: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct ExpenseSheetEntityQuery: EntityQuery {
    /// Shortcuts 編集中の候補一覧 (= 「シート」をタップした時に出るもの)
    @MainActor
    func suggestedEntities() async throws -> [ExpenseSheetEntity] {
        let ctx = PersistenceController.shared.container.viewContext
        let req = NSFetchRequest<ExpenseSheet>(entityName: "ExpenseSheet")
        req.sortDescriptors = [
            NSSortDescriptor(keyPath: \ExpenseSheet.createdAt, ascending: false)
        ]
        let sheets = (try? ctx.fetch(req)) ?? []
        return sheets.map { ExpenseSheetEntity.from($0) }
    }

    /// 識別子の配列 → 実体配列。Shortcuts 起動時に保存済みの ID を解決する経路。
    @MainActor
    func entities(for identifiers: [String]) async throws -> [ExpenseSheetEntity] {
        let pc = PersistenceController.shared
        let ctx = pc.container.viewContext
        var result: [ExpenseSheetEntity] = []
        for idStr in identifiers {
            guard let url = URL(string: idStr),
                  let oid = pc.container.persistentStoreCoordinator
                    .managedObjectID(forURIRepresentation: url),
                  let sheet = try? ctx.existingObject(with: oid) as? ExpenseSheet
            else { continue }
            result.append(ExpenseSheetEntity.from(sheet))
        }
        return result
    }
}

extension ExpenseSheetEntity {
    @MainActor
    static func from(_ sheet: ExpenseSheet) -> ExpenseSheetEntity {
        ExpenseSheetEntity(
            id: sheet.objectID.uriRepresentation().absoluteString,
            name: sheet.displayName,
            symbol: sheet.displaySymbol,
            colorHex: sheet.displayColorHex
        )
    }
}
