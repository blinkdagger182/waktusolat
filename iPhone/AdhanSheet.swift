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
    
    private func shortCalculationLabel(_ method: String) -> String {
        switch method {
        case "Auto (By Location)":                                          return "Auto"
        case "Moonsighting Committee Worldwide":                            return "Moonsighting (UK)"
        case "Muslim World League":                                         return "Muslim World League (US)"
        case "Majlis Ugama Islam Singapura, Singapore":                     return "MUIS (Singapore)"
        case "Jabatan Kemajuan Islam Malaysia (JAKIM)":                     return "JAKIM (Malaysia)"
        case "KEMENAG - Kementerian Agama Republik Indonesia":              return "KEMENAG (Indonesia)"
        default:                                                            return method
        }
    }

    private var resolvedAutoMethodLabel: String {
        switch settings.currentLocation?.countryCode?.uppercased() ?? "" {
        case "MY": return "JAKIM (Malaysia)"
        case "SG": return "MUIS (Singapore)"
        case "ID": return "KEMENAG (Indonesia)"
        case "GB": return "Moonsighting Committee Worldwide"
        case "US", "CA": return "Muslim World League"
        default: return "Muslim World League"
        }
    }

    private var selectedCalculationDescription: String {
        switch settings.prayerCalculation {
        case "Auto (By Location)":
            return "Automatically selects the recommended authority based on your detected country."
        case "Moonsighting Committee Worldwide":
            return "Used in the UK and many Western countries. Based on moon sighting with shafaq set to general."
        case "Muslim World League":
            return "Widely used in the US and internationally. Uses Muslim World League calculation parameters."
        case "Majlis Ugama Islam Singapura, Singapore":
            return "Official Singapore prayer times by MUIS (Majlis Ugama Islam Singapura)."
        case "Jabatan Kemajuan Islam Malaysia (JAKIM)":
            return "Official Malaysian prayer times by JAKIM. Uses the Malaysian Prayer Times API."
        case "KEMENAG - Kementerian Agama Republik Indonesia":
            return "Official Indonesia prayer times by KEMENAG, matched to your kabupaten/kota via GPS."
        default:
            return "Uses the selected prayer time calculation method for your location."
        }
    }
    
    private var selectedMalaysiaZoneLabel: String {
        let zone = settings.debugMalaysiaZoneCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !zone.isEmpty else { return "Auto (GPS)" }
        guard let info = filteredZones.first(where: { $0.jakimCode.uppercased() == zone }) else {
            return zone
        }
        return "\(info.jakimCode) · \(info.negeri) · \(info.daerah)"
    }

    private var selectedIndonesiaZoneLabel: String {
        let regionId = settings.debugIndonesiaRegionId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !regionId.isEmpty else { return "Auto (GPS)" }
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
        let zone = autoDetectedZoneCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !zone.isEmpty else { return "Detecting..." }
        guard let info = malaysiaZones.first(where: { $0.jakimCode.uppercased() == zone }) else {
            return zone
        }
        return "\(info.jakimCode) · \(info.negeri) · \(info.daerah)"
    }

    private var autoDetectedIndonesiaZoneLabel: String {
        settings.currentIndonesiaWaktuZoneName ?? "Detecting..."
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
                waktuZoneLoadError = "Could not load Malaysia Waktu Zones."
                return
            }
            let decoded = try JSONDecoder().decode([MalaysiaZoneInfo].self, from: data)
            malaysiaZones = decoded.sorted { $0.jakimCode < $1.jakimCode }
        } catch {
            waktuZoneLoadError = "Could not load Malaysia Waktu Zones."
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
                waktuZoneLoadError = "Could not load Indonesia prayer zones."
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
            waktuZoneLoadError = "Could not load Indonesia prayer zones."
        }
    }
    
    @MainActor
    private func refreshAutoDetectedZone() async {
        guard let location = settings.currentLocation else {
            autoDetectedZoneCode = ""
            return
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
            settings.prayerCalculation = "Moonsighting Committee Worldwide"
        case "US", "CA":
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
        } else {
            waktuZoneModeSelection = 1
            settings.debugMalaysiaZoneCode = id
            settings.debugIndonesiaRegionId = ""
            settings.prayerCalculation = "Jabatan Kemajuan Islam Malaysia (JAKIM)"
            settings.hanafiMadhab = false
        }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Make sure your prayer times are correct")
                        .font(.title3.bold())

                    VStack(alignment: .leading, spacing: 10) {
                        if !shouldShowGlobalMethodDropdown {
                            Text("Prayer times are sourced from Malaysian Prayer Times, and this app currently supports Malaysia only.")

                            Text("""
                                • The app is currently optimized for Malaysia prayer times.
                                • Calculation is fixed to Malaysia for consistency across app and widgets.
                                """
                            )
                            .foregroundColor(.secondary)
                        } else if isSingaporeMode {
                            Text("Prayer times are sourced from MUIS (Majlis Ugama Islam Singapura), Singapore's official Islamic religious authority.")

                            Text("""
                                • The app is currently optimized for Singapore prayer times.
                                • Times are fetched from our backend, sourced directly from MUIS.
                                • Calculation is fixed to MUIS for consistency across app and widgets.
                                """
                            )
                            .foregroundColor(.secondary)
                        } else if isIndonesiaMode {
                            Text("Prayer times are sourced from KEMENAG (Kementerian Agama Republik Indonesia), Indonesia's official ministry of religious affairs.")

                            Text("""
                                • The app is currently optimized for Indonesia prayer times.
                                • Times are fetched from our backend, sourced directly from KEMENAG.
                                • Calculation is automatically matched to your exact kabupaten/kota.
                                """
                            )
                            .foregroundColor(.secondary)
                        } else {
                            Text("Prayer times are calculated from your current coordinates using trusted Adhan methods.")

                            Text("""
                                • You can choose the most suitable local calculation method.
                                • Traveling mode and prayer offsets still apply.
                                • You can use debug override below to test both paths quickly.
                                """
                            )
                            .foregroundColor(.secondary)
                        }
                    }
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                    
                    Text("After this, take a moment to review your notification settings and appearance preferences.")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                }

                Section(header: Text("PRAYER CALCULATION")) {
                    VStack(alignment: .leading) {
                        if !shouldShowGlobalMethodDropdown {
                            HStack {
                                Text("Calculation")
                                Spacer()
                                Text("Malaysian Prayer Times/ JAKIM")
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)

                            Text(selectedCalculationDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 2)
                        } else if isSingaporeMode {
                            HStack {
                                Text("Calculation")
                                Spacer()
                                Text("MUIS (Singapore)")
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)

                            Text("Official Singapore prayer times by MUIS (Majlis Ugama Islam Singapura), the official Islamic authority of Singapore.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 2)
                        } else if isIndonesiaMode {
                            HStack {
                                Text("Calculation")
                                Spacer()
                                Text("KEMENAG (Indonesia)")
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)

                            Text("Official Indonesia prayer times by KEMENAG, automatically matched to your kabupaten/kota using GPS polygon lookup.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 2)
                        } else {
                            HStack {
                                Text("Calculation")
                                Spacer()
                                Menu {
                                    ForEach(globalCalculationMethods, id: \.self) { method in
                                        Button {
                                            settings.prayerCalculation = method
                                        } label: {
                                            HStack {
                                                Text(shortCalculationLabel(method))
                                                if settings.prayerCalculation == method {
                                                    Spacer()
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(shortCalculationLabel(settings.prayerCalculation))
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
                                    Text("Using \(resolvedAutoMethodLabel)")
                                        .font(.caption)
                                }
                                .foregroundColor(settings.accentColor.color)
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }

                Section(header: Text(debugSectionTitle)) {
                    #if DEBUG
                    Picker("Region Override", selection: $settings.prayerRegionDebugOverride) {
                        Text("Auto").tag(0)
                        Text("Malaysia").tag(1)
                        Text("Global").tag(2)
                    }
                    .pickerStyle(.segmented)
                    
                    Picker("Mode", selection: releaseWaktuModeBinding) {
                        Text("Auto").tag(0)
                        Text("Manual").tag(1)
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Text("Location")
                        Spacer()
                        Text(settings.currentPhoneLocationName ?? settings.currentPrayerAreaName ?? "Unknown")
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .truncationMode(.tail)
                    }
                    .font(.subheadline)

                    if let waktuZone = settings.currentIndonesiaWaktuZoneName {
                        Text("Waktu Zone: \(waktuZone)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 2)
                    } else if settings.isResolvingIndonesiaWaktuZone {
                        Text("Resolving Waktu Zone...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 2)
                    }

                    Text("Location is read-only. Use Waktu Zone in Manual mode for testing.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 2)

                    Text("Use this to test Malaysia (Malaysian Prayer Times/ JAKIM) and global coordinate-based Adhan behavior without changing physical location.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 2)
                    #endif
                    
                    #if !DEBUG
                    if canConfigureWaktuZone {
                        Picker("Mode", selection: releaseWaktuModeBinding) {
                            Text("Auto").tag(0)
                            Text("Manual").tag(1)
                        }
                        .pickerStyle(.segmented)
                    }

                    HStack {
                        Text("Location")
                        Spacer()
                        Text(settings.currentPhoneLocationName ?? settings.currentPrayerAreaName ?? "Unknown")
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .font(.subheadline)

                    if let waktuZone = settings.currentIndonesiaWaktuZoneName {
                        Text("Waktu Zone: \(waktuZone)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 2)
                    } else if settings.isResolvingIndonesiaWaktuZone {
                        Text("Resolving Waktu Zone...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 2)
                    }

                    if canConfigureWaktuZone {
                        if releaseWaktuModeBinding.wrappedValue == 1 {
                            Text("Manual mode lets you select a specific Waktu Zone.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 2)
                        } else {
                            Text("Auto mode uses your current location to determine the prayer zone.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 2)
                        }
                    }

                    #endif

                    if canConfigureWaktuZone {
                        Button(action: openWaktuZonePicker) {
                            HStack {
                                Text("Waktu Zone")
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
                        Text("Auto matches your location to a prayer zone. Manual lets you choose a specific zone.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 2)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Waktu Solat Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
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
        return "PRAYER MODE"
    }

    private var releaseWaktuModeBinding: Binding<Int> {
        Binding(
            get: { waktuZoneModeSelection },
            set: { newValue in
                waktuZoneModeSelection = newValue
                let detectedZone = autoDetectedZoneCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                if newValue == 0 {
                    settings.debugMalaysiaZoneCode = ""
                    settings.debugIndonesiaRegionId = ""
                } else if isIndonesiaMode {
                    if settings.debugIndonesiaRegionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       let resolvedPrayerArea = settings.resolvedPrayerArea {
                        settings.debugIndonesiaRegionId = resolvedPrayerArea.regionId
                    }
                } else if settings.debugMalaysiaZoneCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if !detectedZone.isEmpty {
                        settings.debugMalaysiaZoneCode = detectedZone
                        settings.prayerCalculation = "Jabatan Kemajuan Islam Malaysia (JAKIM)"
                        settings.hanafiMadhab = false
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
                    Text("Loading Waktu Zone list...")
                        .foregroundColor(.secondary)
                } else if let errorMessage, items.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.secondary)
                } else if filteredItems.isEmpty {
                    Text("No Waktu Zones found.")
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
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}


#Preview {
    AdhanSetupSheet()
        .environmentObject(Settings.shared)
}
