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

        // Premium が切れた検出時は通知だけ出して、既存の共有は触らない。
        // 自動 revoke は StoreKit の transient 失敗 (currentEntitlements が一時的に空) で
        // 本物の Premium ユーザーの共有を誤って消すリスクが大きい。
        // 新規共有作成は UI 側で `isPremium` ゲートしているので、課金が切れた状態で
        // 共有が増えることはない。
        if wasPremium && !nowPremium {
            NotificationCenter.default.post(name: .expensoPremiumExpired, object: nil)
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
}

extension Notification.Name {
    static let expensoPremiumExpired = Notification.Name("ExpensoPremiumExpired")
}
