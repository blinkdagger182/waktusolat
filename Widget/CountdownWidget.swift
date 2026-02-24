import SwiftUI
import WidgetKit

private struct CountdownCurve: View {
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
            let middle = CGPoint(x: width * 0.5, y: height * 0.22)
            let end = CGPoint(x: width, y: height * 0.76)
            let curve = Path { path in
                path.move(to: start)
                path.addQuadCurve(to: end, control: CGPoint(x: width * 0.5, y: -height * 0.1))
            }

            ZStack {
                curve
                    .stroke(.secondary.opacity(0.28), style: .init(lineWidth: 2, lineCap: .round))

                curve
                    .trim(from: 0, to: clamped(progress))
                    .stroke(tint, style: .init(lineWidth: 2.8, lineCap: .round))

                Circle()
                    .fill(progress >= 0.02 ? tint : .secondary.opacity(0.5))
                    .frame(width: 7, height: 7)
                    .position(start)

                Circle()
                    .fill(progress >= 0.5 ? tint : .secondary.opacity(0.5))
                    .frame(width: 9, height: 9)
                    .position(middle)

                Circle()
                    .fill(progress >= 0.98 ? tint : .secondary.opacity(0.5))
                    .frame(width: 7, height: 7)
                    .position(end)
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
    
    private func progress(current: Prayer, next: Prayer) -> Double {
        let total = next.time.timeIntervalSince(current.time)
        guard total > 0 else { return 0 }
        let elapsed = Date().timeIntervalSince(current.time)
        return min(max(elapsed / total, 0), 1)
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
                        VStack(alignment: .leading, spacing: 8) {
                            CountdownCurve(
                                progress: progress(current: currentPrayer, next: nextPrayer),
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
