import SwiftUI
import WidgetKit

struct SimpleEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily

    var entry: PrayersProvider.Entry
    
    var hijriCalendar: Calendar = {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.locale = Locale(identifier: "ar")
        return calendar
    }()
    
    var hijriDate: String {
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

    var body: some View {
        VStack {
            if entry.prayers.isEmpty {
                Text("Open app to get prayer times")
                    .foregroundColor(entry.accentColor.color)
            } else {
                let resolved = widgetResolvedCurrentAndNextPrayers(in: entry)
                if let currentPrayer = resolved.current, let nextPrayer = resolved.next {
                    VStack(alignment: .leading) {
                        HStack(spacing: 3) {
                            Text(appLocalized("Time left:"))
                                .fixedSize(horizontal: true, vertical: false)
                                .layoutPriority(1)
                            Text(widgetPrayerDisplayTime(nextPrayer, in: entry), style: .timer)
                        }
                        .font(.caption2)
                        
                        Spacer()
                        
                        VStack {
                            Image(systemName: currentPrayer.image)
                                .font(.title2)
                            
                            Text(widgetPrayerDisplayName(currentPrayer, in: entry))
                                .font(.headline)
                                .padding(.vertical, 1)
                        }
                        .foregroundColor(widgetIsShurooq(currentPrayer, in: entry) ? .primary : entry.accentColor.color)
                        .padding(.bottom, -4)
                        
                        HStack {
                            Text("Next:")
                            
                            Image(systemName: nextPrayer.image)
                                .padding(.horizontal, -6)
                            
                            Text(widgetPrayerDisplayName(nextPrayer, in: entry))
                        }
                        .font(.caption2)
                        .foregroundColor(widgetIsShurooq(nextPrayer, in: entry) ? .primary : entry.accentColor.color)
                        .padding(.vertical, 1)
                        
                        HStack(spacing: 3) {
                            Text(appLocalized("Starts at"))
                                .fixedSize(horizontal: true, vertical: false)
                                .layoutPriority(1)
                            Text(widgetPrayerDisplayTime(nextPrayer, in: entry), style: .time)
                        }
                        .font(.caption2)
                    }
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
}

struct SimpleWidget: Widget {
    let kind: String = "SimpleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
            if #available(iOS 17.0, *) {
                SimpleEntryView(entry: entry)
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                SimpleEntryView(entry: entry)
                    .padding()
            }
        }
        .supportedFamilies([.systemSmall])
        .configurationDisplayName("Simple Prayer Countdown")
        .description("This widget displays the upcoming prayer time in a simple way")
    }
}
