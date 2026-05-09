//
//  DemoShowcase.swift
//  Expenso
//
//  プロモ用デモアニメーションの一覧 / プレイヤー / ビデオ書き出し UI。
//  個別バリアントは `DemoVariants.swift` に定義する。
//

import SwiftUI

struct DemoVariant: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let totalDuration: Double
    let exportSize: CGSize
    /// プレイヤー初期表示で使うテーマ色。
    let defaultTint: Color
    /// 時刻 t (0 ... totalDuration 秒) と tint カラーを入力に SwiftUI View を返す純関数。
    /// ライブプレビューと動画書き出しで同じ関数を共有する。
    let render: (Double, Color) -> AnyView
}

struct DemoShowcaseView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(DemoVariant.allVariants) { variant in
                NavigationLink {
                    DemoPlayerView(variant: variant)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: variant.symbol)
                            .font(.title2)
                            .frame(width: 36, height: 36)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(variant.title)
                                .fontWeight(.medium)
                            Text(variant.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(variant.totalDuration))s")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationTitle("デモアニメーション")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

struct DemoPlayerView: View {
    let variant: DemoVariant

    @State private var startDate = Date()
    @State private var isExporting: Bool = false
    @State private var exportProgress: Double = 0
    @State private var exportedURL: URL? = nil
    @State private var exportError: String? = nil
    @State private var tint: Color
    @State private var isFullscreen: Bool = false

    init(variant: DemoVariant) {
        self.variant = variant
        self._tint = State(initialValue: variant.defaultTint)
    }

    var body: some View {
        ZStack {
            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSince(startDate)
                    .truncatingRemainder(dividingBy: variant.totalDuration)
                GeometryReader { geo in
                    // export size (e.g. 1080×1920) のキャンバス上で描画して
                    // 表示領域に収まるよう一律縮小。書き出し時の見た目と一致する。
                    let scale = min(
                        geo.size.width / variant.exportSize.width,
                        geo.size.height / variant.exportSize.height
                    )
                    variant.render(elapsed, tint)
                        .environment(\.colorScheme, .light)
                        .frame(width: variant.exportSize.width,
                               height: variant.exportSize.height)
                        .scaleEffect(scale, anchor: .center)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                .clipped()
            }

            if isExporting {
                Color.black.opacity(0.55).ignoresSafeArea()
                VStack(spacing: 14) {
                    ProgressView(value: exportProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 220)
                        .tint(.white)
                    Text("\(Int(exportProgress * 100)) %")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                    Text("ビデオを書き出し中...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .navigationTitle(variant.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Text("テーマ色")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ColorPicker("", selection: $tint, supportsOpacity: false)
                    .labelsHidden()
                Spacer()
                Button {
                    tint = variant.defaultTint
                } label: {
                    Label("リセット", systemImage: "arrow.counterclockwise")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isFullscreen = true
                } label: {
                    Label("全画面", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .disabled(isExporting)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await runExport() }
                } label: {
                    Label("ビデオ保存", systemImage: "square.and.arrow.up")
                }
                .disabled(isExporting)
            }
        }
        .fullScreenCover(isPresented: $isFullscreen) {
            DemoFullscreenView(variant: variant, tint: tint)
        }
        .alert("書き出しエラー", isPresented: errorPresentation) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .sheet(item: exportedItem) { item in
            ShareSheet(items: [item.url])
        }
    }

    private var errorPresentation: Binding<Bool> {
        Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )
    }

    private var exportedItem: Binding<ExportedItem?> {
        Binding(
            get: { exportedURL.map { ExportedItem(url: $0) } },
            set: { exportedURL = $0?.url }
        )
    }

    @MainActor
    private func runExport() async {
        isExporting = true
        exportProgress = 0
        defer { isExporting = false }
        do {
            // 書き出し時の tint を closure に閉じ込めて、Exporter の signature は
            // tint 非依存のまま `(Double) -> AnyView` に保つ。
            let currentTint = tint
            let renderClosure: (Double) -> AnyView = { t in
                variant.render(t, currentTint)
            }
            let url = try await DemoVideoExporter.export(
                size: variant.exportSize,
                fps: 30,
                duration: variant.totalDuration,
                fileNameHint: variant.id,
                render: renderClosure
            ) { progress in
                exportProgress = progress
            }
            exportedURL = url
        } catch {
            exportError = error.localizedDescription
        }
    }

    private struct ExportedItem: Identifiable {
        let url: URL
        var id: URL { url }
    }
}

/// 全画面プレビュー (chrome 無し、デモが画面いっぱいに広がる)。
/// タップで閉じる。書き出しサイズと同じアスペクト比でアニメーションを表示。
struct DemoFullscreenView: View {
    let variant: DemoVariant
    let tint: Color

    @Environment(\.dismiss) private var dismiss
    @State private var startDate = Date()
    @State private var showCloseHint: Bool = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSince(startDate)
                    .truncatingRemainder(dividingBy: variant.totalDuration)
                GeometryReader { geo in
                    let scale = min(
                        geo.size.width / variant.exportSize.width,
                        geo.size.height / variant.exportSize.height
                    )
                    variant.render(elapsed, tint)
                        .environment(\.colorScheme, .light)
                        .frame(width: variant.exportSize.width,
                               height: variant.exportSize.height)
                        .scaleEffect(scale, anchor: .center)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .ignoresSafeArea()

            // 数秒後にフェードアウトする「タップで閉じる」ヒント
            if showCloseHint {
                VStack {
                    Spacer()
                    Text("タップで閉じる")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.black.opacity(0.45)))
                        .padding(.bottom, 40)
                }
                .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .task {
            // 2 秒でヒント自動非表示
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeOut(duration: 0.4)) {
                showCloseHint = false
            }
        }
        .statusBarHidden()
    }
}

// MARK: - Helpers shared across variants

extension Color {
    /// 明度を調整した Color を返す。`by` が正で明るく、負で暗く。範囲 -1 ... +1。
    /// 背景グラデーションを tint カラーから生成する用途。
    func adjust(by amount: Double) -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            let newB = max(0.0, min(1.0, b + CGFloat(amount)))
            return Color(hue: Double(h), saturation: Double(s), brightness: Double(newB), opacity: Double(a))
        }
        return self
    }
}

enum DemoEasing {
    /// 0 ... 1 にクランプして easeOut cubic を適用。
    static func easeOut(_ t: Double) -> Double {
        let c = max(0, min(1, t))
        return 1 - pow(1 - c, 3)
    }

    /// Apple 系プロモアニメで多用される easeInOut cubic。
    /// 動き出しと止まり際が極めて滑らか。カメラ移動向き。
    static func smoothEase(_ t: Double) -> Double {
        let c = max(0, min(1, t))
        return c < 0.5
            ? 4 * c * c * c
            : 1 - pow(-2 * c + 2, 3) / 2
    }

    /// バネ感のある overshoot 入り。終端で 1.0 を超えてから戻る (1.10 → 1.0)。
    /// バッジ / ボタンの「ポン」と入る演出向き。
    static func springOvershoot(_ t: Double, overshoot: Double = 0.10) -> Double {
        let c = max(0, min(1, t))
        let s = 1.70158 * (overshoot / 0.10)
        let p = c - 1
        return p * p * ((s + 1) * p + s) + 1
    }

    /// 線形クランプ。`stagger` で「シーン内の遅延付き 0...1」を表現する時に使う。
    static func progress(_ t: Double, from start: Double, duration: Double) -> Double {
        guard duration > 0 else { return t >= start ? 1 : 0 }
        return max(0, min(1, (t - start) / duration))
    }
}
