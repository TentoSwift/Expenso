//
//  BudgetyMacApp.swift
//  Budgety For macOS
//
//  macOS 用エントリポイント。iOS / visionOS と同じ Core Data + CloudKit スタックを共有し、
//  WindowGroup でメインウィンドウを表示する。UI は visionOS 版と同じく
//  NavigationSplitView ベースの sidebar + detail。
//

import SwiftUI
import CoreData

@main
struct BudgetyMacApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup(id: "main") {
            BudgetyMacContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .frame(minWidth: 900, minHeight: 600)
                .task {
                    await UserProfileStore.shared.ensureUserRecordNameLoaded()
                    await UserProfileStore.shared.refreshAppleIDName()
                    let ctx = persistenceController.container.viewContext
                    UserProfileStore.shared.hydrateParticipantProfilesFromShares(in: ctx)
                }
        }
        .defaultSize(width: 1100, height: 750)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            BudgetyMacSettingsView()
                .frame(width: 500, height: 350)
        }
    }
}
