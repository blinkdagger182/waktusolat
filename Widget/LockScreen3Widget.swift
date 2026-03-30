import SwiftUI
import WidgetKit

struct LockScreen3EntryView: View {
    var entry: PrayersProvider.Entry
    @AppStorage(PrayerListWidgetStyle.storageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var styleRaw = PrayerListWidgetStyle.classic.rawValue

    private var style: PrayerListWidgetStyle {
        (PrayerListWidgetStyle(rawValue: styleRaw) ?? .classic).resolvedForWidgetAccess
    }

    private func compactHourString(for prayer: Prayer) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm"
        return formatter.string(from: widgetPrayerDisplayTime(prayer, in: entry))
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

        let usesCompactDeparturesBoard = style == .departuresBoard

        return VStack(alignment: .leading, spacing: usesCompactDeparturesBoard ? 2 : 4) {
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

                            Text(widgetPrayerDisplayName(prayer, in: entry))
                                .fontWeight(.bold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)

                            Spacer()

                            Text(widgetPrayerDisplayTime(prayer, in: entry), style: .time)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(prayer.time <= entry.date ? .primary : .secondary)
                    }

                case .focus:
                    let focused = Array(visiblePrayers.prefix(3))

                    if let lead = focused.first {
                        HStack {
                            Text(widgetPrayerDisplayName(lead, in: entry))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                            Text(widgetPrayerDisplayTime(lead, in: entry), style: .time)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                    }

                    ForEach(Array(focused.dropFirst())) { prayer in
                        HStack {
                            Text(widgetPrayerDisplayName(prayer, in: entry))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                            Spacer()
                            Text(widgetPrayerDisplayTime(prayer, in: entry), style: .time)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                        .foregroundStyle(.secondary)
                    }

                case .departuresBoard, .departuresBoardNoLocation:
                    let focused = Array(visiblePrayers.prefix(3))
                    VStack(alignment: .leading, spacing: usesCompactDeparturesBoard ? 2 : 3) {
                        ForEach(focused) { prayer in
                            HStack(spacing: usesCompactDeparturesBoard ? 6 : 8) {
                                Text(widgetPrayerDisplayName(prayer, in: entry).uppercased())
                                    .font(.system(size: usesCompactDeparturesBoard ? 8 : 9, weight: .bold, design: .monospaced))
                                    .lineLimit(1)
                                    .minimumScaleFactor(usesCompactDeparturesBoard ? 0.7 : 0.75)

                                Spacer(minLength: 4)

                                Text(widgetPrayerDisplayTime(prayer, in: entry), style: .time)
                                    .font(.system(size: usesCompactDeparturesBoard ? 8 : 9, weight: .bold, design: .monospaced))
                                    .monospacedDigit()
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, usesCompactDeparturesBoard ? 7 : 8)
                            .padding(.vertical, usesCompactDeparturesBoard ? 2 : 4)
                            .background(
                                RoundedRectangle(cornerRadius: usesCompactDeparturesBoard ? 7 : 8, style: .continuous)
                                    .fill(prayer.time <= entry.date ? Color.primary.opacity(0.16) : Color.primary.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: usesCompactDeparturesBoard ? 7 : 8, style: .continuous)
                                    .stroke(prayer.time <= entry.date ? Color.primary.opacity(0.28) : Color.primary.opacity(0.14), lineWidth: 0.8)
                            )
                        }
                    }

                case .iconBoard:
                    let focused = Array(visiblePrayers.prefix(3))

                    HStack(alignment: .center, spacing: 8) {
                        ForEach(focused) { prayer in
                            VStack(spacing: 3) {
                                Text(compactHourString(for: prayer))
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)

                                Image(systemName: prayer.image)
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(width: 18, height: 18)

                                Text(widgetPrayerDisplayName(prayer, in: entry))
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .foregroundStyle(prayer.time <= entry.date ? .primary : .secondary)
                            .frame(maxWidth: .infinity)
                        }
                    }

                case .iconBoardSix:
                    let focused = Array(entry.prayers.prefix(6))

                    HStack(alignment: .center, spacing: 8) {
                        ForEach(focused) { prayer in
                            VStack(spacing: 3) {
                                Text(compactHourString(for: prayer))
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.55)

                                Image(systemName: prayer.image)
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(width: 16, height: 16)

                                Text(widgetPrayerDisplayName(prayer, in: entry))
                                    .font(.system(size: 7, weight: .bold, design: .rounded))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.65)
                            }
                            .foregroundStyle(prayer.time <= entry.date ? .primary : .secondary)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                if style != .departuresBoardNoLocation {
                    WidgetLocationFooter(entry: entry, widgetKind: "LockScreen3Widget")
                }
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
