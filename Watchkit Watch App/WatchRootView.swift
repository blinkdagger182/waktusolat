import SwiftUI

struct WatchRootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                WatchAzanView()
            }
            .tabItem {
                Label("Waktu", systemImage: "bell.fill")
            }

            NavigationStack {
                WatchSettingsView()
            }
            .tabItem {
                Label("Info", systemImage: "gearshape.fill")
            }
        }
    }
}

#Preview {
    WatchRootView()
        .environmentObject(WatchPrayerStore())
}
