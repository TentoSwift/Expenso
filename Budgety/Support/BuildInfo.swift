//
//  BuildInfo.swift
//  Budgety
//
//  ビルドの種別判定。DEBUG / TestFlight (= sandbox receipt) / App Store の 3 段階。
//  デバッグ用 UI を「TestFlight でも見せたいが App Store ではオフにしたい」場合に使う。
//

import Foundation

enum BuildInfo {
    /// TestFlight ビルドか (= sandbox receipt が App Store ではなく TestFlight 経由を示す)。
    /// Debug ビルドは含まない。判定は `appStoreReceiptURL.path` に "sandboxReceipt" を含むか。
    static var isTestFlight: Bool {
        guard let url = Bundle.main.appStoreReceiptURL else { return false }
        return url.path.contains("sandboxReceipt")
    }

    /// 内部配布ビルドか (= DEBUG または TestFlight)。
    /// App Store 配信版 (= production) では false。
    static var isInternalBuild: Bool {
        #if DEBUG
        return true
        #else
        return isTestFlight
        #endif
    }
}
