//
//  ShareParticipantDiagnostics.swift
//  Budgety
//
//  `com.apple.developer.icloud-extended-share-access` エンタイトルメントを追加した結果、
//  CKShare.Participant から何が取れるようになるかを実機ログで確認するための診断ヘルパ。
//  iOS 26 以降、デフォルトでは `userIdentity.nameComponents` などが nil になり、
//  本エンタイトルメントの有効化で復活すると推測される。
//
//  使い方: 共有シート表示時などに `ShareParticipantDiagnostics.log(share:)` を呼ぶ。
//  ログは os.log + print の両方に出力。
//

import Foundation
import CloudKit
import os.log

enum ShareParticipantDiagnostics {
    private static let log = Logger(subsystem: "com.tento.budgety", category: "ShareDiagnostics")

    /// 1 つの CKShare の全 participant について、取得可能な identity 情報をダンプする。
    /// Public DB 同期や URN 統一の前に、何が手に入るかを実機 / Console.app で確認する用途。
    static func dump(share: CKShare, context: String = "") {
        let header = "=== CKShare participant dump [\(context)] ==="
        log.notice("\(header, privacy: .public)")
        print(header)

        // owner
        dumpParticipant(share.owner, label: "owner")

        // currentUserParticipant (= 自分のエントリ)
        if let me = share.currentUserParticipant {
            dumpParticipant(me, label: "self (currentUserParticipant)")
        }

        // 全 participants
        for (idx, p) in share.participants.enumerated() {
            dumpParticipant(p, label: "participant[\(idx)]")
        }

        let footer = "=== end ==="
        log.notice("\(footer, privacy: .public)")
        print(footer)
    }

    private static func dumpParticipant(_ p: CKShare.Participant, label: String) {
        let identity = p.userIdentity
        let rn = identity.userRecordID?.recordName ?? "(nil)"

        // nameComponents が iOS 26 で取れなくなったやつ。Extended Share Access で復活想定。
        let nameComp = identity.nameComponents
        let formattedName: String = {
            guard let c = nameComp else { return "(nil)" }
            let fmt = PersonNameComponentsFormatter()
            fmt.style = .default
            return fmt.string(from: c)
        }()
        let givenName = nameComp?.givenName ?? "(nil)"
        let familyName = nameComp?.familyName ?? "(nil)"

        let lookupEmail = identity.lookupInfo?.emailAddress ?? "(nil)"
        let lookupPhone = identity.lookupInfo?.phoneNumber ?? "(nil)"
        let lookupRN = identity.lookupInfo?.userRecordID?.recordName ?? "(nil)"
        let hasICloud = identity.hasiCloudAccount

        let role: String = {
            switch p.role {
            case .owner: return "owner"
            case .privateUser: return "privateUser"
            case .publicUser: return "publicUser"
            case .administrator: return "administrator"
            case .unknown: return "unknown"
            @unknown default: return "unknown(@unknown)"
            }
        }()
        let permission: String = {
            switch p.permission {
            case .none: return "none"
            case .readOnly: return "readOnly"
            case .readWrite: return "readWrite"
            case .unknown: return "unknown"
            @unknown default: return "unknown(@unknown)"
            }
        }()
        let acceptance: String = {
            switch p.acceptanceStatus {
            case .pending: return "pending"
            case .accepted: return "accepted"
            case .removed: return "removed"
            case .unknown: return "unknown"
            @unknown default: return "unknown(@unknown)"
            }
        }()

        let lines: [String] = [
            "[\(label)] role=\(role) permission=\(permission) acceptance=\(acceptance)",
            "  userRecordID.recordName: \(rn)",
            "  hasiCloudAccount: \(hasICloud)",
            "  nameComponents: \(formattedName)  (given=\(givenName), family=\(familyName))",
            "  lookupInfo.email: \(lookupEmail)",
            "  lookupInfo.phone: \(lookupPhone)",
            "  lookupInfo.userRecordID: \(lookupRN)",
        ]
        for line in lines {
            log.notice("\(line, privacy: .public)")
            print(line)
        }
    }
}
