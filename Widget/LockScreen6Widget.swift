import SwiftUI
import WidgetKit

private struct PrayerCountdownBarWindow {
    let start: Date
    let end: Date
}

private func storedLockScreenPrayerCountdownStyle() -> LockScreenPrayerCountdownStyle {
    let rawValue = UserDefaults(suiteName: sharedAppGroupID)?
        .string(forKey: LockScreenPrayerCountdownStyle.storageKey)
    return LockScreenPrayerCountdownStyle(rawValue: rawValue ?? "") ?? .prayerCountdown
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

private struct LockScreenPrayerMiniGraph: View {
    @Environment(\.colorScheme) private var colorScheme
    let dotCount: Int
    let activeDotIndex: Int

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = max(geo.size.height, 1)
            let point: (CGFloat, CGFloat) -> CGPoint = { x, y in
                CGPoint(x: x * width, y: y * height)
            }

            let p0 = point(0.06, 0.70)
            let p1 = point(0.52, 0.10)
            let p2 = point(0.78, 0.26)
            let p3 = point(0.94, 0.66)

            let c01a = point(0.22, 0.70)
            let c01b = point(0.38, 0.08)
            let c12a = point(0.60, 0.10)
            let c12b = point(0.70, 0.24)
            let c23a = point(0.84, 0.30)
            let c23b = point(0.90, 0.66)
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
                        path.addCurve(to: p3, control1: point(0.66, 0.10), control2: point(0.84, 0.66))
                    }
                    return (markers, [0, 0.5, 1], 1, curve)
                }

                let mid1 = cubicPoint(p0, c01a, c01b, p1, 0.50)
                let mid3 = cubicPoint(p2, c23a, c23b, p3, 0.50)
                let sixMarkers = [p0, mid1, p1, p2, mid3, p3]
                let markers = Array(sixMarkers.prefix(clampedDots))
                let peakIndex = markers.enumerated().min(by: { $0.element.y < $1.element.y })?.offset ?? 0

                let segmentLength: (CGPoint, CGPoint, CGPoint, CGPoint) -> CGFloat = { a, b, c, d in
                    var total: CGFloat = 0
                    var previous = a
                    for step in 1...32 {
                        let t = CGFloat(step) / 32
                        let current = cubicPoint(a, b, c, d, t)
                        total += hypot(current.x - previous.x, current.y - previous.y)
                        previous = current
                    }
                    return total
                }

                let l1 = segmentLength(p0, c01a, c01b, p1)
                let l2 = segmentLength(p1, c12a, c12b, p2)
                let l3 = segmentLength(p2, c23a, c23b, p3)
                let total = max(l1 + l2 + l3, 0.0001)
                let allStops: [CGFloat] = [
                    0,
                    (0.5 * l1) / total,
                    l1 / total,
                    (l1 + l2) / total,
                    (l1 + l2 + 0.5 * l3) / total,
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

                ForEach(Array(graphData.markers.enumerated()), id: \.offset) { index, marker in
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
                        .position(marker)
                }
            }
        }
        .frame(height: 20)
    }
}

@available(iOSApplicationExtension 16.0, *)
struct LockScreen6EntryView: View {
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
        var index = -1
        for (offset, prayer) in prayers.enumerated() where now >= prayer.time {
            index = offset
        }
        return index
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if entry.prayers.isEmpty {
                Text("Open app to get prayer times")
                    .font(.caption)
            } else if let nextPrayer = entry.nextPrayer,
                      let window = countdownBarPrayerWindow(for: entry) {
                if selectedStyle == .prayerTimeline {
                    let prayersForGraph = graphPrayers()
                    let currentPrayer = entry.currentPrayer

                    LockScreenPrayerMiniGraph(
                        dotCount: max(prayersForGraph.count, 2),
                        activeDotIndex: activeIndex(in: prayersForGraph)
                    )

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(widgetPrayerDisplayName(currentPrayer?.nameTransliteration ?? nextPrayer.nameTransliteration))
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
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: nextPrayer.image.contains("/") ? "hourglass" : nextPrayer.image)
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 14)

                            Text(widgetPrayerDisplayName(nextPrayer.nameTransliteration))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                                .truncationMode(.tail)
                        }

                        Spacer(minLength: 8)

                        Text(nextPrayer.time, style: .timer)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .multilineTextAlignment(.trailing)
                    }

                    TimelineView(.periodic(from: entry.date, by: 1)) { context in
                        ProgressView(value: progressValue(at: context.date, for: window))
                            .progressViewStyle(.linear)
                    }

                    Text("Ends at \(endTimeText(nextPrayer.time))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                WidgetLocationFooter(entry: entry, widgetKind: "LockScreen6Widget")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .multilineTextAlignment(.leading)
    }
}

@available(iOSApplicationExtension 16.0, *)
struct LockScreen6Widget: Widget {
    let kind: String = "LockScreen6Widget"

    var body: some WidgetConfiguration {
        #if os(iOS)
        if #available(iOS 16, *) {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                if #available(iOS 17.0, *) {
                    LockScreen6EntryView(entry: entry)
                        .containerBackground(for: .widget) { Color.clear }
                } else {
                    LockScreen6EntryView(entry: entry)
                }
            }
            .supportedFamilies([.accessoryRectangular])
            .configurationDisplayName("Prayer Countdown Bar")
            .description("Shows the next prayer with a live countdown bar.")
        } else {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                LockScreen6EntryView(entry: entry)
            }
            .supportedFamilies([.systemSmall])
            .configurationDisplayName("Prayer Countdown Bar")
            .description("Shows the next prayer with a live countdown bar.")
        }
        #endif
    }
}
