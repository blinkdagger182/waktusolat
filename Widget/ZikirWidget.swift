import AppIntents
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
                surface: surface,
                includeFridayBoostsOverride: nil
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

@available(iOS 17.0, *)
private struct TasbihCounterEntry: TimelineEntry {
    let date: Date
    let counts: [String: Int]
    let theme: TasbihCounterTheme

    var activeItem: TasbihCounterItem {
        TasbihCounterStore.items.first { count(for: $0) < $0.target } ?? TasbihCounterStore.items.last!
    }

    func count(for item: TasbihCounterItem) -> Int {
        min(max(counts[item.id] ?? 0, 0), item.target)
    }
}

@available(iOS 17.0, *)
private struct TasbihCounterProvider: TimelineProvider {
    func placeholder(in context: Context) -> TasbihCounterEntry {
        TasbihCounterEntry(
            date: Date(),
            counts: [
                "subhanAllah": 17,
                "alhamdulillah": 0,
                "allahuAkbar": 0,
            ],
            theme: .gold
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TasbihCounterEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TasbihCounterEntry>) -> Void) {
        completion(Timeline(entries: [makeEntry()], policy: .never))
    }

    private func makeEntry() -> TasbihCounterEntry {
        TasbihCounterEntry(date: Date(), counts: TasbihCounterStore.counts(), theme: TasbihCounterStore.theme())
    }
}

@available(iOS 17.0, *)
private struct TasbihCounterEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: TasbihCounterEntry

    private var palette: TasbihCounterPalette {
        TasbihCounterPalette(theme: entry.theme)
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumLayout
            default:
                smallLayout
            }
        }
        .containerBackground(for: .widget) {
            palette.background
        }
        .widgetAccentable(false)
    }

    private var smallLayout: some View {
        let item = entry.activeItem
        let count = entry.count(for: item)

        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text("\(count) / \(item.target)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            ProgressView(value: Double(count), total: Double(item.target))
                .tint(palette.accent)
                .scaleEffect(x: 1, y: 1.4, anchor: .center)

            Spacer(minLength: 0)

            Button(intent: IncrementTasbihCounterIntent()) {
                Text("+1")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.accent)
            .foregroundStyle(palette.buttonText)
        }
        .padding(16)
    }

    private var mediumLayout: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Morning Dhikr")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(1)

                    Text("Tasbih, Tahmid, Takbir")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }

                VStack(spacing: 6) {
                    ForEach(TasbihCounterStore.items) { item in
                        TasbihCounterRow(
                            title: item.title,
                            count: entry.count(for: item),
                            target: item.target,
                            active: item.id == entry.activeItem.id,
                            palette: palette
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                Text(totalProgressText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.accent)
                    .monospacedDigit()
                    .lineLimit(1)

                Button(intent: IncrementTasbihCounterIntent()) {
                    Text("+1")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .frame(width: 74, height: 46)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
                .foregroundStyle(palette.buttonText)

                Button(intent: ResetTasbihCounterIntent()) {
                    Text("Reset")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .frame(width: 74, height: 32)
                }
                .buttonStyle(.bordered)
                .tint(palette.primaryText.opacity(0.82))
            }
            .frame(minWidth: 82, idealWidth: 82, maxWidth: 82, maxHeight: .infinity)
        }
        .padding(16)
    }

    private var totalProgressText: String {
        let completed = TasbihCounterStore.items.reduce(0) { $0 + entry.count(for: $1) }
        let total = TasbihCounterStore.items.reduce(0) { $0 + $1.target }
        return "\(completed)/\(total)"
    }
}

@available(iOS 17.0, *)
private struct TasbihCounterRow: View {
    let title: String
    let count: Int
    let target: Int
    let active: Bool
    let palette: TasbihCounterPalette

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(active ? palette.accent : palette.primaryText.opacity(0.16))
                .frame(width: 4)

            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: active ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(active ? palette.primaryText : palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 8)

                Text("\(count)/\(target)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(active ? palette.accent : palette.secondaryText)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(active ? palette.rowActiveBackground : palette.rowBackground)
        )
    }
}

@available(iOS 17.0, *)
private struct TasbihCounterPalette {
    let theme: TasbihCounterTheme

    var background: LinearGradient {
        switch theme {
        case .gold:
            return LinearGradient(
                colors: [Color(red: 0.06, green: 0.07, blue: 0.06), Color(red: 0.10, green: 0.12, blue: 0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dawn:
            return LinearGradient(
                colors: [Color(red: 0.94, green: 0.91, blue: 0.82), Color(red: 0.78, green: 0.88, blue: 0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .slate:
            return LinearGradient(
                colors: [Color(red: 0.08, green: 0.10, blue: 0.13), Color(red: 0.14, green: 0.18, blue: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var accent: Color {
        switch theme {
        case .gold:
            return Color(red: 0.83, green: 0.72, blue: 0.42)
        case .dawn:
            return Color(red: 0.10, green: 0.38, blue: 0.48)
        case .slate:
            return Color(red: 0.40, green: 0.68, blue: 0.92)
        }
    }

    var primaryText: Color {
        theme == .dawn ? .black : .white
    }

    var secondaryText: Color {
        primaryText.opacity(theme == .dawn ? 0.62 : 0.60)
    }

    var buttonText: Color {
        theme == .slate ? .black : (theme == .dawn ? .white : .black)
    }

    var rowBackground: Color {
        primaryText.opacity(theme == .dawn ? 0.12 : 0.045)
    }

    var rowActiveBackground: Color {
        primaryText.opacity(theme == .dawn ? 0.20 : 0.10)
    }
}

@available(iOS 17.0, *)
struct TasbihCounterWidget: Widget {
    let kind = TasbihCounterStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TasbihCounterProvider()) { entry in
            TasbihCounterEntryView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemMedium])
        .configurationDisplayName("Tasbih Counter")
        .description("Count morning dhikr directly from the widget.")
        .contentMarginsDisabled()
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

// ─────────────────────────────────────────────────────────────
// MARK: - 04 · Zikir Pro  (systemMedium)
// ─────────────────────────────────────────────────────────────

private let pzGold      = Color(red: 201 / 255, green: 162 / 255, blue: 75 / 255)
private let pzInk       = Color(red: 10 / 255,  green: 10 / 255,  blue: 11 / 255)
private let pzTextMain  = Color(red: 242 / 255, green: 241 / 255, blue: 238 / 255)
private let pzTextDim   = Color(red: 140 / 255, green: 140 / 255, blue: 146 / 255)
private let pzTextFaint = Color(red: 90 / 255,  green: 90 / 255,  blue: 96 / 255)

private struct ProZikirLockedView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.title3)
                .foregroundStyle(pzGold)
            Text("Waktu Pro")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(pzGold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ProZikirEntryView: View {
    let entry: ZikirEntry

    private func arabicFont(size: CGFloat) -> Font {
        #if os(iOS)
        let candidates = [
            "KFGQPCUthmanicScriptHAFS",
            "UthmanicHafs1 Ver09",
            "AmiriQuran-Regular",
            "Amiri-Regular",
        ]
        for name in candidates {
            if UIFont(name: name, size: size) != nil {
                return .custom(name, size: size)
            }
        }
        #endif
        return .system(size: size, weight: .light, design: .serif)
    }

    var body: some View {
        ZStack {
            pzInk
            if !premiumWidgetsUnlocked() {
                ProZikirLockedView()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.helperTitle.uppercased())
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(pzTextFaint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 6)

                    Text(entry.phraseArabic)
                        .font(arabicFont(size: 28))
                        .foregroundStyle(pzTextMain)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .environment(\.layoutDirection, .rightToLeft)

                    Spacer(minLength: 6)

                    Text(entry.translation)
                        .font(.system(size: 12, weight: .regular, design: .default).italic())
                        .foregroundStyle(pzTextDim)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
                .padding(20)
            }
        }
    }
}

struct ProZikirWidget: Widget {
    let kind = "ProZikirWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZikirProvider()) { entry in
            if #available(iOS 17.0, *) {
                ProZikirEntryView(entry: entry)
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                ProZikirEntryView(entry: entry)
            }
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("Zikir — Pro")
        .description("Arabic adhkar with translation, medium canvas.")
    }
}
