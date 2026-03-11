import SwiftUI
import WidgetKit

struct LockScreen1EntryView: View {
    var entry: PrayersProvider.Entry

    var body: some View {
        VStack(alignment: .center, spacing: 3) {
            if entry.prayers.isEmpty {
                Text("Open app to get prayer times")
                    .font(.caption)
            } else if let nextPrayer = entry.nextPrayer {
                HStack(spacing: 2) {
                    if !nextPrayer.nameTransliteration.contains("/") {
                        Image(systemName: nextPrayer.image)
                            .font(.system(size: 9, weight: .semibold))
                    }

                    Text(widgetPrayerDisplayName(nextPrayer.nameTransliteration))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.2)
                        .allowsTightening(true)
                        .layoutPriority(1)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                Text(nextPrayer.time, style: .time)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.7)
    }
}

struct LockScreen1Widget: Widget {
    let kind: String = "LockScreen1Widget"

    var body: some WidgetConfiguration {
        #if os(iOS)
        if #available(iOS 16, *) {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                if #available(iOS 17.0, *) {
                    LockScreen1EntryView(entry: entry)
                        .containerBackground(for: .widget) { Color.clear }
                } else {
                    LockScreen1EntryView(entry: entry)
                }
            }
            .supportedFamilies([.accessoryCircular])
            .configurationDisplayName("Next Prayer Times")
            .description("Shows the next upcoming prayer time")
        } else {
            return StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
                LockScreen1EntryView(entry: entry)
            }
            .supportedFamilies([.systemSmall])
            .configurationDisplayName("Next Prayer Times")
            .description("Shows the next upcoming prayer time")
        }
        #endif
    }
}
