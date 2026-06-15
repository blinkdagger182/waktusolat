import AppIntents
import WidgetKit

struct TasbihCounterItem: Identifiable {
    let id: String
    let title: String
    let target: Int
}

enum TasbihCounterStore {
    static let widgetKind = "TasbihCounterWidget"
    static let items: [TasbihCounterItem] = [
        TasbihCounterItem(id: "subhanAllah", title: "SubhanAllah", target: 33),
        TasbihCounterItem(id: "alhamdulillah", title: "Alhamdulillah", target: 33),
        TasbihCounterItem(id: "allahuAkbar", title: "Allahu Akbar", target: 34),
    ]

    private static let keyPrefix = "tasbihCounterWidget"

    static func count(for item: TasbihCounterItem, defaults: UserDefaults? = UserDefaults(suiteName: sharedAppGroupID)) -> Int {
        guard let defaults else { return 0 }
        return min(max(defaults.integer(forKey: storageKey(for: item)), 0), item.target)
    }

    static func counts(defaults: UserDefaults? = UserDefaults(suiteName: sharedAppGroupID)) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: items.map { ($0.id, count(for: $0, defaults: defaults)) })
    }

    static func activeItem(defaults: UserDefaults? = UserDefaults(suiteName: sharedAppGroupID)) -> TasbihCounterItem {
        items.first { count(for: $0, defaults: defaults) < $0.target } ?? items.last ?? TasbihCounterItem(id: "subhanAllah", title: "SubhanAllah", target: 33)
    }

    static func increment(defaults: UserDefaults? = UserDefaults(suiteName: sharedAppGroupID)) {
        guard let defaults else { return }
        let item = activeItem(defaults: defaults)
        let nextCount = min(count(for: item, defaults: defaults) + 1, item.target)
        defaults.set(nextCount, forKey: storageKey(for: item))
    }

    static func reset(defaults: UserDefaults? = UserDefaults(suiteName: sharedAppGroupID)) {
        guard let defaults else { return }
        for item in items {
            defaults.set(0, forKey: storageKey(for: item))
        }
    }

    private static func storageKey(for item: TasbihCounterItem) -> String {
        "\(keyPrefix).\(item.id).count"
    }
}

@available(iOS 17.0, *)
struct IncrementTasbihCounterIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Tasbih Count"
    static var description = IntentDescription("Adds one count to the active tasbih phrase.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        TasbihCounterStore.increment()
        WidgetCenter.shared.reloadTimelines(ofKind: TasbihCounterStore.widgetKind)
        return .result()
    }
}

@available(iOS 17.0, *)
struct ResetTasbihCounterIntent: AppIntent {
    static var title: LocalizedStringResource = "Reset Tasbih Counter"
    static var description = IntentDescription("Resets the tasbih counter widget.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        TasbihCounterStore.reset()
        WidgetCenter.shared.reloadTimelines(ofKind: TasbihCounterStore.widgetKind)
        return .result()
    }
}

enum HomeWidgetPresetSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small:
            return isMalayAppLanguage() ? "Kecil" : "Small"
        case .medium:
            return isMalayAppLanguage() ? "Sederhana" : "Medium"
        case .large:
            return isMalayAppLanguage() ? "Besar" : "Large"
        }
    }
}

enum HomeWidgetPresetSlot: String, CaseIterable, Identifiable {
    case small1
    case small2
    case medium1
    case medium2
    case medium3
    case large1
    case large2

    var id: String { rawValue }

    var size: HomeWidgetPresetSize {
        switch self {
        case .small1, .small2:
            return .small
        case .medium1, .medium2, .medium3:
            return .medium
        case .large1, .large2:
            return .large
        }
    }

    var displayIndex: Int {
        switch self {
        case .small1, .medium1, .large1:
            return 1
        case .small2, .medium2, .large2:
            return 2
        case .medium3:
            return 3
        }
    }

    var title: String {
        "\(size.title) #\(displayIndex)"
    }

    static func slots(for size: HomeWidgetPresetSize) -> [HomeWidgetPresetSlot] {
        allCases.filter { $0.size == size }
    }

    func storageKey() -> String {
        "homeWidgetPreset.\(rawValue).style"
    }

    func defaultStyle() -> HomeWidgetStyle {
        switch self {
        case .small1:
            return .simpleCountdown
        case .small2:
            return .countdown
        case .medium1:
            return .prayerTimesCompact
        case .medium2:
            return .countdownMedium
        case .medium3:
            return .minimalist
        case .large1:
            return .prayerTimesLarge
        case .large2:
            return .countdownLarge
        }
    }
}

enum HomeWidgetStyle: String, CaseIterable, Identifiable {
    case simpleCountdown
    case countdown
    case countdownMedium
    case countdownLarge
    case prayerTimesCompact
    case prayerTimesGrid
    case prayerTimesLarge
    case minimalist
    case metro
    case neo
    case sketch
    case proNext
    case proIndex
    case proArc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simpleCountdown:
            return isMalayAppLanguage() ? "Kiraan Detik Ringkas" : "Simple Countdown"
        case .countdown:
            return isMalayAppLanguage() ? "Kiraan Detik Mini" : "Countdown Mini"
        case .countdownMedium:
            return isMalayAppLanguage() ? "Kiraan Detik" : "Countdown"
        case .countdownLarge:
            return isMalayAppLanguage() ? "Kiraan Detik Besar" : "Countdown Max"
        case .prayerTimesCompact:
            return isMalayAppLanguage() ? "Waktu Padat" : "Times Compact"
        case .prayerTimesGrid:
            return isMalayAppLanguage() ? "Waktu Solat" : "Prayer Times"
        case .prayerTimesLarge:
            return isMalayAppLanguage() ? "Waktu Besar" : "Times Max"
        case .minimalist:
            return "Minimalist"
        case .metro:
            return "Metro"
        case .neo:
            return "Neo"
        case .sketch:
            return "Sketch"
        case .proNext:
            return isMalayAppLanguage() ? "Solat Seterusnya Pro" : "Next Pro"
        case .proIndex:
            return isMalayAppLanguage() ? "Indeks Pro" : "Index Pro"
        case .proArc:
            return isMalayAppLanguage() ? "Lengkok Pro" : "Arc Pro"
        }
    }

    var subtitle: String {
        switch self {
        case .simpleCountdown:
            return isMalayAppLanguage() ? "Widget percuma asal yang ringkas." : "Original compact free widget."
        case .countdown:
            return isMalayAppLanguage() ? "Kiraan detik padat untuk widget kecil." : "Compact countdown for small widgets."
        case .countdownMedium, .countdownLarge:
            return isMalayAppLanguage() ? "Graf kecil dan kiraan detik solat seterusnya." : "Mini graph and next-prayer countdown."
        case .prayerTimesCompact:
            return isMalayAppLanguage() ? "Senarai separuh hari dengan kiraan detik." : "Half-day prayer list with countdown."
        case .prayerTimesGrid, .prayerTimesLarge:
            return isMalayAppLanguage() ? "Grid waktu solat lengkap." : "Full prayer-times grid."
        case .minimalist:
            return isMalayAppLanguage() ? "Blok warna ringkas mengikut solat." : "Minimal color blocks by prayer."
        case .metro:
            return isMalayAppLanguage() ? "Papan jadual transit." : "Transit-board layout."
        case .neo:
            return isMalayAppLanguage() ? "Terminal gelap dengan aksen hijau." : "Dark terminal with green accents."
        case .sketch:
            return isMalayAppLanguage() ? "Kanvas lakaran oren." : "Orange sketch canvas."
        case .proNext, .proIndex, .proArc:
            return isMalayAppLanguage() ? "Gaya premium Waktu Pro." : "Premium Waktu Pro style."
        }
    }

    var supportedSizes: Set<HomeWidgetPresetSize> {
        switch self {
        case .simpleCountdown, .countdown, .proNext:
            return [.small]
        case .countdownMedium, .prayerTimesCompact, .prayerTimesGrid, .proIndex:
            return [.medium]
        case .countdownLarge, .prayerTimesLarge, .proArc:
            return [.large]
        case .minimalist:
            return [.small, .medium, .large]
        case .metro, .neo, .sketch:
            return [.small, .medium, .large]
        }
    }

    var requiresPremiumWidgets: Bool {
        switch self {
        case .metro, .neo, .sketch, .proNext, .proIndex, .proArc:
            return true
        default:
            return false
        }
    }

    func supports(_ size: HomeWidgetPresetSize) -> Bool {
        supportedSizes.contains(size)
    }

    static func styles(for size: HomeWidgetPresetSize) -> [HomeWidgetStyle] {
        allCases.filter { $0.supports(size) }
    }
}

enum HomeWidgetPresetStore {
    static func seedDefaultsIfNeeded(defaults: UserDefaults? = UserDefaults(suiteName: sharedAppGroupID)) {
        guard let defaults else { return }
        for slot in HomeWidgetPresetSlot.allCases where defaults.string(forKey: slot.storageKey()) == nil {
            defaults.set(slot.defaultStyle().rawValue, forKey: slot.storageKey())
        }
    }

    static func style(for slot: HomeWidgetPresetSlot, defaults: UserDefaults? = UserDefaults(suiteName: sharedAppGroupID)) -> HomeWidgetStyle {
        seedDefaultsIfNeeded(defaults: defaults)
        let rawValue = defaults?.string(forKey: slot.storageKey())
        let style = HomeWidgetStyle(rawValue: rawValue ?? "") ?? slot.defaultStyle()
        guard style.supports(slot.size) else { return slot.defaultStyle() }
        if style.requiresPremiumWidgets && !premiumWidgetsUnlocked() {
            return slot.defaultStyle()
        }
        return style
    }

    static func setStyle(_ style: HomeWidgetStyle, for slot: HomeWidgetPresetSlot, defaults: UserDefaults? = UserDefaults(suiteName: sharedAppGroupID)) {
        guard style.supports(slot.size), let defaults else { return }
        defaults.set(style.rawValue, forKey: slot.storageKey())
    }
}

@available(iOS 17.0, *)
struct HomeWidgetPresetEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Widget Preset"
    static var defaultQuery = HomeWidgetPresetEntityQuery()

    let id: String

    var slot: HomeWidgetPresetSlot {
        HomeWidgetPresetSlot(rawValue: id) ?? .small1
    }

    var displayRepresentation: DisplayRepresentation {
        let style = HomeWidgetPresetStore.style(for: slot)
        return DisplayRepresentation(
            title: "\(slot.title)",
            subtitle: "\(style.title)"
        )
    }

    static func entity(for slot: HomeWidgetPresetSlot) -> HomeWidgetPresetEntity {
        HomeWidgetPresetEntity(id: slot.rawValue)
    }
}

@available(iOS 17.0, *)
struct HomeWidgetPresetEntityQuery: EntityQuery {
    func entities(for identifiers: [HomeWidgetPresetEntity.ID]) async throws -> [HomeWidgetPresetEntity] {
        identifiers.compactMap { identifier in
            guard let slot = HomeWidgetPresetSlot(rawValue: identifier) else { return nil }
            return HomeWidgetPresetEntity.entity(for: slot)
        }
    }

    func suggestedEntities() async throws -> [HomeWidgetPresetEntity] {
        HomeWidgetPresetSlot.allCases.map(HomeWidgetPresetEntity.entity)
    }

    func defaultResult() async -> HomeWidgetPresetEntity? {
        HomeWidgetPresetEntity.entity(for: .small1)
    }
}

@available(iOS 17.0, *)
struct HomeWidgetPresetOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [HomeWidgetPresetEntity] {
        HomeWidgetPresetSlot.allCases.map(HomeWidgetPresetEntity.entity)
    }
}

@available(iOS 17.0, *)
struct SmallHomeWidgetPresetOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [HomeWidgetPresetEntity] {
        HomeWidgetPresetSlot.slots(for: .small).map(HomeWidgetPresetEntity.entity)
    }
}

@available(iOS 17.0, *)
struct MediumHomeWidgetPresetOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [HomeWidgetPresetEntity] {
        HomeWidgetPresetSlot.slots(for: .medium).map(HomeWidgetPresetEntity.entity)
    }
}

@available(iOS 17.0, *)
struct LargeHomeWidgetPresetOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [HomeWidgetPresetEntity] {
        HomeWidgetPresetSlot.slots(for: .large).map(HomeWidgetPresetEntity.entity)
    }
}

@available(iOS 17.0, *)
protocol HomeWidgetPresetConfigurationIntent: WidgetConfigurationIntent {
    var preset: HomeWidgetPresetEntity? { get set }
    init()
}

@available(iOS 17.0, *)
struct SmallHomeWidgetConfigurationIntent: HomeWidgetPresetConfigurationIntent {
    static var title: LocalizedStringResource = "Small Waktu Widget"
    static var description = IntentDescription("Choose which saved small Waktu widget preset this widget should use.")

    @Parameter(title: "Preset", optionsProvider: SmallHomeWidgetPresetOptionsProvider())
    var preset: HomeWidgetPresetEntity?

    init() {
        self.preset = HomeWidgetPresetEntity.entity(for: .small1)
    }

    init(preset: HomeWidgetPresetEntity?) {
        self.preset = preset
    }
}

@available(iOS 17.0, *)
struct MediumHomeWidgetConfigurationIntent: HomeWidgetPresetConfigurationIntent {
    static var title: LocalizedStringResource = "Medium Waktu Widget"
    static var description = IntentDescription("Choose which saved medium Waktu widget preset this widget should use.")

    @Parameter(title: "Preset", optionsProvider: MediumHomeWidgetPresetOptionsProvider())
    var preset: HomeWidgetPresetEntity?

    init() {
        self.preset = HomeWidgetPresetEntity.entity(for: .medium1)
    }

    init(preset: HomeWidgetPresetEntity?) {
        self.preset = preset
    }
}

@available(iOS 17.0, *)
struct LargeHomeWidgetConfigurationIntent: HomeWidgetPresetConfigurationIntent {
    static var title: LocalizedStringResource = "Large Waktu Widget"
    static var description = IntentDescription("Choose which saved large Waktu widget preset this widget should use.")

    @Parameter(title: "Preset", optionsProvider: LargeHomeWidgetPresetOptionsProvider())
    var preset: HomeWidgetPresetEntity?

    init() {
        self.preset = HomeWidgetPresetEntity.entity(for: .large1)
    }

    init(preset: HomeWidgetPresetEntity?) {
        self.preset = preset
    }
}

@available(iOS 16.0, watchOS 9.0, *)
struct AppShortcutsRoot: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WhenIsPrayerIntent(),
            phrases: [
                "When is \(\.$prayer) in \(.applicationName)",
                "When is \(\.$prayer) prayer in \(.applicationName)",
                "What time is \(\.$prayer) in \(.applicationName)",
                "What time is \(\.$prayer) prayer in \(.applicationName)",
                "What is the time for \(\.$prayer) in \(.applicationName)",
                "What is the time for \(\.$prayer) prayer in \(.applicationName)",
                "When does \(\.$prayer) start in \(.applicationName)",
                "When does \(\.$prayer) prayer start in \(.applicationName)",
                "Time for \(\.$prayer) in \(.applicationName)",
                "Time for \(\.$prayer) prayer in \(.applicationName)",
                "Prayer time for \(\.$prayer) in \(.applicationName)",
                "Prayer time for \(\.$prayer) prayer in \(.applicationName)",
                "وقت \(\.$prayer) في \(.applicationName)",
                "متى \(\.$prayer) في \(.applicationName)",
                "ما وقت \(\.$prayer) في \(.applicationName)",
            ],
            shortTitle: "When is Prayer",
            systemImageName: "clock"
        )

        AppShortcut(
            intent: CurrentPrayerIntent(),
            phrases: [
                "What is the current prayer in \(.applicationName)",
                "Current prayer in \(.applicationName)",
                "What prayer is it now in \(.applicationName)",
                "Which prayer is now in \(.applicationName)",
                "What prayer time is it in \(.applicationName)",
                "ما هي الصلاة الحالية في \(.applicationName)",
                "ما هي الصلاة الآن في \(.applicationName)",
                "ما الصلاة الآن في \(.applicationName)",
            ],
            shortTitle: "Current Prayer",
            systemImageName: "clock.badge.checkmark"
        )

        AppShortcut(
            intent: NextPrayerIntent(),
            phrases: [
                "What is the next prayer in \(.applicationName)",
                "When is the next prayer in \(.applicationName)",
                "What is the next prayer time in \(.applicationName)",
                "When is the next prayer time in \(.applicationName)",
                "Next prayer in \(.applicationName)",
                "Next prayer time in \(.applicationName)",
                "Time of the next prayer in \(.applicationName)",
                "Which prayer is next in \(.applicationName)",
                "ما هي الصلاة القادمة في \(.applicationName)",
                "متى الصلاة القادمة في \(.applicationName)",
                "ما وقت الصلاة القادمة في \(.applicationName)",
                "وقت الصلاة القادمة في \(.applicationName)",
            ],
            shortTitle: "Next Prayer",
            systemImageName: "forward.end"
        )
    }
}
