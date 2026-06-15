import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
struct ConfigurableHomeWidgetEntry: TimelineEntry {
    let date: Date
    let prayersEntry: PrayersEntry
    let configuration: HomeWidgetConfigurationIntent
}

@available(iOS 17.0, *)
struct ConfigurableHomeWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ConfigurableHomeWidgetEntry {
        ConfigurableHomeWidgetEntry(
            date: Date(),
            prayersEntry: PrayersProvider().placeholder(in: context),
            configuration: HomeWidgetConfigurationIntent()
        )
    }

    func snapshot(
        for configuration: HomeWidgetConfigurationIntent,
        in context: Context
    ) async -> ConfigurableHomeWidgetEntry {
        let entry = await prayersSnapshot(in: context)
        return ConfigurableHomeWidgetEntry(date: entry.date, prayersEntry: entry, configuration: configuration)
    }

    func timeline(
        for configuration: HomeWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<ConfigurableHomeWidgetEntry> {
        let timeline = await prayersTimeline(in: context)
        let entries = timeline.entries.map {
            ConfigurableHomeWidgetEntry(date: $0.date, prayersEntry: $0, configuration: configuration)
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
        let configuredSlot = entry.configuration.preset.slot
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
struct ConfigurableHomeWidget: Widget {
    let kind = "ConfigurableHomeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: HomeWidgetConfigurationIntent.self,
            provider: ConfigurableHomeWidgetProvider()
        ) { entry in
            ConfigurableHomeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .configurationDisplayName("Waktu")
        .description("Choose a saved Waktu widget preset and customize it in the app.")
        .contentMarginsDisabled()
    }
}
