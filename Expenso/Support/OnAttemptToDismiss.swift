//
//  OnAttemptToDismiss.swift
//  Expenso
//
//  SwiftUI のシートで、ユーザーがスワイプダウンや背景タップで閉じようと
//  した瞬間を検知するための UIKit ブリッジ。
//
//  `.interactiveDismissDisabled(true)` だけだと「閉じる操作を無効化する」
//  しかできず、ユーザーの試みをフックできないので、
//  `UIAdaptivePresentationControllerDelegate` の
//  `presentationControllerShouldDismiss(_:)` に橋渡しして、
//  `shouldAllowDismiss` が false の時だけ `onAttempt` を呼び出す。
//

import SwiftUI
import UIKit

extension View {
    /// シートを閉じようとする操作 (スワイプダウン / 背景タップ) をフックする。
    /// `shouldAllowDismiss` が true の間は通常通り閉じる。
    /// false の時は閉じる操作をブロックして `onAttempt` を呼ぶ。
    func onAttemptToDismiss(
        shouldAllowDismiss: @escaping () -> Bool,
        onAttempt: @escaping () -> Void
    ) -> some View {
        background(
            AttemptToDismissView(
                shouldAllowDismiss: shouldAllowDismiss,
                onAttempt: onAttempt
            )
            .frame(width: 0, height: 0)
        )
    }
}

private struct AttemptToDismissView: UIViewControllerRepresentable {
    let shouldAllowDismiss: () -> Bool
    let onAttempt: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(host: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        vc.view.isUserInteractionEnabled = false
        // sheet の presentationController に届くタイミングは layout 後なので
        // 1 フレーム遅らせて delegate を差し込む。
        DispatchQueue.main.async { [weak vc] in
            attachDelegate(from: vc, to: context.coordinator)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.host = self
        // VC が再 attach されるなど delegate が外れる可能性があるので毎回付け直す。
        DispatchQueue.main.async { [weak uiViewController] in
            attachDelegate(from: uiViewController, to: context.coordinator)
        }
    }

    /// `vc` から親をたどって `presentingViewController != nil` の VC
    /// (= 実際にシートとして提示されているホスト) を見つけ、その
    /// presentationController.delegate に Coordinator を差し込む。
    /// 親がまだ繋がっていない場合は次の runloop で再試行する。
    private func attachDelegate(from vc: UIViewController?, to coordinator: Coordinator) {
        guard let vc else { return }
        if let host = sheetHost(from: vc) {
            host.presentationController?.delegate = coordinator
        } else {
            DispatchQueue.main.async { [weak vc] in
                guard let vc, let host = sheetHost(from: vc) else { return }
                host.presentationController?.delegate = coordinator
            }
        }
    }

    /// 親チェーンを上がって、`presentingViewController != nil` の VC を返す。
    private func sheetHost(from vc: UIViewController) -> UIViewController? {
        var current: UIViewController? = vc
        while let c = current {
            if c.presentingViewController != nil { return c }
            current = c.parent
        }
        return nil
    }

    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var host: AttemptToDismissView
        init(host: AttemptToDismissView) { self.host = host }

        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            if host.shouldAllowDismiss() { return true }
            host.onAttempt()
            return false
        }
    }
}
