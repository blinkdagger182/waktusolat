import SwiftUI

struct CreditsView: View {
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Image("developer")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.vertical, 6)

                    Text("Made by developer from Risk Creatives.")
                        .font(.headline)
                    if let url = URL(string: "https://api.waktusolat.app/") {
                        Link("Powered by Waktu Solat Project API", destination: url)
                            .foregroundColor(settings.accentColor.color)
                    }
                }

                Section {
                    Text("""
                    This fork focuses on a clean prayer-time experience with minimal UI and widget-first usability.
                    """)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                }
                
                Section {
                    VersionNumber()
                        .font(.caption)
                }
            }
            .listStyle(.plain)
            .navigationBarTitleDisplayMode(.inline)
            .accentColor(settings.accentColor.color)
            .tint(settings.accentColor.color)
            .navigationTitle("Credits")
        }
    }
}
