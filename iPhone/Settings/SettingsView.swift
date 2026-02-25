import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

#if canImport(RevenueCat)
@MainActor
final class RevenueCatManager: NSObject, ObservableObject, PurchasesDelegate {
    static let shared = RevenueCatManager()

    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var offerings: Offerings?
    @Published var lastErrorMessage: String?

    private let apiKey = "appl_QOZtAKefwKDyLWNlFADoOQkLgcl"
    let entitlementID = "buy_me_kopi"
    private(set) var isConfigured = false

    private override init() {
        super.init()
    }

    func configure() {
        guard !isConfigured else { return }
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif

        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = self
        isConfigured = true

        Task {
            await refreshCustomerInfo()
            await refreshOfferings()
        }
    }

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        self.customerInfo = customerInfo
    }

    func refreshCustomerInfo() async {
        do {
            customerInfo = try await Purchases.shared.customerInfo()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func refreshOfferings() async {
        do {
            offerings = try await Purchases.shared.offerings()
            #if DEBUG
            let ids = offerings?.all.keys.sorted() ?? []
            print("RevenueCat offerings:", ids, "current:", offerings?.current?.identifier ?? "nil")
            #endif
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    var hasBuyMeKopi: Bool {
        customerInfo?.entitlements[entitlementID]?.isActive == true
    }

    func restorePurchases() {
        Purchases.shared.restorePurchases { [weak self] info, error in
            guard let self else { return }
            if let error {
                self.lastErrorMessage = error.localizedDescription
                return
            }
            self.customerInfo = info
        }
    }

    func clearLastError() {
        lastErrorMessage = nil
    }
}
#else
@MainActor
final class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()
    @Published var lastErrorMessage: String?
    let entitlementID = "buy_me_kopi"
    var hasBuyMeKopi: Bool { false }

    func configure() {
        lastErrorMessage = "RevenueCat SDK not available in this build."
    }

    func refreshCustomerInfo() async {}
    func refreshOfferings() async {}
    func restorePurchases() {}
    func clearLastError() { lastErrorMessage = nil }
}
#endif

struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var revenueCat: RevenueCatManager
    
    @State private var showingCredits = false
    @State private var showingPaywall = false
    private let paywallOfferingIdentifier = "Waktu Donation"

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("APPEARANCE")) {
                    SettingsAppearanceView()
                }
                
                Section(header: Text("CREDITS")) {
                    Text("Made by developers at Risk Creatives, powered by the Waktu Solat Project API.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    #if !os(watchOS)
                    Button(action: {
                        settings.hapticFeedback()
                        
                        showingCredits = true
                    }) {
                        Label("View Credits", systemImage: "scroll.fill")
                            .font(.subheadline)
                            .foregroundColor(settings.accentColor.color)
                    }
                    .sheet(isPresented: $showingCredits) {
                        CreditsView()
                    }
                    #endif
                    
                    VersionNumber()
                        .font(.subheadline)
                }

                Section(header: Text("SUPPORT")) {
                    Button {
                        settings.hapticFeedback()
                        Task {
                            await revenueCat.refreshOfferings()
                            if revenueCat.offerings?.all[paywallOfferingIdentifier] != nil {
                                showingPaywall = true
                            } else {
                                let available = revenueCat.offerings?.all.keys.sorted().joined(separator: ", ") ?? "none"
                                revenueCat.lastErrorMessage = "Offering '\(paywallOfferingIdentifier)' not found. Available offerings: \(available)"
                            }
                        }
                    } label: {
                        Label("Buy Me a Coffee", systemImage: "cup.and.saucer.fill")
                            .foregroundColor(settings.accentColor.color)
                    }
                }
            }
            .navigationTitle("Settings")
            .applyConditionalListStyle(defaultView: true)
        }
        .navigationViewStyle(.stack)
        .task {
            revenueCat.configure()
            await revenueCat.refreshCustomerInfo()
            await revenueCat.refreshOfferings()
        }
        .sheet(isPresented: $showingPaywall) {
            paywallSheet
        }
        .alert("Purchase Error", isPresented: Binding(
            get: { revenueCat.lastErrorMessage != nil },
            set: { if !$0 { revenueCat.clearLastError() } }
        )) {
            Button("OK", role: .cancel) {
                revenueCat.clearLastError()
            }
        } message: {
            Text(revenueCat.lastErrorMessage ?? "Unknown error")
        }
    }

    @ViewBuilder
    private var paywallSheet: some View {
        #if canImport(RevenueCatUI)
        if let selectedOffering = revenueCat.offerings?.all[paywallOfferingIdentifier] {
            PaywallView(offering: selectedOffering, displayCloseButton: true)
        } else {
            NavigationView {
                Text("Offering '\(paywallOfferingIdentifier)' was not returned by RevenueCat.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .navigationTitle("Support")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        #else
        NavigationView {
            Text("RevenueCatUI not installed.")
                .foregroundColor(.secondary)
                .navigationTitle("Support")
                .navigationBarTitleDisplayMode(.inline)
        }
        #endif
    }
}

struct SettingsAppearanceView: View {
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        #if !os(watchOS)
        Picker("Color Theme", selection: $settings.colorSchemeString.animation(.easeInOut)) {
            Text("System").tag("system")
            Text("Light").tag("light")
            Text("Dark").tag("dark")
        }
        .font(.subheadline)
        .pickerStyle(SegmentedPickerStyle())
        #endif
        
        VStack(alignment: .leading) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ], spacing: 12) {
                ForEach(accentColors, id: \.self) { accentColor in
                    Circle()
                        .fill(accentColor.color)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(settings.accentColor == accentColor ? Color.primary : Color.clear, lineWidth: 1)
                        )
                        .onTapGesture {
                            settings.hapticFeedback()
                            
                            withAnimation {
                                settings.accentColor = accentColor
                            }
                        }
                }
            }
            .padding(.vertical)
            
            #if !os(watchOS)
            Text("Anas ibn Malik (may Allah be pleased with him) said, “The most beloved of colors to the Messenger of Allah (peace be upon him) was green.”")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 2)
            #endif
        }
        
        #if !os(watchOS)
        VStack(alignment: .leading) {
            Toggle("Default List View", isOn: $settings.defaultView.animation(.easeInOut))
                .font(.subheadline)
                .tint(settings.accentColor.toggleTint)
            
            Text("The default list view is the standard interface found in many of Apple's first party apps, including Notes. This setting applies everywhere in the app except here in Settings.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 2)
        }
        #endif
        
        VStack(alignment: .leading) {
            Toggle("Haptic Feedback", isOn: $settings.hapticOn.animation(.easeInOut))
                .font(.subheadline)
                .tint(settings.accentColor.toggleTint)
        }
    }
}

struct VersionNumber: View {
    @EnvironmentObject var settings: Settings
    
    var width: CGFloat?
    
    var body: some View {
        HStack {
            if let width = width {
                Text("Version:")
                    .frame(width: width)
            } else {
                Text("Version")
            }
            
            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                .foregroundColor(settings.accentColor.color)
                .padding(.leading, -4)
        }
        .foregroundColor(.primary)
    }
}
