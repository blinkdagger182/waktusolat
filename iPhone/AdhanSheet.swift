import SwiftUI

fileprivate struct MalaysiaZoneInfo: Decodable, Identifiable {
    let jakimCode: String
    let negeri: String
    let daerah: String
    var id: String { jakimCode }
}

fileprivate struct IndonesiaZoneInfo: Decodable, Identifiable {
    let id: String
    let location: String
    let province: String
    let timezone: String
}

fileprivate struct WaktuZonePickerItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
}

struct AdhanSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: Settings
    @AppStorage("waktuZoneModeSelection") private var waktuZoneModeSelection: Int = 0
    
    private let globalCalculationMethods: [String] = Settings.globalCalculationMethods
    @State private var malaysiaZones: [MalaysiaZoneInfo] = []
    @State private var indonesiaZones: [IndonesiaZoneInfo] = []
    @State private var isLoadingMalaysiaZones = false
    @State private var isLoadingIndonesiaZones = false
    @State private var waktuZoneLoadError: String?
    @State private var autoDetectedZoneCode: String = ""
    @State private var showingWaktuZonePicker = false
    @State private var isLocationDetailsExpanded = false

    private var isMalay: Bool {
        effectiveAppLanguageCode().hasPrefix("ms")
    }
    
    private var isGlobalDebugForced: Bool {
        settings.prayerRegionDebugOverride == 2
    }
    
    private var shouldShowGlobalMethodDropdown: Bool {
        isGlobalDebugForced || !settings.shouldUseMalaysiaPrayerAPI(for: settings.currentLocation)
    }

    private var isSingaporeMode: Bool {
        !isGlobalDebugForced &&
        settings.currentLocation?.countryCode?.uppercased() == "SG"
    }

    private var isIndonesiaMode: Bool {
        !isGlobalDebugForced &&
        settings.currentLocation?.countryCode?.uppercased() == "ID"
    }

    private var shouldShowPrayerModeSection: Bool {
        let countryCode = settings.currentLocation?.countryCode?.uppercased() ?? ""
        return countryCode == "MY" || countryCode == "SG" || countryCode == "ID"
    }
    
    private func shortCalculationLabel(_ method: String) -> String {
        switch method {
        case "Auto (By Location)":                                          return appLocalized("Auto")
        case "Islamic Society of North America (ISNA)",
             "Islamic Society of North America":                            return "ISNA"
        case "Moonsighting Committee Worldwide":                            return "Moonsighting Committee"
        case "Muslim World League":                                         return "Muslim World League"
        case "Majlis Ugama Islam Singapura, Singapore":                     return "MUIS"
        case "Jabatan Kemajuan Islam Malaysia (JAKIM)":                     return "JAKIM"
        case "KEMENAG - Kementerian Agama Republik Indonesia":              return "KEMENAG (Indonesia)"
        default:                                                            return method
        }
    }

    private func calculationMenuLabel(_ method: String) -> String {
        switch method {
        case "Auto (By Location)":
            return isMalay ? "Auto (Sedang menggunakan \(resolvedAutoMethodLabel))" : "Auto (Currently using \(resolvedAutoMethodLabel))"
        case "Islamic Society of North America (ISNA)":
            return "Islamic Society of North America (ISNA)"
        case "Majlis Ugama Islam Singapura, Singapore":
            return "Majlis Ugama Islam Singapura (MUIS)"
        default:
            return method
        }
    }

    private var resolvedAutoMethodLabel: String {
        settings.effectivePrayerCountrySupportConfig.autoMethodLabel
    }

    private var currentCalculationLabel: String {
        if settings.prayerCalculation == "Auto (By Location)" {
            return resolvedAutoMethodLabel
        }
        return shortCalculationLabel(settings.prayerCalculation)
    }

    private var supportOverviewTitle: String {
        settings.effectivePrayerCountrySupportConfig.supportTitle
    }

    private var supportOverviewBullets: [String] {
        settings.effectivePrayerCountrySupportConfig.supportBullets
    }

    private var selectedCalculationDescription: String {
        switch settings.prayerCalculation {
        case "Auto (By Location)":
            let countryCode = settings.currentLocation?.countryCode?.uppercased() ?? ""
            let supportConfig = settings.effectivePrayerCountrySupportConfig
            if countryCode.isEmpty {
                return isMalay ? "Memilih kiraan waktu solat yang paling sesuai secara automatik berdasarkan negara yang dikesan. Sekarang ia menggunakan \(resolvedAutoMethodLabel)." : "Automatically selects the most suitable prayer calculation based on your detected country. Right now it is using \(resolvedAutoMethodLabel)."
            }
            if supportConfig.pipeline == "global" {
                return isMalay
                    ? "Memilih kiraan waktu solat yang paling sesuai secara automatik berdasarkan negara yang dikesan (\(countryCode)). Di luar wilayah rasmi kami, Auto kini menggunakan \(resolvedAutoMethodLabel) sebagai lalai."
                    : "Automatically selects the most suitable prayer calculation based on your detected country (\(countryCode)). Outside our officially integrated regions, Auto currently defaults to \(resolvedAutoMethodLabel)."
            }
            return isMalay ? "Memilih kiraan waktu solat yang paling sesuai secara automatik berdasarkan negara yang dikesan (\(countryCode)). Sekarang ia menggunakan \(resolvedAutoMethodLabel)." : "Automatically selects the most suitable prayer calculation based on your detected country (\(countryCode)). Right now it is using \(resolvedAutoMethodLabel)."
        case "Islamic Society of North America (ISNA)", "Islamic Society of North America":
            return isMalay ? "Lazim digunakan di Amerika Utara, dengan waktu solat dikira daripada koordinat anda menggunakan parameter ISNA." : "Commonly used across North America, with prayer times calculated from your coordinates using ISNA parameters."
        case "Moonsighting Committee Worldwide":
            return isMalay ? "Digunakan di UK dan banyak negara Barat. Berdasarkan rukyah dengan tetapan shafaq umum." : "Used in the UK and many Western countries. Based on moon sighting with shafaq set to general."
        case "Muslim World League":
            if settings.currentLocation?.countryCode?.uppercased() == "GB" {
                return isMalay ? "Banyak digunakan oleh masjid-masjid di UK, dengan waktu solat dikira daripada koordinat anda menggunakan parameter Muslim World League." : "Widely used across many masjids in the UK, with prayer times calculated from your coordinates using Muslim World League parameters."
            }
            return isMalay ? "Banyak digunakan di AS dan di peringkat antarabangsa. Menggunakan parameter kiraan Muslim World League." : "Widely used in the US and internationally. Uses Muslim World League calculation parameters."
        case "Majlis Ugama Islam Singapura, Singapore":
            return isMalay ? "Waktu solat rasmi Singapura oleh MUIS (Majlis Ugama Islam Singapura)." : "Official Singapore prayer times by MUIS (Majlis Ugama Islam Singapura)."
        case "Jabatan Kemajuan Islam Malaysia (JAKIM)":
            return isMalay ? "Waktu solat rasmi Malaysia oleh JAKIM. Menggunakan API Waktu Solat Malaysia." : "Official Malaysian prayer times by JAKIM. Uses the Malaysian Prayer Times API."
        case "KEMENAG - Kementerian Agama Republik Indonesia":
            return isMalay ? "Waktu solat rasmi Indonesia oleh KEMENAG, dipadankan dengan kabupaten/kota anda melalui GPS." : "Official Indonesia prayer times by KEMENAG, matched to your kabupaten/kota via GPS."
        default:
            return isMalay ? "Menggunakan kaedah kiraan waktu solat yang dipilih untuk lokasi anda." : "Uses the selected prayer time calculation method for your location."
        }
    }
    
    private var selectedMalaysiaZoneLabel: String {
        let zone = settings.debugMalaysiaZoneCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !zone.isEmpty else { return isMalay ? "Auto (GPS)" : "Auto (GPS)" }
        guard let info = filteredZones.first(where: { $0.jakimCode.uppercased() == zone }) else {
            return zone
        }
        return "\(info.jakimCode) · \(info.negeri) · \(info.daerah)"
    }

    private var selectedIndonesiaZoneLabel: String {
        let regionId = settings.debugIndonesiaRegionId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !regionId.isEmpty else { return isMalay ? "Auto (GPS)" : "Auto (GPS)" }
        guard let info = indonesiaZones.first(where: { $0.id == regionId }) else {
            return settings.currentIndonesiaWaktuZoneName ?? regionId
        }
        return "\(ResolvedPrayerArea.prettyName(info.location)), \(ResolvedPrayerArea.prettyName(info.province))"
    }
    
    /// Zones filtered to the user's current country.
    /// SG → only SGP01; ID → empty (zone picker is hidden); everything else → Malaysian JAKIM zones.
    private var filteredZones: [MalaysiaZoneInfo] {
        let country = settings.currentLocation?.countryCode?.uppercased() ?? ""
        switch country {
        case "SG":
            return [MalaysiaZoneInfo(jakimCode: "SGP01", negeri: "Singapore", daerah: "Singapore")]
        case "ID":
            return []
        default:
            return malaysiaZones
        }
    }

    private var autoDetectedZoneLabel: String {
        let zone = resolvedAutoDetectedZoneCode
        guard !zone.isEmpty else { return isMalay ? "Sedang mengesan..." : "Detecting..." }
        guard let info = malaysiaZones.first(where: { $0.jakimCode.uppercased() == zone }) else {
            return zone
        }
        return "\(info.jakimCode) · \(info.negeri) · \(info.daerah)"
    }

    private var resolvedAutoDetectedZoneCode: String {
        let localDetectedZone = autoDetectedZoneCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !localDetectedZone.isEmpty {
            return localDetectedZone
        }
        return settings.currentMalaysiaWaktuZoneName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
    }

    private var autoDetectedIndonesiaZoneLabel: String {
        settings.currentIndonesiaWaktuZoneName ?? (isMalay ? "Sedang mengesan..." : "Detecting...")
    }

    private var canConfigureWaktuZone: Bool {
        !shouldShowGlobalMethodDropdown || isSingaporeMode || isIndonesiaMode
    }

    private var waktuZonePickerTitle: String {
        isIndonesiaMode ? "Indonesia Prayer Zones" : "Waktu Zones"
    }

    private var waktuZonePickerItems: [WaktuZonePickerItem] {
        if isIndonesiaMode {
            return indonesiaZones.map { zone in
                WaktuZonePickerItem(
                    id: zone.id,
                    title: ResolvedPrayerArea.prettyName(zone.location),
                    subtitle: "\(ResolvedPrayerArea.prettyName(zone.province)) • \(zone.timezone)"
                )
            }
        }

        return filteredZones.map { zone in
            WaktuZonePickerItem(
                id: zone.jakimCode,
                title: "\(zone.jakimCode) · \(zone.negeri)",
                subtitle: zone.daerah
            )
        }
    }

    private var currentWaktuZoneLabel: String {
        if isIndonesiaMode {
            return releaseWaktuModeBinding.wrappedValue == 0 ? autoDetectedIndonesiaZoneLabel : selectedIndonesiaZoneLabel
        }
        return releaseWaktuModeBinding.wrappedValue == 0 ? autoDetectedZoneLabel : selectedMalaysiaZoneLabel
    }

    private var currentLocationSummary: String {
        settings.effectivePrayerLocationDisplayName ?? (isMalay ? "Tidak diketahui" : "Unknown")
    }

    private var locationConfigurationSummary: String {
        if canConfigureWaktuZone {
            if releaseWaktuModeBinding.wrappedValue == 1 {
                return appLocalized("Manual keeps prayer times pinned to the selected zone until you switch back to Auto.")
            }
            return appLocalized("Auto uses your current location to match the most relevant prayer zone.")
        }

        return appLocalized("Review the current prayer location and zone used for today's prayer times.")
    }

    private var isLoadingCurrentWaktuZoneList: Bool {
        isIndonesiaMode ? isLoadingIndonesiaZones : isLoadingMalaysiaZones
    }
    
    @MainActor
    private func loadMalaysiaZonesIfNeeded() async {
        guard malaysiaZones.isEmpty else { return }
        // Singapore and Indonesia don't use Malaysian JAKIM zones
        let countryCode = settings.currentLocation?.countryCode?.uppercased()
        guard countryCode != "SG", countryCode != "ID" else { return }
        guard let url = URL(string: "https://api-waktusolat.vercel.app/zones") else { return }
        isLoadingMalaysiaZones = true
        waktuZoneLoadError = nil
        defer { isLoadingMalaysiaZones = false }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard status == 200 else {
                waktuZoneLoadError = isMalay ? "Tidak dapat memuatkan Zon Waktu Solat Malaysia." : "Could not load Malaysia Waktu Zones."
                return
            }
            let decoded = try JSONDecoder().decode([MalaysiaZoneInfo].self, from: data)
            malaysiaZones = decoded.sorted { $0.jakimCode < $1.jakimCode }
        } catch {
            waktuZoneLoadError = isMalay ? "Tidak dapat memuatkan Zon Waktu Solat Malaysia." : "Could not load Malaysia Waktu Zones."
        }
    }

    @MainActor
    private func loadIndonesiaZonesIfNeeded() async {
        guard indonesiaZones.isEmpty else { return }
        guard let url = URL(string: "https://api-waktusolat.vercel.app/indonesia/regions") else { return }
        isLoadingIndonesiaZones = true
        waktuZoneLoadError = nil
        defer { isLoadingIndonesiaZones = false }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard status == 200 else {
                waktuZoneLoadError = isMalay ? "Tidak dapat memuatkan zon waktu solat Indonesia." : "Could not load Indonesia prayer zones."
                return
            }
            let decoded = try JSONDecoder().decode([IndonesiaZoneInfo].self, from: data)
            indonesiaZones = decoded.sorted {
                if $0.province == $1.province {
                    return $0.location < $1.location
                }
                return $0.province < $1.province
            }
        } catch {
            waktuZoneLoadError = isMalay ? "Tidak dapat memuatkan zon waktu solat Indonesia." : "Could not load Indonesia prayer zones."
        }
    }
    
    @MainActor
    private func refreshAutoDetectedZone() async {
        guard let location = settings.currentLocation else {
            autoDetectedZoneCode = ""
            return
        }
        if let resolvedZone = settings.currentMalaysiaWaktuZoneName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(),
           !resolvedZone.isEmpty {
            autoDetectedZoneCode = resolvedZone
        }
        let lat = String(format: "%.6f", location.latitude)
        let lon = String(format: "%.6f", location.longitude)
        guard let url = URL(string: "https://api-waktusolat.vercel.app/zones/\(lat)/\(lon)") else {
            return
        }

        struct ZoneLookupResponse: Decodable {
            let zone: String?
            let jakimCode: String?
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard status == 200 else { return }
            let decoded = try JSONDecoder().decode(ZoneLookupResponse.self, from: data)
            autoDetectedZoneCode = (decoded.zone ?? decoded.jakimCode ?? "").uppercased()
            if waktuZoneModeSelection == 1,
               settings.debugMalaysiaZoneCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !autoDetectedZoneCode.isEmpty {
                settings.debugMalaysiaZoneCode = autoDetectedZoneCode
                settings.prayerCalculation = "Jabatan Kemajuan Islam Malaysia (JAKIM)"
                settings.hanafiMadhab = false
            }
        } catch {
            // Keep silent for setup UI.
        }
    }

    /// Always maps prayer calculation to the regional default for the current country code.
    private func applyRegionDefaultCalculation() {
        let countryCode = settings.currentLocation?.countryCode?.uppercased() ?? ""

        guard !countryCode.isEmpty else {
            // Country code not yet resolved — coordinate-based fallback
            if !shouldShowGlobalMethodDropdown {
                settings.prayerCalculation = "Jabatan Kemajuan Islam Malaysia (JAKIM)"
                settings.hanafiMadhab = false
            } else if settings.prayerCalculation == "Singapore" {
                settings.prayerCalculation = "Auto (By Location)"
            }
            return
        }

        switch countryCode {
        case "MY":
            settings.prayerCalculation = "Jabatan Kemajuan Islam Malaysia (JAKIM)"
            settings.hanafiMadhab = false
        case "SG":
            settings.prayerCalculation = "Majlis Ugama Islam Singapura, Singapore"
        case "ID":
            settings.prayerCalculation = "KEMENAG - Kementerian Agama Republik Indonesia"
            settings.hanafiMadhab = false
        case "GB":
            settings.prayerCalculation = "Muslim World League"
        case "US", "CA":
            settings.prayerCalculation = "Islamic Society of North America (ISNA)"
        case "FR", "JP", "KR", "CN", "PT", "RU":
            settings.prayerCalculation = "Muslim World League"
        default:
            if settings.prayerCalculation == "Singapore" {
                settings.prayerCalculation = "Auto (By Location)"
            }
        }
    }

    private func openWaktuZonePicker() {
        settings.hapticFeedback()
        Task { @MainActor in
            if isIndonesiaMode {
                await loadIndonesiaZonesIfNeeded()
            } else {
                await loadMalaysiaZonesIfNeeded()
            }
        }
        showingWaktuZonePicker = true
    }

    private func applySelectedWaktuZone(id: String) {
        if isIndonesiaMode {
            waktuZoneModeSelection = 1
            settings.debugIndonesiaRegionId = id
            settings.debugMalaysiaZoneCode = ""
            settings.prayerCalculation = "KEMENAG - Kementerian Agama Republik Indonesia"
            settings.hanafiMadhab = false
            if let info = indonesiaZones.first(where: { $0.id == id }) {
                settings.setActivePrayerContext(
                    locationDisplayName: "\(ResolvedPrayerArea.prettyName(info.location)), \(ResolvedPrayerArea.prettyName(info.province))",
                    zoneIdentifier: id,
                    mode: .manual
                )
            } else {
                settings.setActivePrayerContext(
                    locationDisplayName: settings.currentPhoneLocationName ?? settings.effectivePrayerLocationDisplayName,
                    zoneIdentifier: id,
                    mode: .manual
                )
            }
        } else {
            waktuZoneModeSelection = 1
            settings.debugMalaysiaZoneCode = id
            settings.debugIndonesiaRegionId = ""
            settings.prayerCalculation = "Jabatan Kemajuan Islam Malaysia (JAKIM)"
            settings.hanafiMadhab = false
            let selectedZone = filteredZones.first(where: { $0.jakimCode == id })
            settings.setActivePrayerContext(
                locationDisplayName: selectedZone.flatMap(manualDisplayName(for:)) ?? settings.currentPhoneLocationName ?? settings.effectivePrayerLocationDisplayName,
                zoneIdentifier: id,
                mode: .manual
            )
        }
    }

    private func manualDisplayName(for zone: MalaysiaZoneInfo) -> String {
        if let currentPhoneLocation = settings.currentPhoneLocationName,
           zone.daerah
            .split(separator: ",")
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            .contains(where: { district in
                currentPhoneLocation.lowercased().contains(district)
            }) {
            return currentPhoneLocation
        }

        let primaryDistrict = zone.daerah
            .split(separator: ",")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? zone.negeri
        return "\(primaryDistrict), \(zone.negeri)"
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text(isMalay ? "Pastikan waktu solat anda betul" : "Make sure your prayer times are correct")
                        .font(.title3.bold())

                    VStack(alignment: .leading, spacing: 10) {
                        Text(supportOverviewTitle)

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(supportOverviewBullets, id: \.self) { bullet in
                                Text("• \(bullet)")
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                    
                    Text(isMalay ? "Selepas ini, luangkan sedikit masa untuk menyemak tetapan pemberitahuan dan pilihan penampilan anda." : "After this, take a moment to review your notification settings and appearance preferences.")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                }

                Section(header: Text("PRAYER CALCULATION")) {
                    VStack(alignment: .leading) {
                        if !shouldShowGlobalMethodDropdown {
                            HStack {
                                Text(isMalay ? "Kiraan" : "Calculation")
                                Spacer()
                                Text(isMalay ? "Waktu Solat Malaysia / JAKIM" : "Malaysian Prayer Times/ JAKIM")
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)

                            Text(selectedCalculationDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 2)
                        } else if isSingaporeMode {
                            HStack {
                                Text(isMalay ? "Kiraan" : "Calculation")
                                Spacer()
                                Text("MUIS (Singapore)")
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)

                            Text(isMalay ? "Waktu solat rasmi Singapura oleh MUIS (Majlis Ugama Islam Singapura), pihak berkuasa Islam rasmi Singapura." : "Official Singapore prayer times by MUIS (Majlis Ugama Islam Singapura), the official Islamic authority of Singapore.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 2)
                        } else if isIndonesiaMode {
                            HStack {
                                Text(isMalay ? "Kiraan" : "Calculation")
                                Spacer()
                                Text("KEMENAG (Indonesia)")
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)

                            Text(isMalay ? "Waktu solat rasmi Indonesia oleh KEMENAG, dipadankan secara automatik dengan kabupaten/kota anda menggunakan padanan poligon GPS." : "Official Indonesia prayer times by KEMENAG, automatically matched to your kabupaten/kota using GPS polygon lookup.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 2)
                        } else {
                            HStack {
                                Text(isMalay ? "Kiraan" : "Calculation")
                                Spacer()
                                Menu {
                                    ForEach(globalCalculationMethods, id: \.self) { method in
                                        Button {
                                            settings.prayerCalculation = method
                                        } label: {
                                            HStack {
                                                Text(calculationMenuLabel(method))
                                                if settings.prayerCalculation == method {
                                                    Spacer()
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(currentCalculationLabel)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.75)
                                            .truncationMode(.tail)
                                        Image(systemName: "chevron.down")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: 220, alignment: .trailing)
                            }
                            .font(.subheadline)

                            Text(selectedCalculationDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 2)

                            if settings.prayerCalculation == "Auto (By Location)" {
                                HStack(spacing: 4) {
                                    Image(systemName: "location.fill")
                                        .font(.caption2)
                                    Text(isMalay ? "Menggunakan \(resolvedAutoMethodLabel)" : "Using \(resolvedAutoMethodLabel)")
                                        .font(.caption)
                                }
                                .foregroundColor(settings.accentColor.color)
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }

                if shouldShowPrayerModeSection {
                Section(header: Text(debugSectionTitle)) {
                    #if DEBUG
                    Picker("Region Override", selection: $settings.prayerRegionDebugOverride) {
                        Text(appLocalized("Auto")).tag(0)
                        Text(isMalay ? "Malaysia" : "Malaysia").tag(1)
                        Text(isMalay ? "Global" : "Global").tag(2)
                    }
                    .pickerStyle(.segmented)
                    
                    Picker("Mode", selection: releaseWaktuModeBinding) {
                        Text(appLocalized("Auto")).tag(0)
                        Text(appLocalized("Manual")).tag(1)
                    }
                    .pickerStyle(.segmented)
                    
                    locationDisclosure

                    Text(appLocalized("Location is read-only. Use Manual mode only when you want to pin a specific prayer zone for testing."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 2)
                    #endif
                    
                    #if !DEBUG
                    if canConfigureWaktuZone {
                        Picker("Mode", selection: releaseWaktuModeBinding) {
                            Text(appLocalized("Auto")).tag(0)
                            Text(appLocalized("Manual")).tag(1)
                        }
                        .pickerStyle(.segmented)
                    }

                    locationDisclosure

                    Text(locationConfigurationSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 2)

                    #endif

                    if canConfigureWaktuZone {
                        Button(action: openWaktuZonePicker) {
                            HStack {
                                Text(appLocalized("Waktu Zone"))
                                Spacer()
                                HStack(spacing: 4) {
                                    Text(currentWaktuZoneLabel)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                        .truncationMode(.tail)
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                }
                                .foregroundColor(.secondary)
                            }
                            .font(.subheadline)
                        }
                        .buttonStyle(.plain)
                    }

                    if canConfigureWaktuZone {
                        Text(appLocalized("Auto matches your location to a prayer zone. Manual lets you choose a specific zone."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 2)
                    }
                }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(appLocalized("Waktu Solat Setup"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appLocalized("Done")) {
                        settings.hapticFeedback()
                        dismiss()
                    }
                }
            }
            .onAppear {
                applyRegionDefaultCalculation()
            }
            .onChange(of: settings.prayerCalculation) { _ in
                settings.fetchPrayerTimes(force: true)
            }
            .task {
                await loadMalaysiaZonesIfNeeded()
                await loadIndonesiaZonesIfNeeded()
                await refreshAutoDetectedZone()
            }
            .onChange(of: settings.currentLocation?.latitude) { _ in
                Task { await refreshAutoDetectedZone() }
            }
            .onChange(of: settings.currentLocation?.longitude) { _ in
                Task { await refreshAutoDetectedZone() }
            }
            .onChange(of: settings.currentLocation?.countryCode) { _ in
                applyRegionDefaultCalculation()
                Task { await loadMalaysiaZonesIfNeeded() }
                Task { await loadIndonesiaZonesIfNeeded() }
                Task { await refreshAutoDetectedZone() }
            }
            .fullScreenCover(isPresented: $showingWaktuZonePicker) {
                WaktuZonePickerView(
                    title: waktuZonePickerTitle,
                    items: waktuZonePickerItems,
                    isLoading: isLoadingCurrentWaktuZoneList,
                    errorMessage: waktuZoneLoadError,
                    selectedId: isIndonesiaMode ? settings.debugIndonesiaRegionId : settings.debugMalaysiaZoneCode,
                    onSelect: { item in
                        applySelectedWaktuZone(id: item.id)
                    }
                )
                    .preferredColorScheme(settings.colorScheme)
            }
        }
    }
    
    private var debugSectionTitle: String {
        return isMalay ? "MOD SOLAT" : "PRAYER MODE"
    }

    private var releaseWaktuModeBinding: Binding<Int> {
        Binding(
            get: { waktuZoneModeSelection },
            set: { newValue in
                waktuZoneModeSelection = newValue
                let detectedZone = autoDetectedZoneCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                if newValue == 0 {
                    settings.setPrayerLocationModeToAuto()
                } else if isIndonesiaMode {
                    if settings.debugIndonesiaRegionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       let resolvedPrayerArea = settings.resolvedPrayerArea {
                        settings.debugIndonesiaRegionId = resolvedPrayerArea.regionId
                        settings.setActivePrayerContext(
                            locationDisplayName: resolvedPrayerArea.displayName,
                            zoneIdentifier: resolvedPrayerArea.regionId,
                            mode: .manual
                        )
                    }
                } else if settings.debugMalaysiaZoneCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if !detectedZone.isEmpty {
                        settings.debugMalaysiaZoneCode = detectedZone
                        settings.prayerCalculation = "Jabatan Kemajuan Islam Malaysia (JAKIM)"
                        settings.hanafiMadhab = false
                        let selectedZone = filteredZones.first(where: { $0.jakimCode.uppercased() == detectedZone })
                        settings.setActivePrayerContext(
                            locationDisplayName: selectedZone.flatMap(manualDisplayName(for:)) ?? settings.currentPhoneLocationName ?? settings.effectivePrayerLocationDisplayName,
                            zoneIdentifier: detectedZone,
                            mode: .manual
                        )
                    } else {
                        Task { @MainActor in
                            await refreshAutoDetectedZone()
                        }
                    }
                }
            }
        )
    }
}

private extension AdhanSetupSheet {
    @ViewBuilder
    var locationDisclosure: some View {
        DisclosureGroup(isExpanded: $isLocationDetailsExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(appLocalized("Location"))
                    Spacer()
                    Text(currentLocationSummary)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .truncationMode(.tail)
                }
                .font(.subheadline)

                if settings.shouldDisplayWaktuZoneTag,
                   let waktuZone = settings.currentWaktuZoneName {
                    Text(appLocalized("Waktu Zone: %@", waktuZone))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if settings.shouldPromptSetAutoForPrayerLocationMismatch {
                    HStack(alignment: .center, spacing: 12) {
                        Text(settings.prayerLocationMismatchMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer(minLength: 12)

                        Button(settings.prayerLocationAutoPromptText) {
                            settings.setPrayerLocationModeToAuto()
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                    }
                } else if settings.shouldDisplayWaktuZoneTag && settings.isResolvingAnyWaktuZone {
                    Text(appLocalized("Resolving Waktu Zone..."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
        } label: {
            HStack {
                Text(appLocalized("Location"))
                Spacer()
                Text(currentLocationSummary)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .truncationMode(.tail)
            }
            .font(.subheadline)
        }
    }
}

private struct WaktuZonePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let items: [WaktuZonePickerItem]
    let isLoading: Bool
    let errorMessage: String?
    let selectedId: String
    let onSelect: (WaktuZonePickerItem) -> Void
    @State private var searchText = ""

    private var filteredItems: [WaktuZonePickerItem] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return items
        }
        let query = searchText.lowercased()
        return items.filter {
            $0.title.lowercased().contains(query) || $0.subtitle.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationView {
            List {
                if isLoading {
                    Text(appLocalized("Loading Waktu Zone list..."))
                        .foregroundColor(.secondary)
                } else if let errorMessage, items.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.secondary)
                } else if filteredItems.isEmpty {
                    Text(appLocalized("No Waktu Zones found."))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(filteredItems) { item in
                        Button {
                            onSelect(item)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(item.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if item.id == selectedId {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 2)
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(appLocalized("Close")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(appLocalized("Done")) { dismiss() }
                }
            }
        }
    }
}


#Preview {
    AdhanSetupSheet()
        .environmentObject(Settings.shared)
}
