import SwiftUI
import WidgetKit

private struct CurvierPrayerMiniGraph: View {
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
        dateFormatter.locale = appLocale()

        let sourcePrayers = entry.fullPrayers.isEmpty ? entry.prayers : entry.fullPrayers
        let referenceDate = Settings.islamicReferenceDate(prayers: sourcePrayers)
        let effectiveOffset = Settings.effectiveHijriOffset(
            baseOffset: entry.hijriOffset,
            isMalaysia: entry.countryCode?.uppercased() == "MY"
        )
        guard let offsetDate = hijriCalendar.date(byAdding: .day, value: effectiveOffset, to: referenceDate) else {
            return dateFormatter.string(from: referenceDate)
        }

        return dateFormatter.string(from: offsetDate)
    }

    private func graphPrayers() -> [Prayer] {
        let source = entry.fullPrayers.isEmpty ? entry.prayers : entry.fullPrayers
        let sorted = source.sorted { $0.time < $1.time }
        guard entry.travelingMode else {
            return Array(sorted.prefix(6))
        }

        let travelNames = ["Fajr", "Dhuhr", "Maghrib"]
        return travelNames.compactMap { target in
            sorted.first { widgetPrayerDisplayName($0, in: entry) == target }
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
                            CurvierPrayerMiniGraph(
                                prayers: prayersForGraph,
                                activeDotIndex: activeIndex(in: prayersForGraph)
                            )

                            HStack {
                                Text(widgetPrayerDisplayName(currentPrayer, in: entry))
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(entry.accentColor.color)
                                    .lineLimit(1)

                                Spacer(minLength: 4)

                                Text(widgetPrayerDisplayTime(nextPrayer, in: entry), style: .timer)
                                    .font(.title3.monospacedDigit())
                                    .lineLimit(1)

                                Spacer(minLength: 4)

                                Text(widgetPrayerDisplayName(nextPrayer, in: entry))
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
                                Text("Next \(widgetPrayerDisplayTime(nextPrayer, in: entry), style: .time)")
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
                                Text(widgetPrayerDisplayName(currentPrayer, in: entry))
                                    .font(.headline)
                                    .foregroundColor(entry.accentColor.color)
                                    .lineLimit(1)
                                Spacer()
                                Text(widgetPrayerDisplayTime(nextPrayer, in: entry), style: .timer)
                                    .font(.caption.monospacedDigit())
                                    .lineLimit(1)
                            }

                            HStack {
                                Text("Next \(widgetPrayerDisplayName(nextPrayer, in: entry))")
                                Spacer()
                                Text(widgetPrayerDisplayTime(nextPrayer, in: entry), style: .time)
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
