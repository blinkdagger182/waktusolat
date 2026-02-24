import SwiftUI
import WidgetKit

private struct LockScreenCountdownCurve: View {
    let progress: Double
    let tint: Color

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = max(geo.size.height, 1)
            let start = CGPoint(x: 0, y: height * 0.76)
            let mid = CGPoint(x: width * 0.5, y: height * 0.2)
            let end = CGPoint(x: width, y: height * 0.76)
            let curve = Path { path in
                path.move(to: start)
                path.addQuadCurve(
                    to: end,
                    control: CGPoint(x: width * 0.5, y: -height * 0.08)
                )
            }

            ZStack {
                curve
                    .stroke(.secondary.opacity(0.28), style: .init(lineWidth: 1.6, lineCap: .round))

                curve
                    .trim(from: 0, to: clamped(progress))
                    .stroke(tint, style: .init(lineWidth: 2.2, lineCap: .round))

                Circle()
                    .fill(progress >= 0.02 ? tint : .secondary.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .position(start)

                Circle()
                    .fill(progress >= 0.5 ? tint : .secondary.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .position(mid)

                Circle()
                    .fill(progress >= 0.98 ? tint : .secondary.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .position(end)
            }
        }
        .frame(height: 16)
    }
}

struct LockScreen2EntryView: View {
    var entry: PrayersProvider.Entry
    
    private func progress(current: Prayer, next: Prayer) -> Double {
        let total = next.time.timeIntervalSince(current.time)
        guard total > 0 else { return 0 }
        let elapsed = Date().timeIntervalSince(current.time)
        return min(max(elapsed / total, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if entry.prayers.isEmpty {
                Text("Open app to get prayer times")
                    .font(.caption)
            } else if let currentPrayer = entry.currentPrayer, let nextPrayer = entry.nextPrayer {
                LockScreenCountdownCurve(
                    progress: progress(current: currentPrayer, next: nextPrayer),
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
