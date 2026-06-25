import SwiftUI
import WidgetKit

// MARK: - Design tokens

private let skBg     = Color(red: 0.93, green: 0.93, blue: 0.93)
private let skBlack  = Color.black
private let skOrange = Color(red: 0.92, green: 0.38, blue: 0.09)
private let skGray   = Color(red: 0.50, green: 0.50, blue: 0.52)
private let skDim    = Color(red: 0.72, green: 0.72, blue: 0.74)

private let skTimeFmt: DateFormatter = {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HH:mm"; return f
}()

// MARK: - Prayer progress helper (same logic as Neo, separate type)

private struct SketchPrayerData {
    struct Item {
        let name: String
        let short: String
        let time: Date
        let isDone: Bool
    }
    let items: [Item]
    var done: Int { items.filter(\.isDone).count }
    var total: Int { items.count }
    var fraction: Double { total > 0 ? Double(done) / Double(total) : 0 }
    var percentText: String { "\(Int(round(fraction * 100)))%" }
}

private func skProgress(from entry: PrayersEntry) -> SketchPrayerData {
    let source = entry.fullPrayers.isEmpty ? entry.prayers : entry.fullPrayers
    let keys: [(String, String)] = [
        ("fajr", "Fajr"), ("dhuhr", "Dhuhr"), ("asr", "Asr"), ("maghrib", "Maghrib"), ("isha", "Isha")
    ]
    let items = keys.compactMap { key, short -> SketchPrayerData.Item? in
        guard let p = source.first(where: {
            let n = $0.nameTransliteration.lowercased()
            return n.contains(key)
                || (key == "dhuhr" && (n.contains("zuhur") || n.contains("jumuah")))
                || (key == "isha"  && (n.contains("isya") || n.contains("isyak")))
                || (key == "fajr"  && n.contains("subuh"))
                || (key == "maghrib" && n.contains("magrib"))
        }) else { return nil }
        return .init(name: localizedPrayerName(p.nameTransliteration),
                     short: short, time: p.time,
                     isDone: p.time < entry.date)
    }
    return SketchPrayerData(items: items)
}

// MARK: - Locked view

private struct SketchLockedView: View {
    var body: some View {
        ZStack {
            skBg
            VStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.title3).foregroundStyle(skOrange)
                Text("Waktu Pro").font(.system(size: 11, weight: .medium)).foregroundStyle(skOrange)
            }
        }
    }
}

// MARK: - Wave drawing (used by Small)

private struct SketchWaveView: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width; let h = size.height
            // Draw 4 wave curves, each offset slightly
            let offsets: [(Double, Double)] = [(0.0, 0.0), (0.05, 0.04), (0.10, 0.08), (0.16, 0.13)]
            for (i, (dx, dy)) in offsets.enumerated() {
                var wave = Path()
                wave.move(to: CGPoint(x: 0, y: h * (0.68 + dy)))
                wave.addCurve(
                    to: CGPoint(x: w * (1.0 - dx), y: h * (0.35 + dy * 0.5)),
                    control1: CGPoint(x: w * 0.28, y: h * (0.82 + dy)),
                    control2: CGPoint(x: w * 0.62, y: h * (0.30 + dy * 0.5))
                )
                let alpha = Double(offsets.count - i) / Double(offsets.count)
                ctx.stroke(wave, with: .color(skOrange.opacity(alpha * 0.9)),
                           style: StrokeStyle(lineWidth: i == 0 ? 2.2 : 1.4, lineCap: .round))
            }
            // Small accent dot on the primary wave
            let dotX = w * 0.62
            let dotY = h * (0.42)
            let dotR: CGFloat = 5
            ctx.fill(Path(ellipseIn: CGRect(x: dotX - dotR, y: dotY - dotR, width: dotR * 2, height: dotR * 2)),
                     with: .color(skOrange))
        }
    }
}

// MARK: - Hatch pattern (used by Medium/Large for "incomplete" texture)

private struct SketchHatchView: View {
    var opacity: Double = 0.18
    var body: some View {
        Canvas { ctx, size in
            let spacing: CGFloat = 5
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                ctx.stroke(p, with: .color(skGray.opacity(opacity)),
                           style: StrokeStyle(lineWidth: 1))
                x += spacing
            }
        }
    }
}

// MARK: - Donut chart (Sketch Large)

private struct SketchDonut: View {
    let fraction: Double
    let done: Int
    let total: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(skDim.opacity(0.4), lineWidth: 10)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(skOrange, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(done)/\(total)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(skBlack)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - SMALL — dark bg + orange wave
// ═══════════════════════════════════════════════════════

struct SketchSmallView: View {
    let entry: PrayersEntry

    private var current: Prayer? { entry.currentPrayer ?? entry.prayers.first }
    private var next: Prayer?    { entry.nextPrayer }

    var body: some View {
        ZStack {
            skBlack
            if !premiumWidgetsUnlocked() {
                SketchLockedView()
            } else {
                ZStack(alignment: .bottom) {
                    SketchWaveView()

                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Waktu")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Next prayer")
                                    .font(.system(size: 11))
                                    .foregroundStyle(skGray)
                            }
                            Spacer()
                            Image(systemName: "moon.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 14).padding(.top, 14)

                        Spacer()

                        // Prayer + time
                        VStack(alignment: .leading, spacing: 2) {
                            Text(localizedPrayerName(next?.nameTransliteration
                                                     ?? current?.nameTransliteration ?? "—"))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1).minimumScaleFactor(0.75)
                            Text(next.map { skTimeFmt.string(from: $0.time) }
                                 ?? current.map { skTimeFmt.string(from: $0.time) }
                                 ?? "--:--")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 14).padding(.bottom, 18)
                    }
                }
            }
        }
    }
}

struct SketchSmallWidget: Widget {
    let kind = "SketchSmallWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
            if #available(iOS 17.0, *) {
                SketchSmallView(entry: entry).containerBackground(for: .widget) { skBlack }
            } else {
                SketchSmallView(entry: entry)
            }
        }
        .supportedFamilies([.systemSmall])
        .configurationDisplayName("Sketch")
        .description("Next prayer on a dark canvas with an orange wave.")
        .contentMarginsDisabled()
    }
}

struct SketchTransitSmallView: View {
    let entry: PrayersEntry

    private var next: Prayer? { entry.nextPrayer }

    var body: some View {
        ZStack {
            skBlack
            if !premiumWidgetsUnlocked() {
                SketchLockedView()
            } else {
                ZStack(alignment: .bottom) {
                    SketchWaveView()
                        .opacity(0.75)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Next")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                                Text(entry.currentCity.isEmpty ? "Current location" : entry.currentCity)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(skGray)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            Spacer()
                            Image(systemName: next?.image ?? "moon.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(skOrange)
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 14)

                        Spacer()

                        VStack(alignment: .leading, spacing: 3) {
                            Text(localizedPrayerName(next?.nameTransliteration ?? "Waktu"))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            HStack(alignment: .firstTextBaseline, spacing: 7) {
                                Text(next.map { widgetApproxRemainingText(until: $0.time, from: entry.date, compact: true) } ?? "--")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(skOrange)
                                Text(next.map { skTimeFmt.string(from: $0.time) } ?? "--:--")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .monospacedDigit()
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 18)
                    }
                }
            }
        }
    }
}

private struct SketchMixedTile<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(skOrange.opacity(0.32), lineWidth: 1)
            }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - MEDIUM — Sketch + Sketch Transit mix
// ═══════════════════════════════════════════════════════

struct SketchMediumView: View {
    let entry: PrayersEntry

    var body: some View {
        ZStack {
            skBlack
            if !premiumWidgetsUnlocked() {
                SketchLockedView()
            } else {
                HStack(spacing: 10) {
                    SketchMixedTile {
                        SketchSmallView(entry: entry)
                    }
                    SketchMixedTile {
                        SketchTransitSmallView(entry: entry)
                    }
                }
                .padding(10)
            }
        }
    }
}

struct SketchMediumWidget: Widget {
    let kind = "SketchMediumWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
            if #available(iOS 17.0, *) {
                SketchMediumView(entry: entry).containerBackground(for: .widget) { skBg }
            } else {
                SketchMediumView(entry: entry)
            }
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("Sketch Progress")
        .description("Sketch canvas and Sketch Transit next-prayer board.")
        .contentMarginsDisabled()
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - LARGE — Sketch + Sketch Transit mix
// ═══════════════════════════════════════════════════════

private struct SketchDotGrid: View {
    let filledCount: Int
    let total: Int
    let columns: Int = 5
    var rows: Int { Int(ceil(Double(total) / Double(columns))) }

    var body: some View {
        Canvas { ctx, size in
            let cols = CGFloat(columns)
            let rows = CGFloat(Int(ceil(Double(total) / Double(columns))))
            let cellW = size.width / cols
            let cellH = size.height / rows
            let r = min(cellW, cellH) * 0.38

            for i in 0..<total {
                let col = i % columns
                let row = i / columns
                let cx = cellW * (CGFloat(col) + 0.5)
                let cy = cellH * (CGFloat(row) + 0.5)
                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                let path = Path(ellipseIn: rect)

                if i < filledCount {
                    ctx.fill(path, with: .color(skOrange))
                } else {
                    // Hatched circle: draw circle outline + clip diagonal lines inside
                    ctx.stroke(path, with: .color(skDim.opacity(0.5)),
                               style: StrokeStyle(lineWidth: 1.2))
                    ctx.clip(to: path)
                    let spacing: CGFloat = 4
                    var x: CGFloat = cx - r * 2
                    while x < cx + r * 2 {
                        var lp = Path()
                        lp.move(to: CGPoint(x: x, y: cy - r * 2))
                        lp.addLine(to: CGPoint(x: x + r * 2, y: cy + r * 2))
                        ctx.stroke(lp, with: .color(skDim.opacity(0.4)),
                                   style: StrokeStyle(lineWidth: 0.8))
                        x += spacing
                    }
                }
            }
        }
    }
}

struct SketchLargeView: View {
    let entry: PrayersEntry

    var body: some View {
        ZStack {
            skBlack
            if !premiumWidgetsUnlocked() {
                SketchLockedView()
            } else {
                VStack(spacing: 10) {
                    SketchMixedTile {
                        SketchTransitSmallView(entry: entry)
                    }
                    SketchMixedTile {
                        SketchSmallView(entry: entry)
                    }
                }
                .padding(12)
            }
        }
    }
}

struct SketchLargeWidget: Widget {
    let kind = "SketchLargeWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
            if #available(iOS 17.0, *) {
                SketchLargeView(entry: entry).containerBackground(for: .widget) { skBg }
            } else {
                SketchLargeView(entry: entry)
            }
        }
        .supportedFamilies([.systemLarge])
        .configurationDisplayName("Sketch Max")
        .description("Large Sketch mix with canvas and next-prayer board.")
        .contentMarginsDisabled()
    }
}
