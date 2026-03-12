import SwiftUI

struct AdhanSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: Settings
    
    private let globalCalculationMethods: [String] = Settings.globalCalculationMethods
    
    private var isGlobalDebugForced: Bool {
        settings.prayerRegionDebugOverride == 2
    }
    
    private var shouldShowGlobalMethodDropdown: Bool {
        isGlobalDebugForced || !settings.shouldUseMalaysiaPrayerAPI(for: settings.currentLocation)
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
                                Text("Malaysian Prayer Times/ Jakim")
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)

                            Text("Malaysian Prayer Times/ Jakim is currently the only supported calculation mode.")
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
                        }
                    }
                }

                Section(header: Text("DEBUG")) {
                    Picker("Region Override", selection: $settings.prayerRegionDebugOverride) {
                        Text("Auto").tag(0)
                        Text("Malaysia").tag(1)
                        Text("Global").tag(2)
                    }
                    .pickerStyle(.segmented)

                    Text("Use this to test Malaysia (Malaysian Prayer Times/ Jakim) and global coordinate-based Adhan behavior without changing physical location.")
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
        }
    }
}


#Preview {
    AdhanSetupSheet()
        .environmentObject(Settings.shared)
}
