//
//  PurchaseManager.swift
//  Expenso
//

import Foundation
import StoreKit
import Combine

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    enum Plan: String, CaseIterable, Identifiable {
        case monthly = "com.tento.Expenso.premium.monthly"
        case yearly  = "com.tento.Expenso.premium.yearly"
        case lifetime = "com.tento.Expenso.premium.lifetime"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .monthly: "月額"
            case .yearly: "年額"
            case .lifetime: "買い切り"
            }
        }

        var subtitle: String {
            switch self {
            case .monthly: "毎月自動更新"
            case .yearly: "毎年自動更新 (2ヶ月分お得)"
            case .lifetime: "一度の支払いで永続"
            }
        }
    }

    static let premiumProductIDs: Set<String> = Set(Plan.allCases.map(\.rawValue))
    private static let isPremiumKey = "ExpensoIsPremium"
    /// Premium が切れた時に共有解除をリトライするためのフラグ。
    /// `revokeAllOwnedShares` が成功するまで立ち続ける。
    private static let sharesRevocationPendingKey = "ExpensoSharesRevocationPending"

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedIDs: Set<String> = []
    @Published var isProcessing: Bool = false
    @Published var lastError: String?

    private var updateListener: Task<Void, Never>?

    static var isPremiumCached: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["EXPENSO_PREMIUM"] == "1" { return true }
        #endif
        return UserDefaults.standard.bool(forKey: isPremiumKey)
    }

    var isPremium: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["EXPENSO_PREMIUM"] == "1" { return true }
        #endif
        return !purchasedIDs.intersection(Self.premiumProductIDs).isEmpty
    }

    var activePlan: Plan? {
        Plan.allCases.first { purchasedIDs.contains($0.rawValue) }
    }

    func product(for plan: Plan) -> Product? {
        products.first { $0.id == plan.rawValue }
    }

    init() {
        updateListener = Task { [weak self] in
            await self?.refreshEntitlements()
            await self?.listenForUpdates()
        }
    }

    deinit {
        updateListener?.cancel()
    }

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: Self.premiumProductIDs)
            self.products = loaded.sorted { lhs, rhs in
                let order: [String: Int] = [
                    Plan.lifetime.rawValue: 0,
                    Plan.yearly.rawValue: 1,
                    Plan.monthly.rawValue: 2
                ]
                return (order[lhs.id] ?? 99) < (order[rhs.id] ?? 99)
            }
        } catch {
            lastError = "商品の読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                    return true
                case .unverified:
                    lastError = "購入の検証に失敗しました。"
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                lastError = "購入処理が保留中です。承認後に反映されます。"
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = "購入できませんでした: \(error.localizedDescription)"
            return false
        }
    }

    func restore() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = "購入の復元に失敗しました: \(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        let wasPremium = UserDefaults.standard.bool(forKey: Self.isPremiumKey)

        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.revocationDate == nil {
                    ids.insert(transaction.productID)
                }
            }
        }
        purchasedIDs = ids
        let nowPremium = !ids.intersection(Self.premiumProductIDs).isEmpty
        UserDefaults.standard.set(nowPremium, forKey: Self.isPremiumKey)

        if wasPremium && !nowPremium {
            // 今回切れた → 解除フラグを立てて、その場で 1 回試す
            UserDefaults.standard.set(true, forKey: Self.sharesRevocationPendingKey)
            await handlePremiumExpired()
        } else if !nowPremium {
            // 非 Premium 状態で起動するたびに、自分が所有する CKShare の状態を実際に確認する。
            // `wasPremium` フラグの取りこぼしや UserDefaults キャッシュのズレに依存しないよう、
            // CKShare に他参加者または公開リンクが残っていたら必ず解除する。
            await ensureNoActiveSharesIfFree()
        }
    }

    /// 非 Premium のままになっている共有が CloudKit に残っていないかを実態ベースで確認し、
    /// 残っていれば revoke する。失敗したらフラグを残し次回起動でリトライ。
    private func ensureNoActiveSharesIfFree() async {
        let pendingFlag = UserDefaults.standard.bool(forKey: Self.sharesRevocationPendingKey)
        let hasActive = await ShareCoordinator.shared.hasActiveOwnedShares()
        guard pendingFlag || hasActive else { return }

        let success = await ShareCoordinator.shared.revokeAllOwnedShares()
        if success {
            UserDefaults.standard.removeObject(forKey: Self.sharesRevocationPendingKey)
            // ユーザーに何が起きたかを通知 (起動時の自動解除ケース)
            NotificationCenter.default.post(name: .expensoPremiumExpired, object: nil)
        } else {
            UserDefaults.standard.set(true, forKey: Self.sharesRevocationPendingKey)
        }
    }

    private func listenForUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                await refreshEntitlements()
            }
        }
    }

    private func handlePremiumExpired() async {
        let success = await ShareCoordinator.shared.revokeAllOwnedShares()
        if success {
            UserDefaults.standard.removeObject(forKey: Self.sharesRevocationPendingKey)
        }
        NotificationCenter.default.post(name: .expensoPremiumExpired, object: nil)
    }
}

extension Notification.Name {
    static let expensoPremiumExpired = Notification.Name("ExpensoPremiumExpired")
}
