import SwiftUI
import WidgetKit

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
            let clampedDots = max(4, dotCount)

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

            let m1 = cubicPoint(p0, c01a, c01b, p1, 0.50)
            let m3 = cubicPoint(p2, c23a, c23b, p3, 0.50)
            let sixMarkers: [CGPoint] = [p0, m1, p1, p2, m3, p3]
            let markers: [CGPoint] = Array(sixMarkers.prefix(min(max(clampedDots, 2), sixMarkers.count)))
            let peakIndex = markers.enumerated().min(by: { $0.element.y < $1.element.y })?.offset ?? 0
            let clampedActiveIndex = min(max(activeDotIndex, -1), max(markers.count - 1, -1))

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
            let passedProgress = clampedActiveIndex >= 0
                ? stops[min(clampedActiveIndex, max(stops.count - 1, 0))]
                : 0
            let baseLineColor = colorScheme == .light ? Color.black.opacity(0.42) : Color.white.opacity(0.68)
            let activeLineColor = colorScheme == .light ? Color.black.opacity(0.90) : Color.white.opacity(0.95)
            let futureDotStrokeColor = colorScheme == .light ? Color.black.opacity(0.55) : Color.white.opacity(0.72)

            let curve = Path { path in
                path.move(to: p0)
                path.addCurve(to: p1, control1: c01a, control2: c01b)
                path.addCurve(to: p2, control1: c12a, control2: c12b)
                path.addCurve(to: p3, control1: c23a, control2: c23b)
            }

            ZStack {
                curve
                    .stroke(baseLineColor, style: .init(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

                curve
                    .trim(from: 0, to: passedProgress)
                    .stroke(activeLineColor, style: .init(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

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
                        .frame(
                            width: index == peakIndex ? 10 : 8,
                            height: index == peakIndex ? 10 : 8
                        )
                        .shadow(radius: isReached ? 0.6 : 0)
                        .position(point)
                }
            }
        }
        .frame(height: 16)
    }
}

struct CountdownEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily

    var entry: PrayersProvider.Entry
    
    var hijriCalendar: Calendar = {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.locale = Locale(identifier: "ar")
        return calendar
    }()
    
    var hijriDate1: String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = hijriCalendar
        dateFormatter.dateStyle = .medium
        dateFormatter.locale = Locale(identifier: "en")
        
        guard let offsetDate = hijriCalendar.date(byAdding: .day, value: entry.hijriOffset, to: Date()) else {
            return dateFormatter.string(from: Date())
        }
        
        return dateFormatter.string(from: offsetDate)
    }

    private func graphPrayers() -> [Prayer] {
        let source = entry.fullPrayers.isEmpty ? entry.prayers : entry.fullPrayers
        let sorted = source.sorted { $0.time < $1.time }
        return Array(sorted.prefix(6))
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
        VStack {
            if entry.prayers.isEmpty {
                Text("Open app to get prayer times")
                    .foregroundColor(entry.accentColor.color)
            } else {
                if let currentPrayer = entry.currentPrayer, let nextPrayer = entry.nextPrayer {
                    switch widgetFamily {
                    case .systemMedium, .systemLarge:
                        let prayersForGraph = graphPrayers()
                        VStack(alignment: .leading, spacing: 8) {
                            PrayerMiniGraph(
                                tint: entry.accentColor.color,
                                dotCount: max(prayersForGraph.count, 2),
                                activeDotIndex: activeIndex(in: prayersForGraph)
                            )

                            HStack {
                                Text(currentPrayer.nameTransliteration)
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(entry.accentColor.color)
                                    .lineLimit(1)

                                Spacer(minLength: 4)

                                Text(nextPrayer.time, style: .timer)
                                    .font(.title3.monospacedDigit())
                                    .lineLimit(1)

                                Spacer(minLength: 4)

                                Text(nextPrayer.nameTransliteration)
                                    .font(.title3.weight(.semibold))
                                    .lineLimit(1)
                            }

                            HStack {
                                if !entry.currentCity.isEmpty {
                                    Image(systemName: "location.fill")
                                        .font(.caption2)
                                        .foregroundColor(entry.accentColor.color)
                                    Text(entry.currentCity)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 8)
                                Text("Next \(nextPrayer.time, style: .time)")
                                    .lineLimit(1)
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    case .systemSmall:
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Spacer()
                                Text(hijriDate1)
                                    .foregroundColor(entry.accentColor.color)
                                    .font(.caption2)
                                Spacer()
                            }

                            HStack {
                                Text(currentPrayer.nameTransliteration)
                                    .font(.headline)
                                    .foregroundColor(entry.accentColor.color)
                                    .lineLimit(1)
                                Spacer()
                                Text(nextPrayer.time, style: .timer)
                                    .font(.caption.monospacedDigit())
                                    .lineLimit(1)
                            }

                            HStack {
                                Text("Next \(nextPrayer.nameTransliteration)")
                                Spacer()
                                Text(nextPrayer.time, style: .time)
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                            if !entry.currentCity.isEmpty {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .font(.caption2)
                                        .foregroundColor(entry.accentColor.color)
                                    Text(entry.currentCity)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                            }
                        }
                    default:
                        EmptyView()
                    }
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
}

struct CountdownWidget: Widget {
    let kind: String = "CountdownWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
            if #available(iOS 17.0, *) {
                CountdownEntryView(entry: entry)
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                CountdownEntryView(entry: entry)
                    .padding()
            }
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .configurationDisplayName("Prayer Countdown")
        .description("This widget displays the upcoming prayer time")
    }
}
