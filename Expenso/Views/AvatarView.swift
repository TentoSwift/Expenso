//
//  AvatarView.swift
//  Expenso
//
//  プロフィール画像 (写真 or Memoji 合成 JPEG) を表示する共通コンポーネント。
//  画像が無ければ名前のイニシャル文字を彩色グラデ円で描画する。
//

import SwiftUI
import UIKit

struct AvatarView: View {
    let photoData: Data?
    let displayName: String
    let colorHex: String
    var size: CGFloat = 40

    private var initial: String {
        guard let first = displayName.first else { return "?" }
        return String(first).uppercased()
    }

    private var tint: Color { Color(hex: colorHex) ?? .blue }

    var body: some View {
        if let data = photoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 0.5))
        } else {
            ZStack {
                Circle().fill(tint.gradient)
                Text(initial)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
        }
    }
}

extension AvatarView {
    /// Member から生成するヘルパー (静的)。
    /// Member が後から更新された時に自動で再描画したい場合は `ObservedMemberAvatar` を使う。
    init(member: Member, size: CGFloat = 40) {
        self.init(
            photoData: member.photoData,
            displayName: member.displayName,
            colorHex: member.displayColorHex,
            size: size
        )
    }

    /// 名前 + 16 進カラー + 任意 photoData から生成するヘルパー (CKShare participant 用)。
    init(name: String, colorHex: String, photoData: Data? = nil, size: CGFloat = 40) {
        self.init(
            photoData: photoData,
            displayName: name,
            colorHex: colorHex,
            size: size
        )
    }
}

/// Member を `@ObservedObject` で監視し、プロフィール更新 (photoData / colorHex / name) に
/// 自動で追従するアバター。Member が無い (= shared store の Expense 等) ケースでは
/// 受け取った fallback で `AvatarView` を描く。
struct ObservedMemberAvatar: View {
    @ObservedObject var member: Member
    var size: CGFloat = 40

    var body: some View {
        AvatarView(member: member, size: size)
    }
}

/// 支払者アバター用ラッパー。Member が解決できればそれを観測、解決できなければ
/// 名前+色から `AvatarView` を構築する。Expense 行のような所で共通利用する。
struct PayerAvatar: View {
    let member: Member?
    let fallbackName: String
    let fallbackColorHex: String
    let fallbackPhoto: Data?
    var size: CGFloat = 40

    var body: some View {
        if let member {
            ObservedMemberAvatar(member: member, size: size)
        } else {
            AvatarView(name: fallbackName, colorHex: fallbackColorHex, photoData: fallbackPhoto, size: size)
        }
    }
}
