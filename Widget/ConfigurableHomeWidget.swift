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
struct SmallPresetOneWidget: Widget {
    let kind = "HomeWidgetPresetSmall1"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FixedHomeWidgetProvider(slot: .small1)) { entry in
            ConfigurableHomeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .supportedFamilies([.systemSmall])
        .configurationDisplayName("Waktu Small #1")
        .description("Uses the Small #1 style selected in the Waktu app.")
        .contentMarginsDisabled()
    }
}

@available(iOS 17.0, *)
struct SmallPresetTwoWidget: Widget {
    let kind = "HomeWidgetPresetSmall2"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FixedHomeWidgetProvider(slot: .small2)) { entry in
            ConfigurableHomeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .supportedFamilies([.systemSmall])
        .configurationDisplayName("Waktu Small #2")
        .description("Uses the Small #2 style selected in the Waktu app.")
        .contentMarginsDisabled()
    }
}

@available(iOS 17.0, *)
struct MediumPresetOneWidget: Widget {
    let kind = "HomeWidgetPresetMedium1"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FixedHomeWidgetProvider(slot: .medium1)) { entry in
            ConfigurableHomeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("Waktu Medium #1")
        .description("Uses the Medium #1 style selected in the Waktu app.")
        .contentMarginsDisabled()
    }
}

@available(iOS 17.0, *)
struct MediumPresetTwoWidget: Widget {
    let kind = "HomeWidgetPresetMedium2"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FixedHomeWidgetProvider(slot: .medium2)) { entry in
            ConfigurableHomeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("Waktu Medium #2")
        .description("Uses the Medium #2 style selected in the Waktu app.")
        .contentMarginsDisabled()
    }
}

@available(iOS 17.0, *)
struct MediumPresetThreeWidget: Widget {
    let kind = "HomeWidgetPresetMedium3"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FixedHomeWidgetProvider(slot: .medium3)) { entry in
            ConfigurableHomeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("Waktu Medium #3")
        .description("Uses the Medium #3 style selected in the Waktu app.")
        .contentMarginsDisabled()
    }
}

@available(iOS 17.0, *)
struct LargePresetOneWidget: Widget {
    let kind = "HomeWidgetPresetLarge1"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FixedHomeWidgetProvider(slot: .large1)) { entry in
            ConfigurableHomeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .supportedFamilies([.systemLarge])
        .configurationDisplayName("Waktu Large #1")
        .description("Uses the Large #1 style selected in the Waktu app.")
        .contentMarginsDisabled()
    }
}

@available(iOS 17.0, *)
struct LargePresetTwoWidget: Widget {
    let kind = "HomeWidgetPresetLarge2"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FixedHomeWidgetProvider(slot: .large2)) { entry in
            ConfigurableHomeWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .supportedFamilies([.systemLarge])
        .configurationDisplayName("Waktu Large #2")
        .description("Uses the Large #2 style selected in the Waktu app.")
        .contentMarginsDisabled()
    }
}
