import SwiftUI
import WidgetKit

private struct LockScreenCountdownCurve: View {
    let progress: Double
    let dotCount: Int
    let tint: Color

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private func points(width: CGFloat, height: CGFloat) -> [CGPoint] {
        let count = max(dotCount, 2)
        return (0..<count).map { index in
            let t = Double(index) / Double(count - 1)
            let x = width * CGFloat(t)
            let arch = sin(t * Double.pi)
            let y = height * CGFloat(0.78 - (0.48 * arch))
            return CGPoint(x: x, y: y)
        }
    }

    private func smoothPath(from pts: [CGPoint]) -> Path {
        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: first)
        guard pts.count > 1 else { return path }

        for i in 0..<(pts.count - 1) {
            let p0 = i > 0 ? pts[i - 1] : pts[i]
            let p1 = pts[i]
            let p2 = pts[i + 1]
            let p3 = i + 2 < pts.count ? pts[i + 2] : p2

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

        return path
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = max(geo.size.height, 1)
            let dots = points(width: width, height: height)
            let curve = smoothPath(from: dots)
            let step = 1.0 / Double(max(dots.count - 1, 1))

            ZStack {
                curve
                    .stroke(.secondary.opacity(0.28), style: .init(lineWidth: 1.6, lineCap: .round))

                curve
                    .trim(from: 0, to: clamped(progress))
                    .stroke(tint, style: .init(lineWidth: 2.2, lineCap: .round))

                ForEach(Array(dots.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(progress + 0.001 >= (Double(index) * step) ? tint : .secondary.opacity(0.5))
                        .frame(width: index == dots.count / 2 ? 8 : 6, height: index == dots.count / 2 ? 8 : 6)
                        .position(point)
                }
            }
        }
        .frame(height: 16)
    }
}

struct LockScreen2EntryView: View {
    var entry: PrayersProvider.Entry
    
    private func timelinePrayers() -> [Prayer] {
        let source = entry.fullPrayers.count >= 6 ? entry.fullPrayers : entry.prayers
        return source.sorted { $0.time < $1.time }
    }

    private func timelineProgress(prayers: [Prayer]) -> Double {
        guard prayers.count > 1 else { return 0 }
        let now = Date()

        guard let first = prayers.first, let last = prayers.last else { return 0 }
        if now <= first.time { return 0 }
        if now >= last.time { return 1 }

        for index in 0..<(prayers.count - 1) {
            let start = prayers[index].time
            let end = prayers[index + 1].time
            if now >= start && now <= end {
                let seg = end.timeIntervalSince(start)
                guard seg > 0 else { return 0 }
                let local = now.timeIntervalSince(start) / seg
                return (Double(index) + local) / Double(prayers.count - 1)
            }
        }

        return 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if entry.prayers.isEmpty {
                Text("Open app to get prayer times")
                    .font(.caption)
            } else if let currentPrayer = entry.currentPrayer, let nextPrayer = entry.nextPrayer {
                let timeline = timelinePrayers()
                LockScreenCountdownCurve(
                    progress: timelineProgress(prayers: timeline),
                    dotCount: timeline.count,
                    tint: entry.accentColor.color
                )

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(currentPrayer.nameTransliteration)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(entry.accentColor.color)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(nextPrayer.time, style: .timer)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(nextPrayer.nameTransliteration)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    if !entry.currentCity.isEmpty {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(entry.currentCity)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Text("Next \(nextPrayer.time, style: .time)")
                        .lineLimit(1)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
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
