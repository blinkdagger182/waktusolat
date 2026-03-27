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
        switch zikirAlignment {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        case .center, .centerAmiri:
            return .center
        }
    }

    private var textAlignment: TextAlignment {
        switch zikirAlignment {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        case .center, .centerAmiri:
            return .center
        }
    }

    private var frameAlignment: Alignment {
        switch zikirAlignment {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        case .center, .centerAmiri:
            return .center
        }
    }

    private var arabicFontName: String {
        if zikirAlignment == .centerAmiri {
            let amiriCandidates = [
                "AmiriQuran-Regular",
                "Amiri Quran",
                "Amiri-Regular",
                "Amiri"
            ]
            #if os(iOS)
            for name in amiriCandidates where !name.isEmpty {
                if UIFont(name: name, size: 20) != nil {
                    return name
                }
            }
            #endif
        }
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

    private var supportingTextFont: Font {
        if zikirAlignment == .centerAmiri {
            return .system(size: 10, weight: .regular, design: .serif)
        }
        return .system(size: 10, weight: .regular, design: .default)
    }

    private var supportingCaptionFont: Font {
        if zikirAlignment == .centerAmiri {
            return .system(.caption, design: .serif)
        }
        return .system(.caption, design: .default)
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: horizontalAlignment, spacing: 3) {
                Text(entry.helperTitle)
                    .font(zikirAlignment == .centerAmiri ? .system(size: 10, weight: .medium, design: .serif) : .system(size: 10, weight: .medium, design: .default))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .multilineTextAlignment(textAlignment)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.phraseArabic)
                    .font(.custom(arabicFontName, size: 19))
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.translation)
                    .font(supportingTextFont)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(entry.accessibilityLabel)
        default:
            VStack(alignment: horizontalAlignment, spacing: 8) {
                Text(entry.helperTitle)
                    .font(zikirAlignment == .centerAmiri ? .system(.caption, design: .serif).weight(.medium) : .caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(textAlignment)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.phraseArabic)
                    .font(.custom(arabicFontName, size: 28))
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.translation)
                    .font(supportingCaptionFont)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
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
