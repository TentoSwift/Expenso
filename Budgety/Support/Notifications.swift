//
//  Notifications.swift
//  Expenso
//
//  iOS / watchOS の両方から参照される Notification.Name を集約。
//  AppDelegate (= iOS 専用) や PersistenceController (= 共有) から
//  post / observe される。
//

import Foundation

extension Notification.Name {
    static let expensoShareAccepted = Notification.Name("ExpensoShareAccepted")
    static let expensoShareAcceptanceFailed = Notification.Name("ExpensoShareAcceptanceFailed")
    static let expensoSaveFailed = Notification.Name("ExpensoSaveFailed")
    static let expensoStoreReset = Notification.Name("ExpensoStoreReset")
}
