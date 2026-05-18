//
//  View+PlatformShims.swift
//  Budgety
//
//  iOS only API を macOS で no-op として通すための shim。
//  Mac で iOS の View 階層をそのまま使えるようにする。
//

import SwiftUI

#if os(macOS)
// macOS では navigationBarTitleDisplayMode は存在しない。
// 同名のダミーを生やして iOS のコードがコンパイルを通るようにする。
enum NavigationBarItem {
    enum TitleDisplayMode {
        case automatic, inline, large
    }
}

extension View {
    func navigationBarTitleDisplayMode(_ mode: NavigationBarItem.TitleDisplayMode) -> some View {
        self
    }
}

// keyboardType も macOS には無いので no-op。
enum UIKeyboardType {
    case `default`, asciiCapable, numbersAndPunctuation, URL, numberPad, phonePad,
         namePhonePad, emailAddress, decimalPad, twitter, webSearch, asciiCapableNumberPad
}

extension View {
    func keyboardType(_ type: UIKeyboardType) -> some View {
        self
    }

    func textInputAutocapitalization(_ a: Any?) -> some View {
        self
    }
}

// .navigationLink placement は macOS には無い → .primaryAction で代替する shim。
extension ToolbarItemPlacement {
    static var navigationLinkCompat: ToolbarItemPlacement { .primaryAction }
}
#endif
