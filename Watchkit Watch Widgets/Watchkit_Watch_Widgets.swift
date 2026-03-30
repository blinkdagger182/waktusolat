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
        .configurationDisplayName("Waktu Next")
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
            VStack(spacing: 2) {
                Image(systemName: info?.image ?? "bell.fill")
                    .font(.headline)
                    .foregroundStyle(accent)
                Text(info?.title ?? "Waktu")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
            }
            .padding(6)
        }
    }

    private var rectangularView: some View {
        let currentInfo = entry.currentPrayer.map { provider.displayInfo(for: $0, in: entry, now: entry.date) }
        let nextInfo = entry.nextPrayer.map { provider.displayInfo(for: $0, in: entry, now: entry.date) }
        let accent = provider.accentColor(for: entry.accentRawValue)
        let progress = provider.nextPrayerProgress(in: entry, now: entry.date)
        let timeRemaining = provider.timeRemaining(to: entry.nextPrayer, from: entry.date)

        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(entry.city)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 6)
                Text(entry.sourceLabel)
                    .font(.caption2.bold())
                    .foregroundStyle(accent)
            }

            if let nextInfo {
                HStack(spacing: 6) {
                    Image(systemName: nextInfo.image)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                    Text(nextInfo.title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Spacer(minLength: 6)
                    Text(nextInfo.time, style: .time)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(accent.opacity(0.16))
                        Capsule()
                            .fill(accent)
                            .frame(width: max(proxy.size.width * progress, 10))
                    }
                }
                .frame(height: 5)

                if let timeRemaining {
                    Text(timeRemaining)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }

            if let currentInfo {
                Divider()
                Text("Now: \(currentInfo.title)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
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
        let progress = provider.nextPrayerProgress(in: entry, now: entry.date)
        let info = entry.nextPrayer.map { provider.displayInfo(for: $0, in: entry, now: entry.date) }

        return ZStack {
            Circle()
                .stroke(accent.opacity(0.2), lineWidth: 5)
            Circle()
                .trim(from: 0, to: max(progress, 0.04))
                .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Image(systemName: info?.image ?? "waveform.path.ecg")
                    .font(.caption.bold())
                    .foregroundStyle(accent)
                Text(info?.title ?? "Next")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
            }
            .padding(6)
        }
    }

    private var rectangularView: some View {
        let accent = provider.accentColor(for: entry.accentRawValue)
        let currentInfo = entry.currentPrayer.map { provider.displayInfo(for: $0, in: entry, now: entry.date) }
        let nextInfo = entry.nextPrayer.map { provider.displayInfo(for: $0, in: entry, now: entry.date) }
        let progress = provider.nextPrayerProgress(in: entry, now: entry.date)
        let upcoming = provider.upcomingPrayers(in: entry, from: entry.date, limit: 3)

        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Timeline+")
                    .font(.caption2.bold())
                    .foregroundStyle(accent)
                Spacer()
                Text(entry.city)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if let currentInfo, let nextInfo {
                HStack(spacing: 6) {
                    Label {
                        Text(currentInfo.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } icon: {
                        Image(systemName: currentInfo.image)
                            .foregroundStyle(accent)
                    }
                    Spacer(minLength: 6)
                    Text(nextInfo.time, style: .time)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(accent.opacity(0.16))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accent.opacity(0.9), accent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(proxy.size.width * progress, 10))
                    }
                }
                .frame(height: 5)
            }

            ForEach(upcoming.prefix(3)) { prayer in
                let info = provider.displayInfo(for: prayer, in: entry, now: entry.date)
                HStack(spacing: 6) {
                    Image(systemName: info.image)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(prayer.id == entry.nextPrayer?.id ? accent : .secondary)
                    Text(info.title)
                        .font(.caption2.weight(prayer.id == entry.nextPrayer?.id ? .bold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                    Spacer(minLength: 4)
                    Text(info.time, style: .time)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
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
        .configurationDisplayName("Waktu Timeline")
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
                Text(entry.sourceLabel)
                    .font(.caption2.bold())
                    .foregroundStyle(accent)
                Spacer()
                Text(entry.city)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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

#Preview(as: .accessoryRectangular) {
    WaktuNextPrayerWidget()
} timeline: {
    WatchPrayerWidgetProvider().previewEntry(date: .now)
}
