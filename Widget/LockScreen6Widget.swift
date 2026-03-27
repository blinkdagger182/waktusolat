import SwiftUI
import WidgetKit

private struct PrayerCountdownBarWindow {
    let start: Date
    let end: Date
}

private func storedLockScreenPrayerCountdownBarStyle() -> LockScreenPrayerCountdownBarStyle {
    let rawValue = UserDefaults(suiteName: sharedAppGroupID)?
        .string(forKey: LockScreenPrayerCountdownBarStyle.storageKey)
    return LockScreenPrayerCountdownBarStyle(rawValue: rawValue ?? "") ?? .withLocation
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
                ZStack {
                    graphData.curve
                        .stroke(baseLineColor, style: .init(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

                    graphData.curve
                        .trim(from: 0, to: passedProgress)
                        .stroke(activeLineColor, style: .init(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

                    ForEach(Array(graphData.markers.enumerated()), id: \.offset) { index, marker in
                        Circle()
                            .fill(Color.black)
                            .frame(
                                width: index == graphData.peakIndex ? 13 : 11,
                                height: index == graphData.peakIndex ? 13 : 11
                            )
                            .position(marker)
                            .blendMode(.destinationOut)
                    }
                }
                .compositingGroup()

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

private struct LockScreenCurvierPrayerMiniGraph: View {
    @Environment(\.colorScheme) private var colorScheme
    let prayers: [Prayer]
    let activeDotIndex: Int

    private func normalizedCurveY(_ t: CGFloat) -> CGFloat {
        let clamped = min(max(t, 0), 1)
        let p0: CGFloat = 0.76
        let c1: CGFloat = 0.38
        let c2: CGFloat = 0.02
        let p3: CGFloat = 0.88
        let oneMinusT = 1 - clamped
        return
            (oneMinusT * oneMinusT * oneMinusT * p0) +
            (3 * oneMinusT * oneMinusT * clamped * c1) +
            (3 * oneMinusT * clamped * clamped * c2) +
            (clamped * clamped * clamped * p3)
    }

    private func markerPoints(in size: CGSize) -> [CGPoint] {
        let source = prayers.sorted { $0.time < $1.time }
        guard source.count > 1 else {
            return [
                CGPoint(x: size.width * 0.03, y: size.height * 0.82),
                CGPoint(x: size.width * 0.97, y: size.height * 0.82)
            ]
        }

        let first = source.first?.time.timeIntervalSince1970 ?? 0
        let last = max(source.last?.time.timeIntervalSince1970 ?? first + 1, first + 1)
        let range = max(last - first, 1)
        let leftInset = size.width * 0.03
        let usableWidth = size.width * 0.94

        return source.map { prayer in
            let normalized = CGFloat((prayer.time.timeIntervalSince1970 - first) / range)
            let clamped = min(max(normalized, 0), 1)
            let x = leftInset + usableWidth * clamped
            let y = size.height * normalizedCurveY(clamped)
            return CGPoint(x: x, y: y)
        }
    }

    private func sampledCurvePath(in size: CGSize) -> Path {
        var path = Path()
        let leftInset = size.width * 0.03
        let usableWidth = size.width * 0.94
        let steps = 48
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let point = CGPoint(
                x: leftInset + usableWidth * t,
                y: size.height * normalizedCurveY(t)
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

    var body: some View {
        GeometryReader { geo in
            let markers = markerPoints(in: geo.size)
            let peakIndex = markers.enumerated().min(by: { $0.element.y < $1.element.y })?.offset ?? 0
            let clampedActiveIndex = min(max(activeDotIndex, -1), max(markers.count - 1, -1))
            let baseLineColor = colorScheme == .light ? Color.black.opacity(0.42) : Color.white.opacity(0.68)
            let activeLineColor = colorScheme == .light ? Color.black.opacity(0.90) : Color.white.opacity(0.95)
            let futureDotStrokeColor = colorScheme == .light ? Color.black.opacity(0.55) : Color.white.opacity(0.72)

            ZStack {
                let curve = sampledCurvePath(in: geo.size)

                ZStack {
                    curve
                        .stroke(baseLineColor, style: .init(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

                    ForEach(Array(markers.enumerated()), id: \.offset) { index, point in
                        Circle()
                            .fill(Color.black)
                            .frame(width: index == peakIndex ? 13 : 11, height: index == peakIndex ? 13 : 11)
                            .position(point)
                            .blendMode(.destinationOut)
                    }
                }
                .compositingGroup()

                ForEach(Array(markers.enumerated()), id: \.offset) { index, point in
                    let isReached = index <= clampedActiveIndex
                    Circle()
                        .fill(isReached ? activeLineColor : Color.clear)
                        .overlay(
                            Circle().stroke(
                                isReached ? activeLineColor : futureDotStrokeColor,
                                lineWidth: 1.8
                            )
                        )
                        .frame(width: index == peakIndex ? 10 : 8, height: index == peakIndex ? 10 : 8)
                        .shadow(radius: isReached ? 0.6 : 0)
                        .position(point)
                }
            }
        }
        .frame(height: 30)
    }
}

private struct LockScreenPrayerDotCountdown: View {
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
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextTime, style: .time)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextPrayer)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
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

@available(iOSApplicationExtension 16.0, *)
struct LockScreen6EntryView: View {
    var entry: PrayersProvider.Entry

    private var selectedStyle: LockScreenPrayerCountdownBarStyle {
        storedLockScreenPrayerCountdownBarStyle()
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

    private func remainingIntervalText(at now: Date, until target: Date) -> String {
        let remaining = max(target.timeIntervalSince(now), 0)
        let totalMinutes = Int(remaining / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
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
        VStack(alignment: .leading, spacing: 4) {
            if entry.prayers.isEmpty {
                Text("Open app to get prayer times")
                    .font(.caption)
            } else if let nextPrayer = entry.nextPrayer,
                      let window = countdownBarPrayerWindow(for: entry) {
                VStack(alignment: .leading, spacing: 4) {
                    if let currentPrayer = entry.currentPrayer {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(widgetPrayerDisplayName(currentPrayer.nameTransliteration))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Spacer(minLength: 6)

                            if selectedStyle == .batteryWithLocation || selectedStyle == .batteryWithoutLocation {
                                Text(widgetPrayerDisplayName(nextPrayer.nameTransliteration))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text(nextPrayer.time, style: .time)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                    .lineLimit(1)
                            }
                        }
                    }

                    TimelineView(.periodic(from: entry.date, by: 1)) { context in
                        if selectedStyle == .batteryWithLocation || selectedStyle == .batteryWithoutLocation {
                            let progress = progressValue(at: context.date, for: window)
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.primary.opacity(0.28), lineWidth: 1.4)
                                    .frame(height: 24)

                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(entry.accentColor.color.opacity(0.9))
                                        .frame(width: max(geo.size.width * CGFloat(progress), 10), height: 18)
                                        .padding(.horizontal, 3)
                                        .padding(.vertical, 3)
                                }

                                Text(remainingIntervalText(at: context.date, until: window.end))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(progress > 0.45 ? Color.black.opacity(0.82) : .primary)
                                    .monospacedDigit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            }
                            .frame(height: 24)
                        } else {
                            ProgressView(value: progressValue(at: context.date, for: window))
                                .progressViewStyle(.linear)
                                .tint(entry.accentColor.color)
                        }
                    }

                    Text("Ends at \(endTimeText(nextPrayer.time))")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if selectedStyle == .withLocation || selectedStyle == .batteryWithLocation {
                        WidgetLocationFooter(entry: entry, widgetKind: "LockScreen6Widget")
                    }
                }
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
