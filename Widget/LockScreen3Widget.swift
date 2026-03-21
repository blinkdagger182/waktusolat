import SwiftUI
import WidgetKit

struct LockScreen3EntryView: View {
    var entry: PrayersProvider.Entry

    var body: some View {
        let now = entry.date

        let visiblePrayers: [Prayer] = {
            guard !entry.prayers.isEmpty else { return [] }
            let half = entry.prayers.count / 2
            // Pre-Fajr (all prayers still in future): show first half
            if entry.prayers.allSatisfy({ $0.time > now }) {
                return Array(entry.prayers.prefix(half))
            }
            // Post-Isha (all prayers passed): show last half
            if entry.prayers.allSatisfy({ $0.time <= now }) {
                return Array(entry.prayers.suffix(half))
            }
            // Mixed: use next prayer index to decide
            let nextIndex = entry.prayers.firstIndex(where: {
                $0.nameTransliteration == entry.nextPrayer?.nameTransliteration
            }) ?? 0
            return nextIndex < half
                ? Array(entry.prayers.prefix(half))
                : Array(entry.prayers.suffix(half))
        }()
        
        return VStack(alignment: .leading, spacing: 4) {
            if entry.prayers.isEmpty {
                Text("Open app to get prayer times")
            } else {
                ForEach(visiblePrayers) { prayer in
                    HStack {
                        Image(systemName: prayer.image)
                            .font(.caption)
                            .frame(width: 10, alignment: .center)

                        Text(widgetPrayerDisplayName(prayer.nameTransliteration))
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)

                        Spacer()

                        Text(prayer.time, style: .time)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(prayer.time <= entry.date ? .primary : .secondary)
                }

                WidgetLocationFooter(entry: entry, widgetKind: "LockScreen3Widget")
            }
        }
        .font(.caption)
        .multilineTextAlignment(.leading)
        .lineLimit(1)
    }
}

struct LockScreen3Widget: Widget {
    let kind: String = "LockScreen3Widget"

    var body: some WidgetConfiguration {
        #if os(iOS)
        if #available(iOS 16, *) {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                if #available(iOS 17.0, *) {
                    LockScreen3EntryView(entry: entry)
                        .containerBackground(for: .widget) { Color.clear }
                } else {
                    LockScreen3EntryView(entry: entry)
                }
            }
            .supportedFamilies([.accessoryRectangular])
            .configurationDisplayName("Prayer Times")
            .description("Shows the next 3 prayer times, auto-flipping to the second half of the day")
        } else {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                LockScreen3EntryView(entry: entry)
            }
            .supportedFamilies([.systemSmall])
            .configurationDisplayName("Prayer Times")
            .description("Shows the next 3 prayer times, auto-flipping to the second half of the day")
        }
        #endif
    }
}
