import SwiftUI

struct AdhanSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: Settings

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Make sure your prayer times are correct")
                        .font(.title3.bold())

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Prayer times are sourced from the Waktu Solat API, and this app currently supports Malaysia only.")
                        
                        Text("""
                            • The app is currently optimized for Malaysia prayer times.
                            • Calculation is fixed to Malaysia for consistency across app and widgets.
                            • If you are outside Malaysia, support for additional regions will be added later.
                            """
                        )
                        .foregroundColor(.secondary)
                    }
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                    
                    Text("After this, take a moment to review your notification settings and appearance preferences.")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                }

                Section(header: Text("PRAYER CALCULATION")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Calculation")
                            Spacer()
                            Text("Malaysia")
                                .foregroundColor(.secondary)
                        }
                        .font(.subheadline)

                        Text("Malaysia prayer times are currently the only supported calculation mode.")
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
                // Keep an internal compatible value while UI is Malaysia-only.
                settings.prayerCalculation = "Singapore"
                settings.hanafiMadhab = false
            }
        }
    }
}


#Preview {
    AdhanSetupSheet()
        .environmentObject(Settings.shared)
}
