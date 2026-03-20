import SwiftUI

fileprivate struct MalaysiaZoneInfo: Decodable, Identifiable {
    let jakimCode: String
    let negeri: String
    let daerah: String
    var id: String { jakimCode }
}

struct AdhanSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: Settings
    @AppStorage("waktuZoneModeSelection") private var waktuZoneModeSelection: Int = 0
    
    private let globalCalculationMethods: [String] = Settings.globalCalculationMethods
    @State private var malaysiaZones: [MalaysiaZoneInfo] = []
    @State private var autoDetectedZoneCode: String = ""
    @State private var showingWaktuZoneReference = false
    
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
    
    private func shortCalculationLabel(_ method: String) -> String {
        switch method {
        case "Auto (By Location)":                          return "Auto"
        case "Moonsighting Committee Worldwide":            return "Moonsighting (UK)"
        case "Muslim World League":                         return "Muslim World League (US)"
        case "Majlis Ugama Islam Singapura, Singapore":     return "MUIS (Singapore)"
        case "Jabatan Kemajuan Islam Malaysia (JAKIM)":     return "JAKIM (Malaysia)"
        default:                                            return method
        }
    }

    private var resolvedAutoMethodLabel: String {
        switch settings.currentLocation?.countryCode?.uppercased() ?? "" {
        case "MY": return "JAKIM (Malaysia)"
        case "SG": return "MUIS (Singapore)"
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
    
    /// Zones filtered to the user's current country.
    /// SG → only SGP01; everything else → Malaysian JAKIM zones.
    private var filteredZones: [MalaysiaZoneInfo] {
        let country = settings.currentLocation?.countryCode?.uppercased() ?? ""
        switch country {
        case "SG":
            return [MalaysiaZoneInfo(jakimCode: "SGP01", negeri: "Singapore", daerah: "Singapore")]
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
    
    @MainActor
    private func loadMalaysiaZonesIfNeeded() async {
        guard malaysiaZones.isEmpty else { return }
        // Singapore only has one known zone (SGP01) — no need to fetch the Malaysian list
        guard settings.currentLocation?.countryCode?.uppercased() != "SG" else { return }
        guard let url = URL(string: "https://api-waktusolat.vercel.app/zones") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard status == 200 else { return }
            let decoded = try JSONDecoder().decode([MalaysiaZoneInfo].self, from: data)
            malaysiaZones = decoded.sorted { $0.jakimCode < $1.jakimCode }
        } catch {
            // Keep silent in debug UI; manual code entry is not needed with fallback Auto.
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
                        Text(settings.currentLocation?.city ?? "Unknown")
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .truncationMode(.tail)
                    }
                    .font(.subheadline)

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
                    if !shouldShowGlobalMethodDropdown || isSingaporeMode {
                        Picker("Mode", selection: releaseWaktuModeBinding) {
                            Text("Auto").tag(0)
                            Text("Manual").tag(1)
                        }
                        .pickerStyle(.segmented)
                    }

                    HStack {
                        Text("Location")
                        Spacer()
                        Text(settings.currentLocation?.city ?? "Unknown")
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .font(.subheadline)

                    if !shouldShowGlobalMethodDropdown || isSingaporeMode {
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

                    if (!shouldShowGlobalMethodDropdown || isSingaporeMode) && releaseWaktuModeBinding.wrappedValue == 0 {
                        HStack {
                            HStack(spacing: 6) {
                                Text("Waktu Zone")
                                Button {
                                    showingWaktuZoneReference = true
                                } label: {
                                    Image(systemName: "info.circle")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(autoDetectedZoneLabel)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .truncationMode(.tail)
                        }
                        .font(.subheadline)
                    } else if (!shouldShowGlobalMethodDropdown || isSingaporeMode) {
                        HStack {
                            HStack(spacing: 6) {
                                Text("Waktu Zone")
                                Button {
                                    showingWaktuZoneReference = true
                                } label: {
                                    Image(systemName: "info.circle")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.secondary)
                            }
                            Spacer()
                            Menu {
                                Button {
                                    settings.debugMalaysiaZoneCode = ""
                                } label: {
                                    HStack {
                                        Text("Auto (GPS)")
                                        if settings.debugMalaysiaZoneCode.isEmpty {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }

                                ForEach(filteredZones) { zone in
                                    Button {
                                        settings.debugMalaysiaZoneCode = zone.jakimCode
                                        settings.prayerCalculation = "Jabatan Kemajuan Islam Malaysia (JAKIM)"
                                        settings.hanafiMadhab = false
                                    } label: {
                                        HStack {
                                            Text("\(zone.jakimCode) · \(zone.negeri) · \(zone.daerah)")
                                            if settings.debugMalaysiaZoneCode.uppercased() == zone.jakimCode.uppercased() {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(selectedMalaysiaZoneLabel)
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
                    }

                    if !shouldShowGlobalMethodDropdown || isSingaporeMode {
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
                Task { await refreshAutoDetectedZone() }
            }
            .sheet(isPresented: $showingWaktuZoneReference) {
                WaktuZoneReferenceView(zones: filteredZones)
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
                } else if settings.debugMalaysiaZoneCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          !detectedZone.isEmpty {
                    settings.debugMalaysiaZoneCode = detectedZone
                    settings.prayerCalculation = "Jabatan Kemajuan Islam Malaysia (JAKIM)"
                    settings.hanafiMadhab = false
                } else if settings.debugMalaysiaZoneCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Task { @MainActor in
                        await refreshAutoDetectedZone()
                    }
                }
            }
        )
    }
}

private struct WaktuZoneReferenceView: View {
    @Environment(\.dismiss) private var dismiss
    let zones: [MalaysiaZoneInfo]

    var body: some View {
        NavigationView {
            List {
                if zones.isEmpty {
                    Text("Loading Waktu Zone list...")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(zones) { zone in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(zone.jakimCode) · \(zone.negeri)")
                                .font(.subheadline.weight(.semibold))
                            Text(zone.daerah)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Waktu Zones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
