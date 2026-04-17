import SwiftUI
import WidgetKit

private struct LockScreen5Sparkline: View {
    let dotCount: Int
    let activeDotIndex: Int

    private func catmullRomPath(points: [CGPoint]) -> Path {
        Path { path in
            guard points.count > 1 else { return }
            path.move(to: points[0])

            for i in 0..<(points.count - 1) {
                let p0 = i > 0 ? points[i - 1] : points[i]
                let p1 = points[i]
                let p2 = points[i + 1]
                let p3 = (i + 2) < points.count ? points[i + 2] : p2

                let c1 = CGPoint(
                    x: p1.x + (p2.x - p0.x) / 6,
                    y: p1.y + (p2.y - p0.y) / 6
                )
                let c2 = CGPoint(
                    x: p2.x - (p3.x - p1.x) / 6,
                    y: p2.y - (p3.y - p1.y) / 6
                )
                path.addCurve(to: p2, control1: c1, control2: c2)
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let height = max(geo.size.height, 1)
            let p: (CGFloat, CGFloat) -> CGPoint = { x, y in
                CGPoint(x: x * width, y: y * height)
            }

            let clampedDotCount = min(max(dotCount, 2), 6)
            let points: [CGPoint] = clampedDotCount == 3
                ? [
                    p(0.06, 0.70),
                    p(0.52, 0.14),
                    p(0.95, 0.66)
                ]
                : [
                    p(0.06, 0.70),
                    p(0.30, 0.52),
                    p(0.52, 0.14),
                    p(0.70, 0.26),
                    p(0.84, 0.46),
                    p(0.95, 0.66)
                ]

            let smoothPath = catmullRomPath(points: points)

            let lineColor = Color.primary.opacity(0.86)
            let futureDotColor = Color.primary.opacity(0.55)
            let clampedActive = min(max(activeDotIndex, -1), points.count - 1)

            ZStack {
                smoothPath
                    .stroke(lineColor.opacity(0.7), style: .init(lineWidth: 2, lineCap: .round, lineJoin: .round))

                ForEach(Array(points.enumerated()), id: \.offset) { idx, point in
                    let reached = idx <= clampedActive
                    Circle()
                        .fill(reached ? lineColor : Color.clear)
                        .overlay(Circle().stroke(reached ? lineColor : futureDotColor, lineWidth: 1.5))
                        .frame(width: idx == (points.count / 2) ? 7.5 : 6.5, height: idx == (points.count / 2) ? 7.5 : 6.5)
                        .position(point)
                }
            }
        }
        .frame(height: 20)
    }
}

private struct LockScreenSparkEntryView: View {
    var entry: PrayersProvider.Entry

    private func graphPrayers() -> [Prayer] {
        let sorted = widgetResolvedPrayers(in: entry).sorted { $0.time < $1.time }
        guard entry.travelingMode else {
            return Array(sorted.prefix(6))
        }

        let travelNames = ["Fajr", "Dhuhr", "Maghrib"]
        return travelNames.compactMap { target in
            sorted.first { widgetPrayerDisplayName($0, in: entry) == target }
        }
    }

    private func activeIndex(in prayers: [Prayer]) -> Int {
        let now = Date()
        var idx = -1
        for (i, prayer) in prayers.enumerated() where now >= prayer.time {
            idx = i
        }
        return idx
    }

    var body: some View {
        if let nextPrayer = widgetResolvedCurrentAndNextPrayers(in: entry).next {
            let graph = graphPrayers()
            VStack(alignment: .leading, spacing: 6) {
                LockScreen5Sparkline(dotCount: graph.count, activeDotIndex: activeIndex(in: graph))

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Next Prayer")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(widgetPrayerDisplayName(nextPrayer, in: entry))
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    Spacer(minLength: 6)

                    Text(widgetPrayerDisplayTime(nextPrayer, in: entry), style: .timer)
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                WidgetLocationFooter(entry: entry, widgetKind: "LockScreen5Widget")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Text("Open app to get prayer times")
                .font(.caption)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

struct LockScreen5Widget: Widget {
    let kind: String = "LockScreen5Widget"

    var body: some WidgetConfiguration {
        #if os(iOS)
        if #available(iOS 16, *) {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                if #available(iOS 17.0, *) {
                    LockScreenSparkEntryView(entry: entry)
                        .containerBackground(for: .widget) { Color.clear }
                } else {
                    LockScreenSparkEntryView(entry: entry)
                }
            }
            .supportedFamilies([.accessoryRectangular])
            .configurationDisplayName("Prayer Spark Countdown")
            .description("Shows a 6-point prayer sparkline and countdown to the next prayer.")
        } else {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                LockScreenSparkEntryView(entry: entry)
            }
            .supportedFamilies([.systemSmall])
            .configurationDisplayName("Prayer Spark Countdown")
            .description("Shows a 6-point prayer sparkline and countdown to the next prayer.")
        }
        #endif
    }
}
