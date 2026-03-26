import SwiftUI
import WidgetKit

struct LockScreen3EntryView: View {
    var entry: PrayersProvider.Entry
    @AppStorage(PrayerListWidgetStyle.storageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var styleRaw = PrayerListWidgetStyle.classic.rawValue

    private var style: PrayerListWidgetStyle {
        PrayerListWidgetStyle(rawValue: styleRaw) ?? .classic
    }

    var body: some View {
        let now = entry.date

        let visiblePrayers: [Prayer] = {
            guard !entry.prayers.isEmpty else { return [] }
            let half = entry.prayers.count / 2
            if entry.prayers.allSatisfy({ $0.time > now }) {
                return Array(entry.prayers.prefix(half))
            }
            if entry.prayers.allSatisfy({ $0.time <= now }) {
                return Array(entry.prayers.suffix(half))
            }
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
                switch style {
                case .classic:
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

                case .focus:
                    let focused = Array(visiblePrayers.prefix(3))

                    if let lead = focused.first {
                        HStack {
                            Text(widgetPrayerDisplayName(lead.nameTransliteration))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                            Text(lead.time, style: .time)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                    }

                    ForEach(Array(focused.dropFirst())) { prayer in
                        HStack {
                            Text(widgetPrayerDisplayName(prayer.nameTransliteration))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                            Spacer()
                            Text(prayer.time, style: .time)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                        .foregroundStyle(.secondary)
                    }
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
            .configurationDisplayName("Prayer List")
            .description("Shows the next 3 prayer times in a compact list")
        } else {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                LockScreen3EntryView(entry: entry)
            }
            .supportedFamilies([.systemSmall])
            .configurationDisplayName("Prayer List")
            .description("Shows the next 3 prayer times in a compact list")
        }
        #endif
    }
}
