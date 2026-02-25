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

                    Text("Made by developers at Risk Creatives.")
                        .font(.headline)
                    if let url = URL(string: "https://api.waktusolat.app/") {
                        Link("Powered by the Waktu Solat Project API", destination: url)
                            .foregroundColor(settings.accentColor.color)
                    }
                }

                Section {
                    Text("""
                    We built Waktu Solat to stay free, simple, and genuinely useful every day.
                    The goal is a clean widget and app experience that gently reminds us of prayer times, without clutter.
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
