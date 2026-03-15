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
    
    private var selectedCalculationDescription: String {
        switch settings.prayerCalculation {
        case "Auto (By Location)":
            return "Automatically selects a recommended calculation authority based on your detected country."
        case "Jafari / Shia Ithna-Ashari":
            return "Uses the Jafari (Shia Ithna-Ashari) calculation convention."
        case "University of Islamic Sciences, Karachi":
            return "Applies the Karachi method, commonly used in parts of South Asia."
        case "Islamic Society of North America":
            return "Uses ISNA parameters, commonly used in North America."
        case "Muslim World League":
            return "Uses Muslim World League parameters, widely adopted internationally."
        case "Umm Al-Qura University, Makkah":
            return "Uses Umm Al-Qura convention from Makkah, Saudi Arabia."
        case "Egyptian General Authority of Survey":
            return "Uses Egyptian General Authority of Survey parameters."
        case "Institute of Geophysics, University of Tehran":
            return "Uses Tehran University of Geophysics calculation parameters."
        case "Gulf Region":
            return "Uses parameters commonly adopted in Gulf countries."
        case "Kuwait":
            return "Uses Kuwait prayer time calculation parameters."
        case "Qatar":
            return "Uses Qatar prayer time calculation parameters."
        case "Majlis Ugama Islam Singapura, Singapore":
            return "Uses MUIS (Singapore) prayer time calculation parameters."
        case "Union Organization islamic de France":
            return "Uses UOIF calculation parameters used by some communities in France."
        case "Diyanet İşleri Başkanlığı, Turkey":
            return "Uses Diyanet (Turkey) prayer time calculation parameters."
        case "Spiritual Administration of Muslims of Russia":
            return "Uses prayer time parameters from Russia’s Muslim administration."
        case "Moonsighting Committee Worldwide":
            return "Uses Moonsighting Committee Worldwide method with shafaq set to general."
        case "Dubai (experimental)":
            return "Uses Dubai calculation parameters (experimental)."
        case "Jabatan Kemajuan Islam Malaysia (JAKIM)":
            return "Uses JAKIM via Malaysian Prayer Times API."
        case "Tunisia":
            return "Uses Tunisia prayer time calculation parameters."
        case "Algeria":
            return "Uses Algeria prayer time calculation parameters."
        case "KEMENAG - Kementerian Agama Republik Indonesia":
            return "Uses Indonesia KEMENAG prayer time calculation parameters."
        case "Morocco":
            return "Uses Morocco prayer time calculation parameters."
        case "Comunidade Islamica de Lisboa":
            return "Uses Comunidade Islamica de Lisboa prayer time parameters."
        case "Ministry of Awqaf, Islamic Affairs and Holy Places, Jordan":
            return "Uses Jordan Ministry of Awqaf prayer time calculation parameters."
        default:
            return "Uses the selected prayer time calculation method for your location."
        }
    }
    
    private var selectedMalaysiaZoneLabel: String {
        let zone = settings.debugMalaysiaZoneCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !zone.isEmpty else { return "Auto (GPS)" }
        guard let info = malaysiaZones.first(where: { $0.jakimCode.uppercased() == zone }) else {
            return zone
        }
        return "\(info.jakimCode) · \(info.negeri) · \(info.daerah)"
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
                                                Text(method)
                                                if settings.prayerCalculation == method {
                                                    Spacer()
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(settings.prayerCalculation)
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
                    }
                    .font(.subheadline)

                    if releaseWaktuModeBinding.wrappedValue == 1 {
                        Text("Manual mode lets you select a specific Waktu Zone from Malaysian Prayer Times API.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 2)
                    } else {
                        Text("Auto mode uses your current location and keeps Waktu Zone selection disabled.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 2)
                    }
                    #endif

                    if releaseWaktuModeBinding.wrappedValue == 0 {
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
                    } else {
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

                                ForEach(malaysiaZones) { zone in
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

                    Text("Auto matches your location to a Waktu Zone. Manual lets you choose a specific Waktu Zone from Malaysian Prayer Times API.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 2)
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
                // Keep Malaysia path unchanged while allowing non-Malaysia coordinate calculation.
                if !shouldShowGlobalMethodDropdown {
                    settings.prayerCalculation = "Jabatan Kemajuan Islam Malaysia (JAKIM)"
                    settings.hanafiMadhab = false
                } else if settings.prayerCalculation == "Singapore" {
                    // Migrate global users from legacy fixed selection to location-aware mode.
                    settings.prayerCalculation = "Auto (By Location)"
                }
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
            .sheet(isPresented: $showingWaktuZoneReference) {
                WaktuZoneReferenceView(zones: malaysiaZones)
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
