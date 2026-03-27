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
        return alignment.resolvedForWidgetAccess
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
        let size = compactSupportingTextSize
        if zikirAlignment == .centerAmiri {
            return .system(size: size, weight: .regular, design: .serif)
        }
        return .system(size: size, weight: .regular, design: .default)
    }

    private var supportingCaptionFont: Font {
        let size = compactCaptionSize
        if zikirAlignment == .centerAmiri {
            return .system(size: size, weight: .regular, design: .serif)
        }
        return .system(size: size, weight: .regular, design: .default)
    }

    private var contentDensityScore: Int {
        entry.helperTitle.count + entry.phraseArabic.count + entry.translation.count
    }

    private var lockScreenArabicFontSize: CGFloat {
        let arabicLength = entry.phraseArabic.count
        switch (arabicLength, contentDensityScore) {
        case let (length, score) where length > 65 || score > 220:
            return 11
        case let (length, score) where length > 55 || score > 190:
            return 12
        case let (length, score) where length > 45 || score > 165:
            return 13
        case let (length, score) where length > 35 || score > 135:
            return 14.5
        default:
            return 16
        }
    }

    private var widgetArabicFontSize: CGFloat {
        let arabicLength = entry.phraseArabic.count
        switch (arabicLength, contentDensityScore) {
        case let (length, score) where length > 65 || score > 220:
            return 16
        case let (length, score) where length > 55 || score > 190:
            return 18
        case let (length, score) where length > 45 || score > 165:
            return 20
        case let (length, score) where length > 35 || score > 135:
            return 22
        default:
            return 24
        }
    }

    private var compactSupportingTextSize: CGFloat {
        switch contentDensityScore {
        case 191...:
            return 8
        case 151...190:
            return 8.5
        case 121...150:
            return 9
        default:
            return 10
        }
    }

    private var compactCaptionSize: CGFloat {
        switch contentDensityScore {
        case 191...:
            return 9
        case 151...190:
            return 10
        case 121...150:
            return 11
        default:
            return 12
        }
    }

    @ViewBuilder
    private func zikirStack(
        helperSize: CGFloat,
        arabicSize: CGFloat,
        translationSize: CGFloat,
        spacing: CGFloat,
        lineSpacing: CGFloat,
        helperLimit: Int,
        translationLimit: Int
    ) -> some View {
        VStack(alignment: horizontalAlignment, spacing: spacing) {
            Text(entry.helperTitle)
                .font(
                    zikirAlignment == .centerAmiri
                        ? .system(size: helperSize, weight: .medium, design: .serif)
                        : .system(size: helperSize, weight: .medium, design: .default)
                )
                .foregroundStyle(.secondary)
                .multilineTextAlignment(textAlignment)
                .lineLimit(helperLimit)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .layoutPriority(3)

            Text(entry.phraseArabic)
                .font(.custom(arabicFontName, size: arabicSize))
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .lineLimit(nil)
                .minimumScaleFactor(0.55)
                .lineSpacing(lineSpacing)
                .layoutPriority(1)

            Text(entry.translation)
                .font(
                    zikirAlignment == .centerAmiri
                        ? .system(size: translationSize, weight: .regular, design: .serif)
                        : .system(size: translationSize, weight: .regular, design: .default)
                )
                .foregroundStyle(.secondary)
                .multilineTextAlignment(textAlignment)
                .lineLimit(translationLimit)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .layoutPriority(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            Group {
                if #available(iOSApplicationExtension 16.0, *) {
                    ViewThatFits(in: .vertical) {
                        zikirStack(
                            helperSize: compactSupportingTextSize,
                            arabicSize: lockScreenArabicFontSize,
                            translationSize: compactSupportingTextSize,
                            spacing: 3,
                            lineSpacing: 0.5,
                            helperLimit: 2,
                            translationLimit: 2
                        )
                        zikirStack(
                            helperSize: max(compactSupportingTextSize - 0.5, 7),
                            arabicSize: max(lockScreenArabicFontSize - 2, 10),
                            translationSize: max(compactSupportingTextSize - 0.5, 7),
                            spacing: 2,
                            lineSpacing: 0.25,
                            helperLimit: 2,
                            translationLimit: 2
                        )
                        zikirStack(
                            helperSize: 7,
                            arabicSize: 10,
                            translationSize: 7,
                            spacing: 1.5,
                            lineSpacing: 0,
                            helperLimit: 1,
                            translationLimit: 2
                        )
                    }
                } else {
                    zikirStack(
                        helperSize: max(compactSupportingTextSize - 0.5, 7),
                        arabicSize: max(lockScreenArabicFontSize - 2, 10),
                        translationSize: max(compactSupportingTextSize - 0.5, 7),
                        spacing: 2,
                        lineSpacing: 0.25,
                        helperLimit: 2,
                        translationLimit: 2
                    )
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(entry.accessibilityLabel)
        default:
            Group {
                if #available(iOSApplicationExtension 16.0, *) {
                    ViewThatFits(in: .vertical) {
                        zikirStack(
                            helperSize: compactCaptionSize,
                            arabicSize: widgetArabicFontSize,
                            translationSize: compactCaptionSize,
                            spacing: 6,
                            lineSpacing: 0.5,
                            helperLimit: 2,
                            translationLimit: 3
                        )
                        zikirStack(
                            helperSize: max(compactCaptionSize - 1, 8),
                            arabicSize: max(widgetArabicFontSize - 3, 14),
                            translationSize: max(compactCaptionSize - 1, 8),
                            spacing: 4,
                            lineSpacing: 0.25,
                            helperLimit: 2,
                            translationLimit: 2
                        )
                        zikirStack(
                            helperSize: 8,
                            arabicSize: 14,
                            translationSize: 8,
                            spacing: 3,
                            lineSpacing: 0,
                            helperLimit: 1,
                            translationLimit: 2
                        )
                    }
                } else {
                    zikirStack(
                        helperSize: max(compactCaptionSize - 1, 8),
                        arabicSize: max(widgetArabicFontSize - 3, 14),
                        translationSize: max(compactCaptionSize - 1, 8),
                        spacing: 4,
                        lineSpacing: 0.25,
                        helperLimit: 2,
                        translationLimit: 2
                    )
                }
            }
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
