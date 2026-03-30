//
//  Watchkit_Watch_Widgets.swift
//  Watchkit Watch Widgets
//
//  Created by Rizhan Ruslan on 31/03/2026.
//

import WidgetKit
import SwiftUI

struct Watchkit_Watch_Widgets: Widget {
    private let provider = WatchPrayerWidgetProvider()
    let kind: String = "WatchPrayerWidgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: provider) { entry in
            WatchPrayerWidgetEntryView(entry: entry, provider: provider)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Waktu")
        .description("Shows the current and next prayer on Apple Watch.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

private struct WatchPrayerWidgetEntryView: View {
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
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.45)
                    .multilineTextAlignment(.center)
            }
            .padding(6)
        }
    }

    private var rectangularView: some View {
        let currentInfo = entry.currentPrayer.map { provider.displayInfo(for: $0, in: entry, now: entry.date) }
        let nextInfo = entry.nextPrayer.map { provider.displayInfo(for: $0, in: entry, now: entry.date) }
        let accent = provider.accentColor(for: entry.accentRawValue)

        return VStack(alignment: .leading, spacing: 4) {
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
                Text(nextInfo.title)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(nextInfo.time, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let currentInfo {
                Divider()
                Text("Now: \(currentInfo.title)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

#Preview(as: .accessoryRectangular) {
    Watchkit_Watch_Widgets()
} timeline: {
    WatchPrayerWidgetProvider().previewEntry(date: .now)
}
