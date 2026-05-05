//
//  ReceiptScanner.swift
//  Expenso
//
//  VisionKit `DataScannerViewController` のラッパー (iOS 16+)。
//  認識したテキスト行を `ReceiptParser` に渡してパース。
//

import SwiftUI
import VisionKit
import Vision
import UIKit
import PhotosUI

// MARK: - Live camera scanner (DataScannerViewController)

/// `VNDocumentCameraViewController` のラッパー。
/// 書類のフチを自動検出し、安定したフレームで自動シャッターを切るシステムスキャナ。
/// (Notes アプリの「書類をスキャン」と同じ UI)
struct ReceiptCameraScanner: UIViewControllerRepresentable {
    let onComplete: (ReceiptParseResult) -> Void
    let onCancel: () -> Void

    static var isAvailable: Bool {
        VNDocumentCameraViewController.isSupported
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onComplete: (ReceiptParseResult) -> Void
        let onCancel: () -> Void

        init(onComplete: @escaping (ReceiptParseResult) -> Void, onCancel: @escaping () -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            // 1 ページ目だけを使う (レシートは通常 1 枚)
            guard scan.pageCount > 0 else {
                onCancel()
                return
            }
            let image = scan.imageOfPage(at: 0)
            controller.dismiss(animated: true)

            guard let cgImage = image.cgImage else {
                onComplete(ReceiptParseResult())
                return
            }
            recognize(in: cgImage) { [onComplete] lines in
                Task {
                    let result = await ReceiptAIParser.parse(lines: lines)
                    await MainActor.run { onComplete(result) }
                }
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            #if DEBUG
            print("⚠️ VNDocumentCameraViewController failed: \(error)")
            #endif
            onCancel()
        }

        private func recognize(in cgImage: CGImage, completion: @escaping ([String]) -> Void) {
            let request = VNRecognizeTextRequest { req, _ in
                let lines = (req.results as? [VNRecognizedTextObservation])?.compactMap {
                    $0.topCandidates(1).first?.string
                } ?? []
                completion(lines)
            }
            request.recognitionLanguages = ["ja-JP", "en-US"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }
    }
}

/// AddExpenseView から `fullScreenCover` で表示するためのラッパー。
/// `VNDocumentCameraViewController` 自身が UI を持っているのでオーバーレイは重ねない。
struct ReceiptCameraScannerSheet: View {
    let onComplete: (ReceiptParseResult) -> Void
    let onCancel: () -> Void

    var body: some View {
        ReceiptCameraScanner(onComplete: onComplete, onCancel: onCancel)
            .ignoresSafeArea()
    }
}

// MARK: - Photo library scanner (PHPicker + VNRecognizeTextRequest)

/// 写真ライブラリから 1 枚選んでテキスト認識し、結果を返す。
struct ReceiptPhotoScanner: UIViewControllerRepresentable {
    let onComplete: (ReceiptParseResult) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onCancel: onCancel)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onComplete: (ReceiptParseResult) -> Void
        let onCancel: () -> Void

        init(onComplete: @escaping (ReceiptParseResult) -> Void, onCancel: @escaping () -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
                onCancel()
                return
            }
            provider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
                guard let self else { return }
                guard let img = obj as? UIImage, let cg = img.cgImage else {
                    DispatchQueue.main.async { self.onCancel() }
                    return
                }
                Self.recognize(in: cg) { lines in
                    Task {
                        let parsed = await ReceiptAIParser.parse(lines: lines)
                        await MainActor.run { self.onComplete(parsed) }
                    }
                }
            }
        }

        private static func recognize(in cgImage: CGImage, completion: @escaping ([String]) -> Void) {
            let request = VNRecognizeTextRequest { req, _ in
                let lines = (req.results as? [VNRecognizedTextObservation])?.compactMap {
                    $0.topCandidates(1).first?.string
                } ?? []
                completion(lines)
            }
            request.recognitionLanguages = ["ja-JP", "en-US"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }
    }
}
