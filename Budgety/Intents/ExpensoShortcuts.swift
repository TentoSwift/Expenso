//
//  ExpensoShortcuts.swift
//  Expenso
//
//  AppShortcutsProvider に登録すると、Shortcuts アプリ・Siri・Spotlight に
//  自動的に表示されるアプリショートカット。「Hey Siri、Expenso で支出を追加」
//  のようなフレーズで `AddExpenseIntent` を起動できる。
//

import AppIntents

struct ExpensoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "\(.applicationName) で支出を追加",
                "\(.applicationName) に記録",
                "Add an expense to \(.applicationName)"
            ],
            shortTitle: "支出を追加",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: GetExpensesIntent(),
            phrases: [
                "\(.applicationName) で支出を取得",
                "\(.applicationName) の支出を JSON で",
                "Get expenses from \(.applicationName)"
            ],
            shortTitle: "支出を取得",
            systemImageName: "square.and.arrow.up"
        )
        AppShortcut(
            intent: QuickAddExpenseIntent(),
            phrases: [
                "\(.applicationName) でクイック追加",
                "Quick add to \(.applicationName)"
            ],
            shortTitle: "クイック支出追加",
            systemImageName: "plus.bubble.fill"
        )
    }
}
