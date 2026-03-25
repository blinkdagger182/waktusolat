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
        let effectiveOffset = Settings.effectiveHijriOffset(baseOffset: entry.hijriOffset, isMalaysia: entry.isMalaysia)
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
                if let currentPrayer = entry.currentPrayer, let nextPrayer = entry.nextPrayer {
                    VStack(alignment: .leading) {
                        HStack(spacing: 3) {
                            Text(appLocalized("Time left:"))
                            Text(nextPrayer.time, style: .timer)
                        }
                        .font(.caption2)
                        
                        Spacer()
                        
                        VStack {
                            Image(systemName: currentPrayer.image)
                                .font(.title2)
                            
                            Text(widgetPrayerDisplayName(currentPrayer.nameTransliteration))
                                .font(.headline)
                                .padding(.vertical, 1)
                        }
                        .foregroundColor(widgetIsShurooq(currentPrayer.nameTransliteration) ? .primary : entry.accentColor.color)
                        .padding(.bottom, -4)
                        
                        HStack {
                            Text("Next:")
                            
                            Image(systemName: nextPrayer.image)
                                .padding(.horizontal, -6)
                            
                            Text(widgetPrayerDisplayName(nextPrayer.nameTransliteration))
                        }
                        .font(.caption2)
                        .foregroundColor(widgetIsShurooq(nextPrayer.nameTransliteration) ? .primary : entry.accentColor.color)
                        .padding(.vertical, 1)
                        
                        HStack(spacing: 3) {
                            Text(appLocalized("Starts at"))
                            Text(nextPrayer.time, style: .time)
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
