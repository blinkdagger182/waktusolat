//
//  Watchkit_Watch_Widgets.swift
//  Watchkit Watch Widgets
//
//  Created by Rizhan Ruslan on 31/03/2026.
//

import WidgetKit
import SwiftUI

struct WaktuNextPrayerWidget: Widget {
    private let provider = WatchPrayerWidgetProvider()
    let kind: String = "WaktuNextPrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: provider) { entry in
            NextPrayerWidgetEntryView(entry: entry, provider: provider)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Waktu Timeline")
        .description("Shows the next prayer on Apple Watch.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

private struct NextPrayerWidgetEntryView: View {
    let entry: WatchPrayerWidgetEntry
    let provider: WatchPrayerWidgetProvider
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            inlineView
        case .accessoryCircular:
            circularView
        default:
            rectangularView
        }
    }

    private var inlineView: some View {
        let nextPrayer = entry.nextPrayer ?? entry.currentPrayer
        let info = nextPrayer.map { provider.displayInfo(for: $0, in: entry, now: entry.date) }
        return HStack(spacing: 4) {
            Text(info?.title ?? "Waktu")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let time = info?.time {
                Text(time, style: .time)
            }
        }
    }

    private var circularView: some View {
        let nextPrayer = entry.nextPrayer ?? entry.currentPrayer
        let info = nextPrayer.map { provider.displayInfo(for: $0, in: entry, now: entry.date) }
        let accent = provider.accentColor(for: entry.accentRawValue)

        return ZStack {
            Circle()
                .stroke(accent.opacity(0.25), lineWidth: 6)
            VStack(spacing: 1) {
                Image(systemName: info?.image ?? "bell.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                Text(info?.title ?? "Waktu")
                    .font(.system(size: 6.6, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .allowsTightening(true)
                if let time = info?.time {
                    Text(time, style: .time)
                        .font(.system(size: 6.1, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 7)
        }
    }

    private var rectangularView: some View {
        let currentInfo = entry.currentPrayer.map { provider.displayInfo(for: $0, in: entry, now: entry.date) }
        let nextInfo = entry.nextPrayer.map { provider.displayInfo(for: $0, in: entry, now: entry.date) }
        let accent = provider.accentColor(for: entry.accentRawValue)
        let prayersForGraph = entry.prayers.isEmpty ? [entry.currentPrayer, entry.nextPrayer].compactMap { $0 } : entry.prayers
        let activeIndex = max(prayersForGraph.lastIndex(where: { $0.time <= entry.date }) ?? -1, -1)

        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(entry.city)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            WatchCurvierPrayerMiniGraph(
                prayers: prayersForGraph,
                activeDotIndex: activeIndex
            )

            if let currentInfo, let nextInfo {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: currentInfo.image)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(accent)
                        Text(currentInfo.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    Spacer(minLength: 0)

                    Text(nextInfo.time, style: .time)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(nextInfo.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct WaktuCurrentPrayerWidget: Widget {
    private let provider = WatchPrayerWidgetProvider()
    let kind: String = "WaktuCurrentPrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: provider) { entry in
            CurrentPrayerWidgetEntryView(entry: entry, provider: provider)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Waktu Current")
        .description("Shows the current prayer and what comes next.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

private struct CurrentPrayerWidgetEntryView: View {
    let entry: WatchPrayerWidgetEntry
    let provider: WatchPrayerWidgetProvider
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        default:
            rectangularView
        }
    }

    private var circularView: some View {
        let accent = provider.accentColor(for: entry.accentRawValue)
        let info = entry.currentPrayer.map { provider.displayInfo(for: $0, in: entry, now: entry.date) }
        let progress = provider.nextPrayerProgress(in: entry, now: entry.date)

        return ZStack {
            Circle()
                .stroke(accent.opacity(0.18), lineWidth: 5.5)
            Circle()
                .trim(from: 0, to: max(progress, 0.02))
                .stroke(accent, style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Image(systemName: info?.image ?? "clock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                Text(info?.title ?? "Waktu")
                    .font(.system(size: 6.6, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .allowsTightening(true)
                if let time = info?.time {
                    Text(time, style: .time)
                        .font(.system(size: 6.1, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 7)
        }
    }

    private var rectangularView: some View {
        let accent = provider.accentColor(for: entry.accentRawValue)
        let currentInfo = entry.currentPrayer.map { provider.displayInfo(for: $0, in: entry, now: entry.date) }
        let nextInfo = entry.nextPrayer.map { provider.displayInfo(for: $0, in: entry, now: entry.date) }

        return VStack(alignment: .leading, spacing: 5) {
            Text(entry.city)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let currentInfo, let nextInfo {
                HStack(spacing: 6) {
                    Image(systemName: currentInfo.image)
                        .foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(currentInfo.title)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                        Text(currentInfo.time, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Divider()
                Text("Next: \(nextInfo.title)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct WaktuPrayerTimelineWidget: Widget {
    private let provider = WatchPrayerWidgetProvider()
    let kind: String = "WaktuPrayerTimelineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: provider) { entry in
            PrayerTimelineWidgetEntryView(entry: entry, provider: provider)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Waktu List")
        .description("Shows the next three prayer times.")
        .supportedFamilies([.accessoryRectangular])
    }
}

private struct PrayerTimelineWidgetEntryView: View {
    let entry: WatchPrayerWidgetEntry
    let provider: WatchPrayerWidgetProvider

    var body: some View {
        let upcoming = provider.upcomingPrayers(in: entry, from: entry.date, limit: 3)
        let accent = provider.accentColor(for: entry.accentRawValue)

        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(entry.city)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
            }

            ForEach(upcoming) { prayer in
                let info = provider.displayInfo(for: prayer, in: entry, now: entry.date)
                HStack(spacing: 6) {
                    Image(systemName: info.image)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(prayer.id == entry.nextPrayer?.id ? accent : .secondary)
                    Text(info.title)
                        .font(.system(size: 10, weight: prayer.id == entry.nextPrayer?.id ? .bold : .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Spacer(minLength: 6)
                    Text(info.time, style: .time)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct WatchCurvierPrayerMiniGraph: View {
    @Environment(\.colorScheme) private var colorScheme
    let prayers: [WatchWidgetPrayer]
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

        let total = max(source.last!.time.timeIntervalSince(source.first!.time), 1)
        let leftInset = size.width * 0.03
        let usableWidth = size.width * 0.94

        return source.map { prayer in
            let elapsed = prayer.time.timeIntervalSince(source.first!.time)
            let t = CGFloat(elapsed / total)
            return CGPoint(
                x: leftInset + usableWidth * t,
                y: size.height * normalizedCurveY(t)
            )
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

#Preview(as: .accessoryRectangular) {
    WaktuNextPrayerWidget()
} timeline: {
    WatchPrayerWidgetProvider().previewEntry(date: .now)
}
