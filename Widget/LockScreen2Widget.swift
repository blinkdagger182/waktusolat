import SwiftUI
import WidgetKit

private struct PrayerCountdownBarWindow {
    let start: Date
    let end: Date
}

private func storedLockScreenPrayerCountdownStyle() -> LockScreenPrayerCountdownStyle {
    let rawValue = UserDefaults(suiteName: sharedAppGroupID)?
        .string(forKey: LockScreenPrayerCountdownStyle.storageKey)
    return LockScreenPrayerCountdownStyle(rawValue: rawValue ?? "") ?? .prayerCountdownWithLocation
}

private func countdownBarPrayerWindow(for entry: PrayersProvider.Entry) -> PrayerCountdownBarWindow? {
    guard let nextPrayer = entry.nextPrayer else { return nil }

    let source = (entry.fullPrayers.isEmpty ? entry.prayers : entry.fullPrayers).sorted { $0.time < $1.time }
    let now = entry.date

    if let currentPrayer = entry.currentPrayer, currentPrayer.time < nextPrayer.time, currentPrayer.time <= now {
        return PrayerCountdownBarWindow(start: currentPrayer.time, end: nextPrayer.time)
    }

    if let previousPrayer = source.last(where: { $0.time < nextPrayer.time && $0.time <= now }) {
        return PrayerCountdownBarWindow(start: previousPrayer.time, end: nextPrayer.time)
    }

    let fallbackStart = min(now, nextPrayer.time.addingTimeInterval(-4 * 60 * 60))
    return PrayerCountdownBarWindow(start: fallbackStart, end: nextPrayer.time)
}

private struct PrayerMiniGraph: View {
    @Environment(\.colorScheme) private var colorScheme
    let tint: Color
    let dotCount: Int
    let activeDotIndex: Int

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = max(geo.size.height, 1)
            let P: (CGFloat, CGFloat) -> CGPoint = { x, y in .init(x: x * width, y: y * height) }

            let p0 = P(0.06, 0.70)
            let p1 = P(0.52, 0.10)
            let p2 = P(0.78, 0.26)
            let p3 = P(0.94, 0.66)

            let c01a = P(0.22, 0.70)
            let c01b = P(0.38, 0.08)
            let c12a = P(0.60, 0.10)
            let c12b = P(0.70, 0.24)
            let c23a = P(0.84, 0.30)
            let c23b = P(0.90, 0.66)
            let clampedDots = min(max(dotCount, 2), 6)

            let cubicPoint: (CGPoint, CGPoint, CGPoint, CGPoint, CGFloat) -> CGPoint = { a, b, c, d, t in
                let oneMinusT = 1 - t
                let x = (oneMinusT * oneMinusT * oneMinusT * a.x)
                    + (3 * oneMinusT * oneMinusT * t * b.x)
                    + (3 * oneMinusT * t * t * c.x)
                    + (t * t * t * d.x)
                let y = (oneMinusT * oneMinusT * oneMinusT * a.y)
                    + (3 * oneMinusT * oneMinusT * t * b.y)
                    + (3 * oneMinusT * t * t * c.y)
                    + (t * t * t * d.y)
                return CGPoint(x: x, y: y)
            }

            let baseLineColor = colorScheme == .light ? Color.black.opacity(0.42) : Color.white.opacity(0.68)
            let activeLineColor = colorScheme == .light ? Color.black.opacity(0.90) : Color.white.opacity(0.95)
            let futureDotStrokeColor = colorScheme == .light ? Color.black.opacity(0.55) : Color.white.opacity(0.72)
            let clampedActiveIndex = min(max(activeDotIndex, -1), max(clampedDots - 1, -1))

            let graphData: (markers: [CGPoint], stops: [CGFloat], peakIndex: Int, curve: Path) = {
                if clampedDots == 3 {
                    let markers = [p0, p1, p3]
                    let curve = Path { path in
                        path.move(to: p0)
                        path.addCurve(to: p1, control1: c01a, control2: c01b)
                        path.addCurve(to: p3, control1: P(0.66, 0.10), control2: P(0.84, 0.66))
                    }
                    return (markers, [0, 0.5, 1], 1, curve)
                }

                let m1 = cubicPoint(p0, c01a, c01b, p1, 0.50)
                let m3 = cubicPoint(p2, c23a, c23b, p3, 0.50)
                let sixMarkers: [CGPoint] = [p0, m1, p1, p2, m3, p3]
                let markers = Array(sixMarkers.prefix(clampedDots))
                let peakIndex = markers.enumerated().min(by: { $0.element.y < $1.element.y })?.offset ?? 0

                let segmentLength: (CGPoint, CGPoint, CGPoint, CGPoint) -> CGFloat = { a, b, c, d in
                    var total: CGFloat = 0
                    var prev = a
                    let steps = 32
                    for step in 1...steps {
                        let t = CGFloat(step) / CGFloat(steps)
                        let point = cubicPoint(a, b, c, d, t)
                        total += hypot(point.x - prev.x, point.y - prev.y)
                        prev = point
                    }
                    return total
                }

                let l1 = segmentLength(p0, c01a, c01b, p1)
                let l2 = segmentLength(p1, c12a, c12b, p2)
                let l3 = segmentLength(p2, c23a, c23b, p3)
                let totalLen = max(l1 + l2 + l3, 0.0001)
                let allStops: [CGFloat] = [
                    0,
                    (0.5 * l1) / totalLen,
                    (l1) / totalLen,
                    (l1 + l2) / totalLen,
                    (l1 + l2 + 0.5 * l3) / totalLen,
                    1
                ]
                let stops = Array(allStops.prefix(markers.count))
                let curve = Path { path in
                    path.move(to: p0)
                    path.addCurve(to: p1, control1: c01a, control2: c01b)
                    path.addCurve(to: p2, control1: c12a, control2: c12b)
                    path.addCurve(to: p3, control1: c23a, control2: c23b)
                }
                return (markers, stops, peakIndex, curve)
            }()

            let passedProgress = clampedActiveIndex >= 0
                ? graphData.stops[min(clampedActiveIndex, max(graphData.stops.count - 1, 0))]
                : 0

            ZStack {
                graphData.curve
                    .stroke(baseLineColor, style: .init(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

                graphData.curve
                    .trim(from: 0, to: passedProgress)
                    .stroke(activeLineColor, style: .init(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

                ForEach(Array(graphData.markers.enumerated()), id: \.offset) { index, point in
                    let isReached = index <= clampedActiveIndex
                    Circle()
                        .fill(isReached ? activeLineColor : Color.clear)
                        .overlay(
                            Circle().stroke(
                                isReached ? activeLineColor : futureDotStrokeColor,
                                lineWidth: 1.8
                            )
                        )
                        .frame(
                            width: index == graphData.peakIndex ? 10 : 8,
                            height: index == graphData.peakIndex ? 10 : 8
                        )
                        .shadow(radius: isReached ? 0.6 : 0)
                        .position(point)
                }
            }
        }
        .frame(height: 20)
    }
}

private struct PrayerDotCountdown: View {
    let currentPrayer: String
    let nextPrayer: String
    let nextTime: Date
    let footer: String?
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(index < 3 ? Color.primary.opacity(0.92) : Color.primary.opacity(0.26))
                        .frame(width: index == 2 ? 10 : 8, height: index == 2 ? 10 : 8)
                }
            }
            .frame(height: 16)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(currentPrayer)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(accentColor)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextTime, style: .time)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextPrayer)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct LockScreen2EntryView: View {
    var entry: PrayersProvider.Entry

    private var selectedStyle: LockScreenPrayerCountdownStyle {
        storedLockScreenPrayerCountdownStyle()
    }

    private func progressValue(at now: Date, for window: PrayerCountdownBarWindow) -> Double {
        let total = max(window.end.timeIntervalSince(window.start), 1)
        let elapsed = min(max(now.timeIntervalSince(window.start), 0), total)
        return elapsed / total
    }

    private func endTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func graphPrayers() -> [Prayer] {
        let source = entry.fullPrayers.isEmpty ? entry.prayers : entry.fullPrayers
        let sorted = source.sorted { $0.time < $1.time }
        guard entry.travelingMode else {
            return Array(sorted.prefix(6))
        }

        let travelNames = ["Fajr", "Dhuhr", "Maghrib"]
        return travelNames.compactMap { target in
            sorted.first { widgetPrayerDisplayName($0.nameTransliteration) == target }
        }
    }

    private func activeIndex(in prayers: [Prayer]) -> Int {
        guard !prayers.isEmpty else { return 0 }
        let now = Date()
        var idx = -1
        for (i, prayer) in prayers.enumerated() where now >= prayer.time {
            idx = i
        }
        return idx
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if entry.prayers.isEmpty {
                Text("Open app to get prayer times")
                    .font(.caption)
            } else if let currentPrayer = entry.currentPrayer,
                      let nextPrayer = entry.nextPrayer,
                      let window = countdownBarPrayerWindow(for: entry) {
                if selectedStyle == .prayerTimelineWithLocation || selectedStyle == .prayerTimelineWithoutLocation {
                    let prayersForGraph = graphPrayers()
                    PrayerMiniGraph(
                        tint: entry.accentColor.color,
                        dotCount: max(prayersForGraph.count, 2),
                        activeDotIndex: activeIndex(in: prayersForGraph)
                    )

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(widgetPrayerDisplayName(currentPrayer.nameTransliteration))
                            .font(.headline.weight(.semibold))
                            .foregroundColor(entry.accentColor.color)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        Text(nextPrayer.time, style: .time)
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        Text(widgetPrayerDisplayName(nextPrayer.nameTransliteration))
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                } else {
                    PrayerDotCountdown(
                        currentPrayer: widgetPrayerDisplayName(currentPrayer.nameTransliteration),
                        nextPrayer: widgetPrayerDisplayName(nextPrayer.nameTransliteration),
                        nextTime: nextPrayer.time,
                        footer: selectedStyle == .prayerCountdownWithLocation ? entry.currentCity : nil,
                        accentColor: entry.accentColor.color
                    )
                }
                if selectedStyle == .prayerTimelineWithLocation {
                    WidgetLocationFooter(entry: entry, widgetKind: "LockScreen2Widget")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .multilineTextAlignment(.leading)
        .lineLimit(2)
        .minimumScaleFactor(0.5)
    }
}

struct LockScreen2Widget: Widget {
    let kind: String = "LockScreen2Widget"

    var body: some WidgetConfiguration {
        #if os(iOS)
        if #available(iOS 16, *) {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                if #available(iOS 17.0, *) {
                    LockScreen2EntryView(entry: entry)
                        .containerBackground(for: .widget) { Color.clear }
                } else {
                    LockScreen2EntryView(entry: entry)
                }
            }
            .supportedFamilies([.accessoryRectangular])
            .configurationDisplayName("Prayer Times")
            .description("Shows the current prayer and the time remaining until the next prayer")
        } else {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                LockScreen2EntryView(entry: entry)
            }
            .supportedFamilies([.systemSmall])
            .configurationDisplayName("Prayer Times")
            .description("Shows the current prayer and the time remaining until the next prayer")
        }
        #endif
    }
}
