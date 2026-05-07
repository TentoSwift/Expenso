//
//  OnAttemptToDismiss.swift
//  Expenso
//
//  https://qiita.com/Ten_Swift/items/f7f2ca57aa3900969767 を踏襲。
//  シートを閉じようとする操作 (スワイプ / 背景タップ) を確実にフックするため、
//  コンテンツ全体を `UIHostingController` 派生クラスでラップしてシートの
//  ホストにし、`UIAdaptivePresentationControllerDelegate` を直接実装する。
//
//  `.background(UIViewControllerRepresentable)` 方式だと、自分が presentation
//  ホストにならないため delegate が SwiftUI の物に上書きされて取りこぼす。
//  Hosting controller 自身を「シートのホスト」に据えるとこの問題が起きない。
//

import SwiftUI
import UIKit

extension View {
    /// シートを閉じようとした瞬間 (スワイプ / 背景タップ / xmark など) をフックする。
    /// - shouldAllowDismiss: 自動で閉じて良いか
    /// - onAttempt: false の時にユーザが閉じようとした瞬間に呼ばれる
    func onAttemptToDismiss(
        shouldAllowDismiss: @escaping () -> Bool,
        onAttempt: @escaping () -> Void
    ) -> some View {
        DismissAwareContainer(
            shouldAllowDismiss: shouldAllowDismiss,
            onAttempt: onAttempt
        ) { self }
    }
}

private struct DismissAwareContainer<Content: View>: UIViewControllerRepresentable {
    let shouldAllowDismiss: () -> Bool
    let onAttempt: () -> Void
    let content: Content

    init(
        shouldAllowDismiss: @escaping () -> Bool,
        onAttempt: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.shouldAllowDismiss = shouldAllowDismiss
        self.onAttempt = onAttempt
        self.content = content()
    }

    func makeUIViewController(context: Context) -> DismissAwareHostingController<Content> {
        let hc = DismissAwareHostingController(rootView: content)
        hc.shouldAllowDismiss = shouldAllowDismiss
        hc.onAttempt = onAttempt
        return hc
    }

    func updateUIViewController(
        _ uiViewController: DismissAwareHostingController<Content>,
        context: Context
    ) {
        uiViewController.rootView = content
        uiViewController.shouldAllowDismiss = shouldAllowDismiss
        uiViewController.onAttempt = onAttempt
        uiViewController.reapplyGuards()
    }
}

private final class DismissAwareHostingController<Content: View>:
    UIHostingController<Content>,
    UIAdaptivePresentationControllerDelegate
{
    var shouldAllowDismiss: (() -> Bool)?
    var onAttempt: (() -> Void)?

    func reapplyGuards() {
        let allow = shouldAllowDismiss?() ?? true

        isModalInPresentation = !allow
        presentationController?.delegate = self

        if let parentVC = parent {
            parentVC.isModalInPresentation = !allow
            parentVC.presentationController?.delegate = self
        }
        if let nav = navigationController {
            nav.isModalInPresentation = !allow
            nav.presentationController?.delegate = self
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reapplyGuards()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reapplyGuards()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        reapplyGuards()
    }

    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        shouldAllowDismiss?() ?? true
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        onAttempt?()
    }
}
