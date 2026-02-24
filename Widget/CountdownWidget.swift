import SwiftUI
import WidgetKit

private struct CountdownCurve: View {
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
                    .stroke(.secondary.opacity(0.28), style: .init(lineWidth: 2, lineCap: .round))

                curve
                    .trim(from: 0, to: clamped(progress))
                    .stroke(tint, style: .init(lineWidth: 2.8, lineCap: .round))

                ForEach(Array(dots.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(progress + 0.001 >= (Double(index) * step) ? tint : .secondary.opacity(0.5))
                        .frame(width: index == dots.count / 2 ? 9 : 7, height: index == dots.count / 2 ? 9 : 7)
                        .position(point)
                }
            }
        }
        .frame(height: 18)
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
        VStack {
            if entry.prayers.isEmpty {
                Text("Open app to get prayer times")
                    .foregroundColor(entry.accentColor.color)
            } else {
                if let currentPrayer = entry.currentPrayer, let nextPrayer = entry.nextPrayer {
                    switch widgetFamily {
                    case .systemMedium:
                        let timeline = timelinePrayers()
                        VStack(alignment: .leading, spacing: 8) {
                            CountdownCurve(
                                progress: timelineProgress(prayers: timeline),
                                dotCount: timeline.count,
                                tint: entry.accentColor.color
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
        .supportedFamilies([.systemSmall, .systemMedium])
        .configurationDisplayName("Prayer Countdown")
        .description("This widget displays the upcoming prayer time")
    }
}
