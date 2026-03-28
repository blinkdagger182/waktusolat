import SwiftUI
import WidgetKit

struct Prayers2EntryView: View {
    @Environment(\.widgetFamily) var widgetFamily

    var entry: PrayersProvider.Entry

    func getPrayerColor(for prayer: Prayer, in prayers: [Prayer]) -> Color {
        guard let currentIndex = prayers.firstIndex(where: { $0.id == prayer.id }) else {
            return .secondary
        }

        guard let currentPrayerIndex = prayers.firstIndex(where: { $0.nameTransliteration == entry.currentPrayer?.nameTransliteration }) else {
            return .secondary
        }

        if currentIndex < currentPrayerIndex {
            return .primary
        } else if currentIndex == currentPrayerIndex {
            return entry.accentColor.color
        } else {
            return .secondary
        }
    }
    
    var hijriCalendar: Calendar = {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.locale = Locale(identifier: "ar")
        return calendar
    }()
    
    var hijriDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = hijriCalendar
        dateFormatter.dateStyle = .full
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
                    HStack {
                        Image(systemName: currentPrayer.image)
                            .foregroundColor(entry.accentColor.color)
                        
                        Text(widgetPrayerDisplayName(currentPrayer, in: entry))
                            .foregroundColor(widgetIsShurooq(currentPrayer, in: entry) ? .primary : entry.accentColor.color)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        HStack {
                            Spacer()
                            
                            HStack(spacing: 3) {
                                Text(appLocalized("Time left:"))
                                    .fixedSize(horizontal: true, vertical: false)
                                    .layoutPriority(1)
                                Text(widgetPrayerDisplayTime(nextPrayer, in: entry), style: .timer)
                            }
                            .font(.subheadline)
                            .frame(alignment: .trailing)
                            .multilineTextAlignment(.trailing)
                        }
                    }
                    .font(.headline)
                    .padding(.vertical, 4)
                }
                
                Spacer()

                let currentIndex = entry.prayers.firstIndex(where: {
                    $0.nameTransliteration == entry.currentPrayer?.nameTransliteration
                }) ?? 0
                let half = entry.prayers.count / 2
                let visiblePrayers = currentIndex >= half - 1
                    ? Array(entry.prayers.suffix(half))
                    : Array(entry.prayers.prefix(half))

                VStack(spacing: 4) {
                    ForEach(visiblePrayers) { prayer in
                        HStack {
                            Image(systemName: prayer.image)
                                .frame(width: 10, alignment: .center)

                            Text(widgetPrayerDisplayName(prayer, in: entry))
                                .fontWeight(.bold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)

                            Spacer()

                            Text(widgetPrayerDisplayTime(prayer, in: entry), style: .time)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(getPrayerColor(for: prayer, in: entry.prayers))
                        .font(.caption)
                    }
                }
                .frame(maxHeight: .infinity)
                
                Spacer()
                
                HStack {
                    if !entry.currentCity.isEmpty && !entry.currentCity.isEmpty {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(entry.accentColor.color)
                            .padding(.horizontal, 3)
                        
                        Text(entry.currentCity)
                            .font(.caption2)
                    }
                    
                    Spacer()
                    
                    Image("CurrentAppIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 15, height: 15)
                        .cornerRadius(2)
                }
                .padding(.vertical, 4)
            }
        }
        .lineLimit(1)
    }
}

struct Prayers2Widget: Widget {
    let kind: String = "Prayers2Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
            if #available(iOS 17.0, *) {
                Prayers2EntryView(entry: entry)
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                Prayers2EntryView(entry: entry)
                    .padding()
            }
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("Prayer Times")
        .description("This widget displays the prayer times")
    }
}
