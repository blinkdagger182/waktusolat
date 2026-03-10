import SwiftUI
import WidgetKit

struct LockScreen4EntryView: View {
    var entry: PrayersProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if entry.prayers.isEmpty {
                Text("Open app to get prayer times")
            } else {
                let prayers = Array(
                    entry.prayers
                        .suffix(Int(floor(Double(
                            entry.prayers.count / 2
                        ))))
                )
                
                ForEach(prayers) { prayer in
                    HStack {
                        Image(systemName: prayer.image)
                            .font(.caption)
                            .frame(width: 10, alignment: .center)
                        
                        Text(prayer.nameTransliteration)
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Spacer()
                        
                        Text(prayer.time, style: .time)
                            .fontWeight(.bold)
                    }
                    .foregroundColor((entry.currentPrayer?.nameTransliteration ?? "").contains(prayer.nameTransliteration) ? .primary : .secondary)
                }
            }
        }
        .font(.caption)
        .multilineTextAlignment(.leading)
        .lineLimit(1)
    }
}

struct LockScreen4Widget: Widget {
    let kind: String = "LockScreen4Widget"

    var body: some WidgetConfiguration {
        #if os(iOS)
        if #available(iOS 16, *) {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                if #available(iOS 17.0, *) {
                    LockScreen4EntryView(entry: entry)
                        .containerBackground(for: .widget) { Color.clear }
                } else {
                    LockScreen4EntryView(entry: entry)
                }
            }
            .supportedFamilies([.accessoryRectangular])
            .configurationDisplayName("Last 3 Prayer Times")
            .description("Shows the last three prayer times of the day")
        } else {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                LockScreen4EntryView(entry: entry)
            }
            .supportedFamilies([.systemSmall])
            .configurationDisplayName("Last 3 Prayer Times")
            .description("Shows the last three prayer times of the day")
        }
        #endif
    }
}

struct LockScreenVerseEntryView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("As-Saff 61:10-11")
                .font(.system(size: 16, weight: .bold, design: .serif))
                .foregroundStyle(Color(red: 0.93, green: 0.76, blue: 0.43))
                .lineLimit(1)

            Text("Shall I guide you to a transaction that will save you from a painful punishment?")
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundStyle(Color(red: 0.95, green: 0.83, blue: 0.57))
                .lineLimit(3)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }
}

struct LockScreenVerseWidget: Widget {
    let kind: String = "LockScreenVerseWidget"

    var body: some WidgetConfiguration {
        #if os(iOS)
        if #available(iOS 16, *) {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { _ in
                if #available(iOS 17.0, *) {
                    LockScreenVerseEntryView()
                        .containerBackground(for: .widget) { Color.clear }
                } else {
                    LockScreenVerseEntryView()
                }
            }
            .supportedFamilies([.accessoryRectangular])
            .configurationDisplayName("Verse Reminder")
            .description("Shows a hardcoded Quran verse snippet.")
        } else {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { _ in
                LockScreenVerseEntryView()
            }
            .supportedFamilies([.systemSmall])
            .configurationDisplayName("Verse Reminder")
            .description("Shows a hardcoded Quran verse snippet.")
        }
        #endif
    }
}
