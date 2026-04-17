import SwiftUI
import WidgetKit
#if os(iOS)
import UIKit
#endif

#if os(iOS)
private func auraPrayerBackgroundKey(for prayer: Prayer?) -> AuraPrayerBackgroundKey {
    let transliteration = prayer?.nameTransliteration.lowercased() ?? ""
    let english = prayer?.nameEnglish.lowercased() ?? ""
    let symbol = prayer?.image.lowercased() ?? ""
    let combined = "\(transliteration) \(english) \(symbol)"

    if combined.contains("maghrib") || combined.contains("sunset") {
        return .maghrib
    }
    if combined.contains("asr") || combined.contains("asar") || combined.contains("sun.min") || combined.contains("afternoon") {
        return .asar
    }
    if combined.contains("isha") || combined.contains("isya") || combined.contains("isyak") || combined.contains("moon") || combined.contains("night") {
        return .isyak
    }
    if combined.contains("dhuhr") || combined.contains("zuhur") || combined.contains("jumuah") || combined.contains("noon") || combined.contains("sun.max") {
        return .zuhur
    }
    if combined.contains("sunrise") || combined.contains("syuruk") || combined.contains("shurooq") {
        return .syuruk
    }
    return .subuh
}

private func auraPrayerBackgroundKey(forAssetName assetName: String) -> AuraPrayerBackgroundKey {
    switch assetName {
    case "MaghribWidgetBackground":
        return .maghrib
    case "AsarWidgetBackground":
        return .asar
    case "IsyakWidgetBackground":
        return .isyak
    case "ZuhurWidgetBackground":
        return .zuhur
    case "SyurukWidgetBackground":
        return .syuruk
    default:
        return .subuh
    }
}

private func customAuraBackgroundImage(for key: AuraPrayerBackgroundKey) -> UIImage? {
    guard
        let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.app.riskcreatives.waktu")?
            .appendingPathComponent(key.storageFileName),
        FileManager.default.fileExists(atPath: url.path),
        let data = try? Data(contentsOf: url),
        let image = UIImage(data: data)
    else {
        return nil
    }
    return image
}

private func customAuraBackgroundImage(for prayer: Prayer?) -> UIImage? {
    customAuraBackgroundImage(for: auraPrayerBackgroundKey(for: prayer))
}
#endif

private func widgetBackgroundAssetName(for prayer: Prayer?) -> String {
    let transliteration = prayer?.nameTransliteration.lowercased() ?? ""
    let english = prayer?.nameEnglish.lowercased() ?? ""
    let symbol = prayer?.image.lowercased() ?? ""
    let combined = "\(transliteration) \(english) \(symbol)"

    if combined.contains("maghrib") || combined.contains("sunset") {
        return "MaghribWidgetBackground"
    }

    if combined.contains("asr") || combined.contains("asar") || combined.contains("sun.min") || combined.contains("afternoon") {
        return "AsarWidgetBackground"
    }

    if combined.contains("isha") || combined.contains("isya") || combined.contains("isyak") || combined.contains("moon") || combined.contains("night") {
        return "IsyakWidgetBackground"
    }

    if combined.contains("dhuhr") || combined.contains("zuhur") || combined.contains("jumuah") || combined.contains("noon") || combined.contains("sun.max") {
        return "ZuhurWidgetBackground"
    }

    if combined.contains("sunrise") || combined.contains("syuruk") || combined.contains("shurooq") {
        return "SyurukWidgetBackground"
    }

    return "SubuhWidgetBackground"
}

private func resolvedDisplayPrayer(for entry: PrayersEntry) -> Prayer? {
    let resolved = widgetResolvedCurrentAndNextPrayers(in: entry)
    return resolved.next ?? resolved.current
}

private func auraDisplayPrayerName(_ name: String) -> String {
    widgetPrayerDisplayName(name)
}

private struct GraphicPrayerEntryView: View {
    var entry: PrayersProvider.Entry

    private var displayPrayer: Prayer? {
        resolvedDisplayPrayer(for: entry)
    }

    private func formattedTime(_ date: Date) -> (main: String, meridiem: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        let full = formatter.string(from: date)
        let parts = full.split(separator: " ")
        if parts.count == 2 {
            return (String(parts[0]), String(parts[1]))
        }
        return (full, "")
    }

    @ViewBuilder
    private func backgroundView(for prayer: Prayer?) -> some View {
        #if os(iOS)
        if let customBackground = customAuraBackgroundImage(for: prayer) {
            Image(uiImage: customBackground)
                .resizable()
                .scaledToFill()
        } else {
            Image(widgetBackgroundAssetName(for: prayer))
                .resizable()
                .scaledToFill()
        }
        #else
        Image(widgetBackgroundAssetName(for: prayer))
            .resizable()
            .scaledToFill()
        #endif
    }

    var body: some View {
        ZStack {
            backgroundView(for: displayPrayer)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            LinearGradient(
                colors: [Color.black.opacity(0.12), Color.black.opacity(0.30)],
                startPoint: .top,
                endPoint: .bottom
            )

            if let prayer = displayPrayer {
                let displayTime = widgetPrayerDisplayTime(prayer, in: entry)
                let timeText = formattedTime(displayTime)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.stars.fill")
                            .font(.headline)
                        Text(widgetPrayerDisplayName(prayer, in: entry))
                            .font(.title2.weight(.bold))
                    }
                    .foregroundColor(.white)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(timeText.main)
                            .font(.system(size: 46, weight: .bold))
                        Text(timeText.meridiem)
                            .font(.title2.weight(.semibold))
                    }
                    .foregroundColor(.white)

                    HStack(spacing: 5) {
                        Text("In")
                        Text(displayTime, style: .timer)
                    }
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .monospacedDigit()
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                Text("Open app to refresh prayer times")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(16)
            }
        }
        .clipped()
    }
}

private struct GraphicPrayerSquareEntryView: View {
    var entry: GraphicPrayerSquareEntry

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    var body: some View {
        ZStack {
            #if os(iOS)
            if let customBackground = customAuraBackgroundImage(for: auraPrayerBackgroundKey(forAssetName: entry.backgroundAsset)) {
                Image(uiImage: customBackground)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Image(entry.backgroundAsset)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
            #else
            Image(entry.backgroundAsset)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            #endif

            LinearGradient(
                colors: [Color.black.opacity(0.10), Color.black.opacity(0.32)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 3) {
                Text(auraDisplayPrayerName(entry.prayerName))
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(formattedTime(entry.prayerTime))
                    .font(.system(size: 24, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 4) {
                    Text("In")
                    Text(entry.prayerTime, style: .timer)
                }
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .monospacedDigit()
            }
            .padding(12)
            .foregroundColor(.white)
            .environment(\.redactionReasons, RedactionReasons())
            .unredacted()
        }
        .compositingGroup()
        .clipped()
        .environment(\.redactionReasons, RedactionReasons())
        .unredacted()
    }
}

private struct GraphicPrayerSquareEntry: TimelineEntry {
    let date: Date
    let prayerName: String
    let prayerTime: Date
    let backgroundAsset: String
}

private struct GraphicPrayerSquareProvider: TimelineProvider {
    private let appGroupStore = UserDefaults(suiteName: "group.app.riskcreatives.waktu")
    private let prayerDataKey = "prayersData"

    func placeholder(in context: Context) -> GraphicPrayerSquareEntry {
        sampleEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (GraphicPrayerSquareEntry) -> Void) {
        completion(loadEntry() ?? sampleEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GraphicPrayerSquareEntry>) -> Void) {
        let entry = loadEntry() ?? sampleEntry()
        let refreshAt = max(Date().addingTimeInterval(15 * 60), entry.prayerTime)
        completion(Timeline(entries: [entry], policy: .after(refreshAt)))
    }

    private func loadEntry() -> GraphicPrayerSquareEntry? {
        guard
            let data = appGroupStore?.data(forKey: prayerDataKey),
            let prayers = try? Settings.decoder.decode(Prayers.self, from: data),
            !prayers.prayers.isEmpty
        else {
            return nil
        }

        let now = Date()
        let selected = prayers.prayers.first(where: { $0.time > now }) ?? prayers.prayers.first!
        return GraphicPrayerSquareEntry(
            date: now,
            prayerName: selected.nameTransliteration,
            prayerTime: selected.time,
            backgroundAsset: widgetBackgroundAssetName(for: selected)
        )
    }

    private func sampleEntry() -> GraphicPrayerSquareEntry {
        let now = Date()
        let sampleTime = now.addingTimeInterval(69 * 60)
        return GraphicPrayerSquareEntry(
            date: now,
            prayerName: "Isyak",
            prayerTime: sampleTime,
            backgroundAsset: "IsyakWidgetBackground"
        )
    }
}

struct GraphicPrayerWidget: Widget {
    let kind: String = "GraphicPrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayersProvider()) { entry in
            if #available(iOS 17.0, *) {
                GraphicPrayerEntryView(entry: entry)
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                GraphicPrayerEntryView(entry: entry)
                    .padding(0)
            }
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("Waktu Aura")
        .description("Shows the upcoming prayer with visual background style.")
        .contentMarginsDisabled()
    }
}

struct GraphicPrayerSquareWidget: Widget {
    let kind: String = "GraphicPrayerSquareWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GraphicPrayerSquareProvider()) { entry in
            if #available(iOS 17.0, *) {
                GraphicPrayerSquareEntryView(entry: entry)
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                GraphicPrayerSquareEntryView(entry: entry)
                    .padding(0)
            }
        }
        .supportedFamilies([.systemSmall])
        .configurationDisplayName("Waktu Aura Mini")
        .description("Square visual widget for the upcoming prayer.")
        .contentMarginsDisabled()
    }
}
