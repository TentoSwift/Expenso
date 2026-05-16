//
//  ExpensoApp.swift
//  Expenso
//
//  Created by Tento Ishino on 2026/05/04.
//  Copyright © 2026 Tento Ishino. All rights reserved.
//

import SwiftUI
import CoreData

@main
struct ExpensoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared

    @Environment(\.scenePhase) private var scenePhase
    @State private var shareToast: String?
    @State private var premiumExpiredAlertShown: Bool = false
    /// 初回起動時のみオンボーディングを出す。UserDefaults 永続化。
    @AppStorage("hasShownOnboarding") private var hasShownOnboarding: Bool = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .sheet(isPresented: Binding(
                    get: { !hasShownOnboarding },
                    set: { if !$0 { hasShownOnboarding = true } }
                )) {
                    OnboardingView { hasShownOnboarding = true }
                        .interactiveDismissDisabled()
                }
                .overlay(alignment: .top) {
                    if let shareToast {
                        Text(shareToast)
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.thinMaterial, in: Capsule())
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .shadow(radius: 4)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .expensoShareAccepted)) { note in
                    let title = (note.userInfo?["shareTitle"] as? String) ?? "シート"
                    showToast("「\(title)」に参加しました")
                    // 共有相手にあなたが誰か分かるよう、プロフィール未設定なら設定 UI を出す
                }
                .onReceive(NotificationCenter.default.publisher(for: .expensoShareAcceptanceFailed)) { note in
                    let message = (note.userInfo?["message"] as? String) ?? "共有の受諾に失敗しました"
                    showToast(message)
                }
                .onReceive(NotificationCenter.default.publisher(for: .expensoPremiumExpired)) { _ in
                    premiumExpiredAlertShown = true
                }
                .alert("Premium が終了しました", isPresented: $premiumExpiredAlertShown) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("自分が作成した共有とシートロックを解除しました。")
                }
                .onReceive(NotificationCenter.default.publisher(for: .expensoSaveFailed)) { note in
                    let message = (note.userInfo?["message"] as? String) ?? "保存に失敗しました"
                    showToast(message)
                }
                .onReceive(NotificationCenter.default.publisher(for: .expensoStoreReset)) { note in
                    let message = (note.userInfo?["message"] as? String) ?? "データベースをリセットしました"
                    showToast(message)
                }
                .task {
                    await PurchaseManager.shared.refreshEntitlements()
                    #if DEBUG
                    if ProcessInfo.processInfo.environment["EXPENSO_DEBUG_REVOKE"] == "1" {
                        await PurchaseManager.runExpiryRevokeForDebug()
                    }
                    #endif
                    await FXRatesService.shared.refreshIfStale()
                    await UserProfileStore.shared.ensureUserRecordNameLoaded()
                    let ctx = persistenceController.container.viewContext
                    if BuildInfo.profileFeatureEnabled {
                        UserProfileStore.shared.hydrateFromParticipantProfile(in: ctx)
                        UserProfileStore.shared.propagateProfileToAllSheets(in: ctx)
                    }
                    // 過去の PP 逆引きで self Member.recordName に他人の ID が紛れた可能性を
                    // ケアするための one-shot 正規化 (= canonical 経由で再判定)。
                    UserProfileStore.shared.sanitizeSelfMemberRecordName(in: ctx)
                    // 共有シートで `payerProfileID == 自分の旧 userRecordName` になっている
                    // 行を canonical (email ベース等) に自動マイグレートする。
                    UserProfileStore.shared.migrateLegacyPayerProfileIDs(in: ctx)
                    // 定期項目の未生成 occurrence を Expense に展開
                    RecurringExpenseGenerator.generateAll(in: ctx)
                    // v0.x で UserDefaults に格納していたシートロック情報を Core Data 側へ移行
                    SheetLockManager.shared.migrateLegacyEntriesIfNeeded(context: ctx)
                }
                // CloudKit が新しいデータを取り込んだら ParticipantProfile から再 hydrate。
                // 通知は viewContext へのマージ完了より早く飛ぶことがあるため、
                // 200ms ほど待ってから fetch して取りこぼしを防ぐ。
                .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        let ctx = persistenceController.container.viewContext
                        if (UserProfileStore.shared.userRecordName ?? "").isEmpty {
                            await UserProfileStore.shared.ensureUserRecordNameLoaded()
                        }
                        UserProfileStore.shared.hydrateFromParticipantProfile(in: ctx)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        Task { await PurchaseManager.shared.refreshEntitlements() }
                        let ctx = persistenceController.container.viewContext
                        RecurringExpenseGenerator.generateAll(in: ctx)
                        Task { @MainActor in
                            if (UserProfileStore.shared.userRecordName ?? "").isEmpty {
                                await UserProfileStore.shared.ensureUserRecordNameLoaded()
                            }
                            if BuildInfo.profileFeatureEnabled {
                                UserProfileStore.shared.hydrateFromParticipantProfile(in: ctx)
                                UserProfileStore.shared.propagateProfileToAllSheets(in: ctx)
                            }
                        }
                    case .background:
                        // バックグラウンドに移る前に次回の BGAppRefreshTask を予約。
                        // iOS は背景時にしか走らせないので、この瞬間がチャンス。
                        AppDelegate.scheduleAppRefresh()
                        // バックグラウンドに移ったらシートロックを全て再要求 (= 次回フォアグラウンドで再入力)
                        Task { @MainActor in
                            SheetLockManager.shared.lockAll()
                        }
                    default:
                        break
                    }
                }
        }
        // WWDC 2025 #238 で導入された AssistiveAccess Scene。
        // 端末が AA モード時はこちらが起動 (= ContentView ではなく簡易版が表示される)。
        AssistiveAccess {
            AssistiveAccessView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.locale, Locale(identifier: "ja_JP"))
        }
    }

    private func showToast(_ message: String) {
        withAnimation { shareToast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation { shareToast = nil }
        }
    }
}
