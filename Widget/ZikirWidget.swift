import SwiftUI
import WidgetKit
#if os(iOS)
import UIKit
#endif

private struct ZikirEntry: TimelineEntry {
    let date: Date
    let helperTitle: String
    let phraseArabic: String
    let translation: String
    let accessibilityLabel: String
}

private struct ZikirProvider: TimelineProvider {
    private let store = UserDefaults(suiteName: sharedAppGroupID)

    func placeholder(in context: Context) -> ZikirEntry {
        previewEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (ZikirEntry) -> Void) {
        completion(context.isPreview ? previewEntry() : makeEntry(surface: surface(for: context.family)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZikirEntry>) -> Void) {
        let surface = surface(for: context.family)
        let result = makeSelectionResult(surface: surface, now: Date())
        let entry = ZikirEntry(
            date: result.slotStart,
            helperTitle: result.helperTitle,
            phraseArabic: result.phrase.textArabic,
            translation: result.phrase.localizedTranslation(),
            accessibilityLabel: result.accessibilityLabel
        )
        completion(Timeline(entries: [entry], policy: .after(result.refreshDate)))
    }

    private func makeEntry(surface: ZikirSelectionContext.Surface) -> ZikirEntry {
        let result = makeSelectionResult(surface: surface, now: Date())
        return ZikirEntry(
            date: result.slotStart,
            helperTitle: result.helperTitle,
            phraseArabic: result.phrase.textArabic,
            translation: result.phrase.localizedTranslation(),
            accessibilityLabel: result.accessibilityLabel
        )
    }

    private func makeSelectionResult(surface: ZikirSelectionContext.Surface, now: Date) -> ZikirSelectionResult {
        let prayers = loadPrayers()
        return ZikirSelector.select(
            for: .init(
                date: now,
                prayers: prayers,
                surface: surface
            )
        )
    }

    private func loadPrayers() -> [Prayer] {
        guard
            let data = store?.data(forKey: "prayersData"),
            let decoded = try? Settings.decoder.decode(Prayers.self, from: data)
        else {
            return []
        }
        return decoded.fullPrayers.isEmpty ? decoded.prayers : decoded.fullPrayers
    }

    private func surface(for family: WidgetFamily) -> ZikirSelectionContext.Surface {
        switch family {
        case .accessoryRectangular:
            return .lockScreenWidget
        default:
            return .widget
        }
    }

    private func previewEntry() -> ZikirEntry {
        let phrase = ZikirLibrary.all.first { $0.id == "morning-la-ilaha" }
            ?? ZikirLibrary.all[0]
        let helper = phrase.localizedHelperTitles().first ?? appLocalized("Morning Zikir")
        let translation = phrase.localizedTranslation()
        return ZikirEntry(
            date: Date(),
            helperTitle: helper,
            phraseArabic: phrase.textArabic,
            translation: translation,
            accessibilityLabel: "\(helper). \(phrase.textArabic). \(translation)"
        )
    }
}

private struct ZikirEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ZikirEntry

    private var zikirAlignment: WidgetZikirAlignment {
        guard
            let rawValue = UserDefaults(suiteName: sharedAppGroupID)?.string(forKey: WidgetZikirAlignment.storageKey),
            let alignment = WidgetZikirAlignment(rawValue: rawValue)
        else {
            return .center
        }
        return alignment
    }

    private var horizontalAlignment: HorizontalAlignment {
        zikirAlignment == .leading ? .leading : .center
    }

    private var textAlignment: TextAlignment {
        zikirAlignment == .leading ? .leading : .center
    }

    private var frameAlignment: Alignment {
        zikirAlignment == .leading ? .leading : .center
    }

    private var arabicFontName: String {
        let stored = UserDefaults(suiteName: sharedAppGroupID)?.string(forKey: "fontArabic") ?? ""
        let candidates = [
            stored,
            "KFGQPCUthmanicScriptHAFS",
            "Uthmani",
            "KFGQPC Uthmanic Script HAFS",
            "UthmanicHafs1 Ver09",
            "AmiriQuran-Regular",
            "Amiri Quran"
        ]
        #if os(iOS)
        for name in candidates where !name.isEmpty {
            if UIFont(name: name, size: 20) != nil {
                return name
            }
        }
        #endif
        return stored.isEmpty ? "KFGQPCUthmanicScriptHAFS" : stored
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: horizontalAlignment, spacing: 3) {
                Text(entry.helperTitle)
                    .font(.system(size: 10, weight: .medium, design: .default))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                Text(entry.phraseArabic)
                    .font(.custom(arabicFontName, size: 19))
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .environment(\.layoutDirection, .rightToLeft)
                Text(entry.translation)
                    .font(.system(size: 10, weight: .regular, design: .default))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(entry.accessibilityLabel)
        default:
            VStack(alignment: horizontalAlignment, spacing: 8) {
                Text(entry.helperTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(entry.phraseArabic)
                    .font(.custom(arabicFontName, size: 28))
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .lineLimit(3)
                    .minimumScaleFactor(0.65)
                    .environment(\.layoutDirection, .rightToLeft)
                Text(entry.translation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(entry.accessibilityLabel)
        }
    }
}

struct ZikirWidget: Widget {
    let kind = "ZikirWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZikirProvider()) { entry in
            if #available(iOS 17.0, *) {
                ZikirEntryView(entry: entry)
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                ZikirEntryView(entry: entry)
            }
        }
        .supportedFamilies([.systemSmall])
        .configurationDisplayName("Zikir & Selawat")
        .description("Short Arabic adhkar that rotate gently through the day.")
    }
}

@available(iOSApplicationExtension 16.0, *)
struct LockScreenZikirWidget: Widget {
    let kind = "LockScreenZikirWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZikirProvider()) { entry in
            if #available(iOS 17.0, *) {
                ZikirEntryView(entry: entry)
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                ZikirEntryView(entry: entry)
            }
        }
        .supportedFamilies([.accessoryRectangular])
        .configurationDisplayName("Zikir & Selawat")
        .description("Short Arabic adhkar for your Lock Screen.")
    }
}
