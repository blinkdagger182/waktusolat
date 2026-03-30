import SwiftUI

struct WatchSettingsView: View {
    @EnvironmentObject private var store: WatchPrayerStore

    var body: some View {
        List {
            Section(store.language.isMalay ? "Sumber" : "Source") {
                infoRow(title: store.language.isMalay ? "Lokasi" : "Location", value: store.city)
                infoRow(title: store.language.isMalay ? "Kiraan" : "Calculation", value: store.sourceLabel)
                infoRow(title: store.language.isMalay ? "Negara" : "Country", value: store.countryCode ?? "GLOBAL")
            }

            if store.countryCode == "BN" {
                Section(store.language.isMalay ? "Brunei" : "Brunei") {
                    Text(store.storedDhuha != nil
                         ? (store.language.isMalay ? "Dhuha dibaca daripada data backend MORA yang diselaraskan." : "Dhuha is read from the synced MORA backend data.")
                         : (store.language.isMalay ? "Dhuha akan muncul selepas app iPhone menyegarkan cache Brunei." : "Dhuha will appear after the iPhone app refreshes the Brunei cache."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section(store.language.isMalay ? "Segar Semula" : "Refresh") {
                Button(store.language.isMalay ? "Muat Semula dari iPhone" : "Reload from iPhone") {
                    store.reload()
                }

                if let lastRefreshAt = store.lastRefreshAt {
                    Text(lastRefreshAt, style: .time)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Info")
        .task {
            store.reload()
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .lineLimit(2)
        }
    }
}

#Preview {
    NavigationStack {
        WatchSettingsView()
            .environmentObject(WatchPrayerStore())
    }
}
