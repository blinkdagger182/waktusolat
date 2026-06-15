import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
struct ConfigurableHomeWidgetEntry: TimelineEntry {
    let date: Date
    let prayersEntry: PrayersEntry
    let configuredSlot: HomeWidgetPresetSlot?
}

@available(iOS 17.0, *)
struct ConfigurableHomeWidgetProvider<Configuration: HomeWidgetPresetConfigurationIntent>: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ConfigurableHomeWidgetEntry {
        ConfigurableHomeWidgetEntry(
            date: Date(),
            prayersEntry: PrayersProvider().placeholder(in: context),
            configuredSlot: Configuration().preset?.slot
        )
    }

    func snapshot(
        for configuration: Configuration,
        in context: Context
    ) async -> ConfigurableHomeWidgetEntry {
        let entry = await prayersSnapshot(in: context)
        return ConfigurableHomeWidgetEntry(date: entry.date, prayersEntry: entry, configuredSlot: configuration.preset?.slot)
    }

    func timeline(
        for configuration: Configuration,
        in context: Context
    ) async -> Timeline<ConfigurableHomeWidgetEntry> {
        let timeline = await prayersTimeline(in: context)
        let entries = timeline.entries.map {
            ConfigurableHomeWidgetEntry(date: $0.date, prayersEntry: $0, configuredSlot: configuration.preset?.slot)
        }
        return Timeline(entries: entries, policy: timeline.policy)
    }

    private func prayersSnapshot(in context: Context) async -> PrayersEntry {
        await withCheckedContinuation { continuation in
            PrayersProvider().getSnapshot(in: context) { entry in
                continuation.resume(returning: entry)
            }
        }
    }

    private func prayersTimeline(in context: Context) async -> Timeline<PrayersEntry> {
        await withCheckedContinuation { continuation in
            PrayersProvider().getTimeline(in: context) { timeline in
                continuation.resume(returning: timeline)
            }
        }
    }
}

@available(iOS 17.0, *)
struct ConfigurableHomeWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ConfigurableHomeWidgetEntry

    private var effectiveSlot: HomeWidgetPresetSlot {
        let configuredSlot = entry.configuredSlot ?? HomeWidgetPresetSlot.slots(for: effectiveSize).first ?? .small1
        guard configuredSlot.size == effectiveSize else {
            return HomeWidgetPresetSlot.slots(for: effectiveSize).first ?? .small1
        }
        return configuredSlot
    }

    private var effectiveSize: HomeWidgetPresetSize {
        switch family {
        case .systemMedium:
            return .medium
        case .systemLarge:
            return .large
        default:
            return .small
        }
    }

    private var style: HomeWidgetStyle {
        HomeWidgetPresetStore.style(for: effectiveSlot)
    }

    var body: some View {
        Group {
            switch style {
            case .simpleCountdown:
                SimpleEntryView(entry: entry.prayersEntry)
                    .padding(widgetContentPadding)
            case .countdown, .countdownMedium, .countdownLarge:
                CountdownEntryView(entry: entry.prayersEntry)
                    .padding(widgetContentPadding)
            case .prayerTimesCompact:
                Prayers2EntryView(entry: entry.prayersEntry)
                    .padding(widgetContentPadding)
            case .prayerTimesGrid, .prayerTimesLarge:
                PrayersEntryView(entry: entry.prayersEntry)
                    .padding(widgetContentPadding)
            case .minimalist:
                MinimalistWaktuEntryView(entry: entry.prayersEntry)
            case .metro:
                metroView
            case .neo:
                neoView
            case .sketch:
                sketchView
            case .proNext:
                ProNextEntryView(entry: entry.prayersEntry)
            case .proIndex:
                ProIndexEntryView(entry: entry.prayersEntry)
            case .proArc:
                ProArcEntryView(entry: entry.prayersEntry)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var metroView: some View {
        switch effectiveSize {
        case .small:
            MetroSmallView(entry: entry.prayersEntry)
        case .medium:
            MetroMediumView(entry: entry.prayersEntry)
        case .large:
            MetroLargeView(entry: entry.prayersEntry)
        }
    }

    @ViewBuilder
    private var neoView: some View {
        switch effectiveSize {
        case .small:
            NeoSmallView(entry: entry.prayersEntry)
        case .medium:
            NeoMediumView(entry: entry.prayersEntry)
        case .large:
            NeoLargeView(entry: entry.prayersEntry)
        }
    }

    @ViewBuilder
    private var sketchView: some View {
        switch effectiveSize {
        case .small:
            SketchSmallView(entry: entry.prayersEntry)
        case .medium:
            SketchMediumView(entry: entry.prayersEntry)
        case .large:
            SketchLargeView(entry: entry.prayersEntry)
        }
    }

    private var widgetContentPadding: CGFloat {
        switch effectiveSize {
        case .small:
            return 14
        case .medium:
            return 16
        case .large:
            return 18
        }
    }
}

@available(iOS 17.0, *)
struct FixedHomeWidgetProvider: TimelineProvider {
    let slot: HomeWidgetPresetSlot

    func placeholder(in context: Context) -> ConfigurableHomeWidgetEntry {
        ConfigurableHomeWidgetEntry(
            date: Date(),
            prayersEntry: PrayersProvider().placeholder(in: context),
            configuredSlot: slot
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ConfigurableHomeWidgetEntry) -> Void) {
        PrayersProvider().getSnapshot(in: context) { entry in
            completion(ConfigurableHomeWidgetEntry(date: entry.date, prayersEntry: entry, configuredSlot: slot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ConfigurableHomeWidgetEntry>) -> Void) {
        PrayersProvider().getTimeline(in: context) { timeline in
            let entries = timeline.entries.map {
                ConfigurableHomeWidgetEntry(date: $0.date, prayersEntry: $0, configuredSlot: slot)
            }
            completion(Timeline(entries: entries, policy: timeline.policy))
        }
    }
}

@available(iOS 17.0, *)
private struct FixedHomePresetConfiguration {
    let slot: HomeWidgetPresetSlot

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HomeWidgetPreset.\(slot.rawValue)", provider: FixedHomeWidgetProvider(slot: slot)) { entry in
            ConfigurableHomeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .supportedFamilies([widgetFamily])
        .configurationDisplayName("Waktu \(slot.title)")
        .description("Uses the \(slot.title) style selected in the Waktu app.")
        .contentMarginsDisabled()
    }

    private var widgetFamily: WidgetFamily {
        switch slot.size {
        case .small:
            return .systemSmall
        case .medium:
            return .systemMedium
        case .large:
            return .systemLarge
        }
    }
}

@available(iOS 17.0, *)
struct SmallPresetOneWidget: Widget {
    var body: some WidgetConfiguration {
        FixedHomePresetConfiguration(slot: .small1).body
    }
}

@available(iOS 17.0, *)
struct SmallPresetTwoWidget: Widget {
    var body: some WidgetConfiguration {
        FixedHomePresetConfiguration(slot: .small2).body
    }
}

@available(iOS 17.0, *)
struct MediumPresetOneWidget: Widget {
    var body: some WidgetConfiguration {
        FixedHomePresetConfiguration(slot: .medium1).body
    }
}

@available(iOS 17.0, *)
struct MediumPresetTwoWidget: Widget {
    var body: some WidgetConfiguration {
        FixedHomePresetConfiguration(slot: .medium2).body
    }
}

@available(iOS 17.0, *)
struct MediumPresetThreeWidget: Widget {
    var body: some WidgetConfiguration {
        FixedHomePresetConfiguration(slot: .medium3).body
    }
}

@available(iOS 17.0, *)
struct LargePresetOneWidget: Widget {
    var body: some WidgetConfiguration {
        FixedHomePresetConfiguration(slot: .large1).body
    }
}

@available(iOS 17.0, *)
struct LargePresetTwoWidget: Widget {
    var body: some WidgetConfiguration {
        FixedHomePresetConfiguration(slot: .large2).body
    }
}

@available(iOS 17.0, *)
struct SmallConfigurableHomeWidget: Widget {
    let kind = "SmallConfigurableHomeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SmallHomeWidgetConfigurationIntent.self,
            provider: ConfigurableHomeWidgetProvider<SmallHomeWidgetConfigurationIntent>()
        ) { entry in
            ConfigurableHomeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .supportedFamilies([.systemSmall])
        .configurationDisplayName("Waktu Small")
        .description("Choose a saved small Waktu widget preset and customize it in the app.")
        .contentMarginsDisabled()
    }
}

@available(iOS 17.0, *)
struct MediumConfigurableHomeWidget: Widget {
    let kind = "MediumConfigurableHomeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: MediumHomeWidgetConfigurationIntent.self,
            provider: ConfigurableHomeWidgetProvider<MediumHomeWidgetConfigurationIntent>()
        ) { entry in
            ConfigurableHomeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("Waktu Medium")
        .description("Choose a saved medium Waktu widget preset and customize it in the app.")
        .contentMarginsDisabled()
    }
}

@available(iOS 17.0, *)
struct LargeConfigurableHomeWidget: Widget {
    let kind = "LargeConfigurableHomeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: LargeHomeWidgetConfigurationIntent.self,
            provider: ConfigurableHomeWidgetProvider<LargeHomeWidgetConfigurationIntent>()
        ) { entry in
            ConfigurableHomeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .supportedFamilies([.systemLarge])
        .configurationDisplayName("Waktu Large")
        .description("Choose a saved large Waktu widget preset and customize it in the app.")
        .contentMarginsDisabled()
    }
}
