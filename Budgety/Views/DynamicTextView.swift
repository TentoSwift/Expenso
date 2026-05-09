//
//  DynamicTextView.swift
//  Expenso
//
//  UITextView ベースで Dynamic Type に追従しながら自動行数調整するテキスト入力。
//  Enter キーで改行を入れずに `onSubmit` を発火し、フォーカスを外す挙動を持つ。
//

import SwiftUI
import UIKit

struct DynamicTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var focus: Bool
    var placeholder: String = ""
    var font: UIFont = .systemFont(ofSize: 17)
    /// Enter (改行) が入力された時に呼ばれる。フォーカスは内部で外される。
    var onSubmit: (() -> Void)? = nil

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator

        textView.isScrollEnabled = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.isUserInteractionEnabled = true

        textView.backgroundColor = .clear
        textView.textColor = .label
        textView.font = UIFontMetrics.default.scaledFont(for: font)
        textView.adjustsFontForContentSizeCategory = true

        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = .zero

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        // Dynamic Type / アクセシビリティサイズ変更への追従
        uiView.font = UIFontMetrics.default.scaledFont(for: font)

        // SwiftUI → UIKit のフォーカス制御
        if focus && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !focus && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextView,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width else { return nil }
        let size = uiView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: width, height: size.height)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: DynamicTextView

        init(_ parent: DynamicTextView) {
            self.parent = parent
        }

        // UIKit → SwiftUI のフォーカス同期
        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.focus = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.focus = false
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            if text == "\n" {
                // Enter が押された: 改行は入れずに submit を発火しフォーカスを外す
                textView.resignFirstResponder()
                parent.focus = false
                parent.onSubmit?()
                return false
            }
            return true
        }
    }
}

/// プレースホルダーを `.background` で重ねる便利ラッパー。
struct DynamicTextField: View {
    @Binding var text: String
    @Binding var focus: Bool
    var placeholder: String
    var font: UIFont = .systemFont(ofSize: 17)
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        DynamicTextView(
            text: $text,
            focus: $focus,
            placeholder: placeholder,
            font: font,
            onSubmit: onSubmit
        )
        .background(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(Color(uiColor: .placeholderText))
                    .allowsHitTesting(false)
            }
        }
    }
}
