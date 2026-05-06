//
//  ShareStatusBadge.swift
//  Expenso
//

import SwiftUI
import CoreData
import CloudKit

/// シートの共有状態を `CKShare.currentUserParticipant.role` から判定して表示する。
/// - role == .owner で他に参加者あり → 「共有中」
/// - role が owner 以外 (= privateUser/publicUser など) → 「受信中」
/// - CKShare 自体が無い (まだ誰とも共有していない自分のシート) → バッジなし
struct ShareStatusBadge: View {
    @ObservedObject var record: ExpenseSheet

    private enum Status { case none, ownerSharing, participant }
    @State private var status: Status = .none

    /// `compact = true` だとアイコンのみ (リスト行など狭い場所向け)
    var compact: Bool = false

    var body: some View {
        Group {
            switch status {
            case .none:
                EmptyView()
            case .ownerSharing:
                badge(text: "共有中", systemImage: "person.2.fill", color: .green)
            case .participant:
                badge(text: "受信中", systemImage: "tray.and.arrow.down.fill", color: .blue)
            }
        }
        .task(id: record.objectID) {
            await refresh()
        }
        // CKShare の追加・参加者の更新は CloudKit 経由で remote change として降ってくる。
        // 参加者を追加してもバッジが更新されないのを防ぐためここでも refresh を呼ぶ。
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
            Task { await refresh() }
        }
    }

    @MainActor
    private func refresh() async {
        guard let share = ShareCoordinator.shared.existingShare(for: record) else {
            // CKShare が無い = 共有してもされてもいない自分のシート
            status = .none
            return
        }
        // CKShare.currentUserParticipant は、現在の iCloud アカウントの participant を直接返す
        // (CKContainer.userRecordID() を await で取らずに済む)
        guard let myRole = share.currentUserParticipant?.role else {
            status = .none
            return
        }
        if myRole == .owner {
            // 自分がオーナー: 参加済み (acceptanceStatus == .accepted) のメンバーがいる、
            // もしくは公開リンクが有効なら「共有中」。招待中だけの状態では表示しない。
            let hasAcceptedOthers = share.participants.contains(where: {
                $0.role != .owner && $0.acceptanceStatus == .accepted
            })
            let isPubliclyShared = share.publicPermission != .none
            status = (hasAcceptedOthers || isPubliclyShared) ? .ownerSharing : .none
        } else {
            // 自分は招待された側
            status = .participant
        }
    }

    @ViewBuilder
    private func badge(text: String, systemImage: String, color: Color) -> some View {
        if compact {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
                .padding(4)
                .background(Circle().fill(color.opacity(0.15)))
                .accessibilityLabel(text)
        } else {
            HStack(spacing: 3) {
                Image(systemName: systemImage)
                Text(text)
            }
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
        }
    }
}
