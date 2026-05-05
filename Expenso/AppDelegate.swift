//
//  AppDelegate.swift
//  Expenso
//

import UIKit
import CloudKit
import CoreData

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            accept(metadata: metadata)
        }
    }

    func windowScene(_ windowScene: UIWindowScene,
                     userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        accept(metadata: cloudKitShareMetadata)
    }

    private func accept(metadata: CKShare.Metadata) {
        let pc = PersistenceController.shared
        let container = pc.container

        guard let sharedStore = pc.sharedStore else {
            NotificationCenter.default.post(
                name: .expensoShareAcceptanceFailed,
                object: nil,
                userInfo: ["message": "共有ストアが準備できていません。アプリを再起動してください。"]
            )
            return
        }

        container.acceptShareInvitations(from: [metadata], into: sharedStore) { _, error in
            DispatchQueue.main.async {
                if let error {
                    NotificationCenter.default.post(
                        name: .expensoShareAcceptanceFailed,
                        object: nil,
                        userInfo: ["message": "共有の受諾に失敗しました: \(error.localizedDescription)"]
                    )
                } else {
                    // 受諾後は新シートに自分の ParticipantProfile を書き込み、共有相手に名前/画像を見せる
                    Task { @MainActor in
                        await UserProfileStore.shared.ensureUserRecordNameLoaded()
                        UserProfileStore.shared.propagateProfile(in: pc.container.viewContext)
                    }
                    NotificationCenter.default.post(
                        name: .expensoShareAccepted,
                        object: nil,
                        userInfo: [
                            "shareTitle": (metadata.share[CKShare.SystemFieldKey.title] as? String) ?? ""
                        ]
                    )
                }
            }
        }
    }
}

extension Notification.Name {
    static let expensoShareAccepted = Notification.Name("ExpensoShareAccepted")
    static let expensoShareAcceptanceFailed = Notification.Name("ExpensoShareAcceptanceFailed")
    static let expensoSaveFailed = Notification.Name("ExpensoSaveFailed")
    static let expensoStoreReset = Notification.Name("ExpensoStoreReset")
}
