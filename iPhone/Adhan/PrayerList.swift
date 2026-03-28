import SwiftUI

struct PrayerList: View {
    @EnvironmentObject var settings: Settings
    
    @State private var expandedPrayer: Prayer?
    @State private var fullPrayers: Bool = false
    
    @AppStorage("prayerDisplayMode") private var prayerDisplayModeRawValue: String = PrayerDisplayMode.list.rawValue
    
    @State private var selectedDate = Date()

    enum PrayerDisplayMode: String, CaseIterable, Identifiable {
        case list = "Prayer List"
        case grid = "Prayer Grid"
        
        var id: String { self.rawValue }

        var displayName: String {
            switch self {
            case .list: return effectiveAppLanguageCode().hasPrefix("ms") ? "Senarai" : "LIST"
            case .grid: return effectiveAppLanguageCode().hasPrefix("ms") ? "Grid" : "GRID"
            }
        }
    }
    
    func getPrayerColor(for prayer: Prayer) -> Color {
        guard let prayers = settings.prayers?.prayers else {
            return .secondary
        }
        
        guard let currentPrayer = settings.currentPrayer else {
            return .secondary
        }
        
        if currentPrayer.nameTransliteration.contains(prayer.nameTransliteration) {
            return settings.accentColor.color
        }
        
        guard let currentPrayerIndex = prayers.firstIndex(where: { $0.id == currentPrayer.id }),
              let prayerIndex = prayers.firstIndex(where: { $0.id == prayer.id }) else {
            return .secondary
        }
        
        if prayerIndex < currentPrayerIndex {
            return .secondary
        }
        
        return .primary
    }

    private var prayerObject: Prayers? {
        settings.prayers
    }

    private var displayedPrayerTimes: [Prayer] {
        if settings.changedDate {
            return fullPrayers ? (settings.dateFullPrayers ?? []) : (settings.datePrayers ?? [])
        }

        guard let prayerObject else { return [] }
        return fullPrayers ? prayerObject.fullPrayers : prayerObject.prayers
    }

    private var gridColumns: [GridItem] {
        let count = displayedPrayerTimes.count == 4 ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private var shurooqDerivedHelpersByPrayerID: [UUID: ShurooqDerivedHelperTimes] {
        PrayerDerivedTimes.shurooqHelpers(
            for: displayedPrayerTimes,
            countryCode: settings.currentLocation?.countryCode
        )
    }

    private func displayInfo(for prayer: Prayer) -> PrayerDisplayInfo {
        PrayerDerivedTimes.displayInfo(
            for: prayer,
            in: displayedPrayerTimes,
            countryCode: settings.currentLocation?.countryCode
        )
    }

    @ViewBuilder
    private var sectionHeader: some View {
        HStack {
            Text("PRAYER TIMES")

            #if !os(watchOS)
            Spacer()

            Picker("", selection: $prayerDisplayModeRawValue.animation(.easeInOut)) {
                ForEach(PrayerDisplayMode.allCases) { mode in
                    Text(mode.displayName).tag(mode.rawValue)
                }
            }
            .font(.caption2)
            .pickerStyle(MenuPickerStyle())
            .padding(.vertical, -12)
            #endif
        }
    }

    @ViewBuilder
    private var listContent: some View {
        Group {
            ForEach(displayedPrayerTimes) { prayerTime in
                let displayInfo = displayInfo(for: prayerTime)

                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(settings.currentPrayer?.nameTransliteration.contains(prayerTime.nameTransliteration) ?? false ? settings.accentColor.color.opacity(0.25) : .clear)
                        .padding(.horizontal, -12)
                        #if !os(watchOS)
                        .padding(.vertical, -11)
                        #endif

                    HStack {
                        Button(action: {
                            settings.hapticFeedback()

                            withAnimation {
                                if let expandedPrayer = expandedPrayer, prayerTime == expandedPrayer {
                                    self.expandedPrayer = nil
                                } else {
                                    self.expandedPrayer = prayerTime
                                }
                            }
                        }) {
                            HStack(alignment: .center, spacing: 0) {
                                Image(systemName: prayerTime.image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(displayInfo.usesSecondarySunStyle ? .primary : settings.accentColor.color)
                                    .padding(.all, 4)
                                    .padding(.trailing, 8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(localizedPrayerName(displayInfo.nameTransliteration))
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text(displayInfo.time, style: .time)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    if let helperTimes = shurooqDerivedHelpersByPrayerID[prayerTime.id] {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("Ishraq: \(DateFormatter.timeEN.string(from: helperTimes.ishraq))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)

                                            if !displayInfo.isDerivedDhuha {
                                                Text("Dhuha: \(DateFormatter.timeEN.string(from: helperTimes.dhuha))")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .padding(.top, 1)
                                    }
                                }
                                .layoutPriority(1)

                                Spacer()

                                #if !os(watchOS)
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(localizedPrayerMeaning(displayInfo.nameEnglish))
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)

                                    Text(displayInfo.nameArabic)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }
                                #endif
                            }
                        }

                        #if !os(watchOS)
                        Image(systemName: settings.shouldShowFilledBell(prayerTime: prayerTime) ? "bell.fill" : settings.shouldShowOutlinedBell(prayerTime: prayerTime) ? "bell" : "bell.slash")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .onTapGesture {
                                settings.hapticFeedback()
                                // Tap cycle:
                                // bell.slash -> bell (on-time only)
                                // bell -> bell.fill (on-time + pre-notification)
                                // bell.fill -> bell.slash (off)

                                if settings.shouldShowOutlinedBell(prayerTime: prayerTime) {
                                    switch prayerTime.nameTransliteration {
                                    case "Fajr":
                                        settings.preNotificationFajr = 15
                                        settings.notificationFajr = true
                                    case "Shurooq":
                                        settings.preNotificationSunrise = 15
                                        settings.notificationSunrise = true
                                    case "Dhuhr", "Dhuhr/Asr", "Jumuah":
                                        settings.preNotificationDhuhr = 15
                                        settings.notificationDhuhr = true
                                    case "Asr":
                                        settings.preNotificationAsr = 15
                                        settings.notificationAsr = true
                                    case "Maghrib", "Maghrib/Isha":
                                        settings.preNotificationMaghrib = 15
                                        settings.notificationMaghrib = true
                                    case "Isha":
                                        settings.preNotificationIsha = 15
                                        settings.notificationIsha = true
                                    default:
                                        break
                                    }
                                } else if settings.shouldShowFilledBell(prayerTime: prayerTime) {
                                    switch prayerTime.nameTransliteration {
                                    case "Fajr":
                                        settings.preNotificationFajr = 0
                                        settings.notificationFajr = false
                                    case "Shurooq":
                                        settings.preNotificationSunrise = 0
                                        settings.notificationSunrise = false
                                    case "Dhuhr", "Dhuhr/Asr", "Jumuah":
                                        settings.preNotificationDhuhr = 0
                                        settings.notificationDhuhr = false
                                    case "Asr":
                                        settings.preNotificationAsr = 0
                                        settings.notificationAsr = false
                                    case "Maghrib", "Maghrib/Isha":
                                        settings.preNotificationMaghrib = 0
                                        settings.notificationMaghrib = false
                                    case "Isha":
                                        settings.preNotificationIsha = 0
                                        settings.notificationIsha = false
                                    default:
                                        break
                                    }
                                } else {
                                    switch prayerTime.nameTransliteration {
                                    case "Fajr":
                                        settings.preNotificationFajr = 0
                                        settings.notificationFajr = true
                                    case "Shurooq":
                                        settings.preNotificationSunrise = 0
                                        settings.notificationSunrise = true
                                    case "Dhuhr", "Dhuhr/Asr", "Jumuah":
                                        settings.preNotificationDhuhr = 0
                                        settings.notificationDhuhr = true
                                    case "Asr":
                                        settings.preNotificationAsr = 0
                                        settings.notificationAsr = true
                                    case "Maghrib", "Maghrib/Isha":
                                        settings.preNotificationMaghrib = 0
                                        settings.notificationMaghrib = true
                                    case "Isha":
                                        settings.preNotificationIsha = 0
                                        settings.notificationIsha = true
                                    default:
                                        break
                                    }
                                }
                            }
                            .frame(width: 18, height: 18)
                            .foregroundColor(
                                prayerTime.nameTransliteration == "Shurooq" ? .primary :
                                    (settings.shouldShowFilledBell(prayerTime: prayerTime) || settings.shouldShowOutlinedBell(prayerTime: prayerTime)) ? settings.accentColor.color : .primary
                            )
                            .padding(.leading, 6)
                            .contextMenu {
                                Button(action: {
                                    settings.hapticFeedback()

                                    switch prayerTime.nameTransliteration {
                                    case "Fajr":
                                        settings.preNotificationFajr = 15
                                        settings.notificationFajr = true
                                    case "Shurooq":
                                        settings.preNotificationSunrise = 15
                                        settings.notificationSunrise = true
                                    case "Dhuhr", "Dhuhr/Asr", "Jumuah":
                                        settings.preNotificationDhuhr = 15
                                        settings.notificationDhuhr = true
                                    case "Asr":
                                        settings.preNotificationAsr = 15
                                        settings.notificationAsr = true
                                    case "Maghrib", "Maghrib/Isha":
                                        settings.preNotificationMaghrib = 15
                                        settings.notificationMaghrib = true
                                    case "Isha":
                                        settings.preNotificationIsha = 15
                                        settings.notificationIsha = true
                                    default:
                                        break
                                    }
                                }) {
                                    Label("Prenotification", systemImage: "bell.fill")
                                }

                                Button(action: {
                                    settings.hapticFeedback()

                                    switch prayerTime.nameTransliteration {
                                    case "Fajr":
                                        settings.preNotificationFajr = 0
                                        settings.notificationFajr = true
                                    case "Shurooq":
                                        settings.preNotificationSunrise = 0
                                        settings.notificationSunrise = true
                                    case "Dhuhr", "Dhuhr/Asr", "Jumuah":
                                        settings.preNotificationDhuhr = 0
                                        settings.notificationDhuhr = true
                                    case "Asr":
                                        settings.preNotificationAsr = 0
                                        settings.notificationAsr = true
                                    case "Maghrib", "Maghrib/Isha":
                                        settings.preNotificationMaghrib = 0
                                        settings.notificationMaghrib = true
                                    case "Isha":
                                        settings.preNotificationIsha = 0
                                        settings.notificationIsha = true
                                    default:
                                        break
                                    }
                                }) {
                                    Label("Notification", systemImage: "bell")
                                }

                                Button(action: {
                                    settings.hapticFeedback()

                                    switch prayerTime.nameTransliteration {
                                    case "Fajr":
                                        settings.preNotificationFajr = 0
                                        settings.notificationFajr = false
                                    case "Shurooq":
                                        settings.preNotificationSunrise = 0
                                        settings.notificationSunrise = false
                                    case "Dhuhr", "Dhuhr/Asr", "Jumuah":
                                        settings.preNotificationDhuhr = 0
                                        settings.notificationDhuhr = false
                                    case "Asr":
                                        settings.preNotificationAsr = 0
                                        settings.notificationAsr = false
                                    case "Maghrib", "Maghrib/Isha":
                                        settings.preNotificationMaghrib = 0
                                        settings.notificationMaghrib = false
                                    case "Isha":
                                        settings.preNotificationIsha = 0
                                        settings.notificationIsha = false
                                    default:
                                        break
                                    }
                                }) {
                                    Label("No Notification", systemImage: "bell.slash")
                                }
                            }
                        #endif
                    }
                    .padding(.vertical, 4)
                }

                if let expandedPrayer = expandedPrayer, prayerTime == expandedPrayer {
                    if displayInfo.isDerivedDhuha {
                        VStack(alignment: .leading) {
                            Text(localizedDhuhaSummaryText())
                                .foregroundColor(.primary)
                                .font(.footnote)

                            if let detailNote = localizedPrayerDetailNote(for: displayInfo.nameTransliteration) {
                                Text(detailNote)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                    .padding(.top, 2)
                            }
                        }
                    } else if prayerTime.nameTransliteration != "Shurooq" {
                        VStack(alignment: .leading) {
                            if(prayerTime.rakah != "0") {
                                Text(localizedPrayerRakahInfo(prayerTime.rakah))
                                    .foregroundColor(.primary)
                                    .font(.body)
                            }

                            if(prayerTime.sunnahBefore != "0") {
                                Text(localizedSunnahBeforeInfo(prayerTime.sunnahBefore))
                                    .foregroundColor(.secondary)
                                    .font(.footnote)
                            }

                            if(prayerTime.sunnahAfter != "0") {
                                Text(localizedSunnahAfterInfo(prayerTime.sunnahAfter))
                                    .foregroundColor(.secondary)
                                    .font(.footnote)
                            }

                            if let detailNote = localizedPrayerDetailNote(for: prayerTime.nameTransliteration) {
                                Text(detailNote)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                    .padding(.top, 2)
                            }
                        }
                    } else {
                        VStack(alignment: .leading) {
                            Text(localizedShurooqSummaryText())
                                .foregroundColor(.primary)
                                .font(.footnote)

                            if let detailNote = localizedPrayerDetailNote(for: prayerTime.nameTransliteration) {
                                Text(detailNote)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                    .padding(.top, 2)
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: settings.travelingMode) { _ in
            withAnimation {
                fullPrayers = false
            }
        }
    }

    @ViewBuilder
    private var gridContent: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(displayedPrayerTimes) { prayer in
                VStack(alignment: .center) {
                    HStack {
                        Image(systemName: prayer.image)
                            .font(.subheadline)
                            .foregroundColor(getPrayerColor(for: prayer))
                            .padding(.trailing, -5)

                        Text(localizedPrayerName(prayer.nameTransliteration))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(getPrayerColor(for: prayer))
                    }

                    Text(prayer.time, style: .time)
                        .font(.subheadline)
                        .foregroundColor(getPrayerColor(for: prayer))
                }
            }
        }
        .padding(.horizontal, -20)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    @ViewBuilder
    private var travelingModeFooter: some View {
        if settings.travelingMode {
            VStack {
                #if !os(watchOS)
                Text("Traveling mode is on. If you are traveling more than 48 mi, then you can pray Qasr, where you combine prayers. You can customize and learn more in settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                #endif

                Text(fullPrayers ? "View Qasr Prayers" : "View Full Prayers")
                    .font(.subheadline)
                    .foregroundColor(settings.accentColor.color)
                    .padding(.vertical, 8)
                    .onTapGesture {
                        settings.hapticFeedback()
                        withAnimation {
                            fullPrayers.toggle()
                        }
                    }

                #if os(watchOS)
                Text("Traveling mode is on. If you are traveling more than 48 mi, then you can pray Qasr, where you combine prayers. You can customize and learn more in settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                #endif
            }
        }
    }

    @ViewBuilder
    private var dateSelectorSection: some View {
        #if !os(watchOS)
        VStack {
            DatePicker("Showing prayers for", selection: $selectedDate.animation(.easeInOut), displayedComponents: .date)
                .datePickerStyle(DefaultDatePickerStyle())
                .padding(4)

            if settings.changedDate && !settings.isDateSupportedByJAKIM(selectedDate) {
                Text("Prayer times are sourced from JAKIM via Waktu Solat API. At the moment, only the \(settings.supportedJAKIMYear) schedule is published, so this selected date is outside the available range.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }

            if !Calendar.current.isDate(selectedDate, inSameDayAs: Date()) {
                Text("Show prayers for today")
                    .font(.subheadline)
                    .foregroundColor(settings.accentColor.color)
                    .padding(.vertical, 8)
                    .onTapGesture {
                        settings.hapticFeedback()
                        withAnimation {
                            selectedDate = Date()
                        }
                    }
            }
        }
        .onChange(of: selectedDate) { value in
            let calendar = Calendar.current

            settings.changedDate = !calendar.isDate(value, inSameDayAs: Date())

            if settings.changedDate {
                if settings.isDateSupportedByJAKIM(value) {
                    Task { @MainActor in
                        await settings.refreshDatePrayers(for: value)
                    }
                } else {
                    settings.datePrayers = []
                    settings.dateFullPrayers = []
                }
            }
        }
        #endif
    }
    
    var body: some View {
        if prayerObject != nil {
            Section(header: sectionHeader) {
                if PrayerDisplayMode(rawValue: prayerDisplayModeRawValue) == .list {
                    listContent
                } else {
                    gridContent
                }

                travelingModeFooter
                dateSelectorSection
            }
        }
    }
}

#Preview {
    AdhanView()
        .environmentObject(Settings.shared)
}
