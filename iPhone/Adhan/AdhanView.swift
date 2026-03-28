import SwiftUI

private struct DailyQuranCachedQuote: Codable {
    let dayKey: String
    let reference: String
    let text: String
    let surahName: String
}

struct AdhanView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var namesData: NamesViewModel
    @Environment(\.openURL) private var openURL
    
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var showingSettingsSheet = false
    @State private var showBigQibla = false
    @State private var showDailyQuranAccordion = false
    @State private var dailyQuranQuote: DailyQuranCachedQuote?
    
    @State private var showAlert: AlertType?
    enum AlertType: Identifiable {
        case travelTurnOnAutomatic, travelTurnOffAutomatic, locationAlert, notificationAlert

        var id: Int {
            switch self {
            case .travelTurnOnAutomatic: return 1
            case .travelTurnOffAutomatic: return 2
            case .locationAlert: return 3
            case .notificationAlert: return 4
            }
        }
    }
    
    func prayerTimeRefresh(force: Bool) {
        // Always request a fresh location when user refreshes the page.
        // This ensures prayer data re-fetch uses the newest detected place.
        settings.requestLocationAuthorization()

        settings.fetchPrayerTimes(force: force) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if settings.travelTurnOnAutomatic {
                    showAlert = .travelTurnOnAutomatic
                } else if settings.travelTurnOffAutomatic {
                    showAlert = .travelTurnOffAutomatic
                } else if !settings.locationNeverAskAgain && settings.showLocationAlert {
                    showAlert = .locationAlert
                } else if !settings.notificationNeverAskAgain && settings.showNotificationAlert {
                    showAlert = .notificationAlert
                }
            }
        }
    }

    private func loadDailyQuranQuote() {
        let defaults = UserDefaults(suiteName: "group.app.riskcreatives.waktu")
        guard
            let data = defaults?.data(forKey: "dailyInspirationCachedQuoteV2")
                ?? defaults?.data(forKey: "dailyInspirationCachedQuoteV1"),
            let cached = try? JSONDecoder().decode(DailyQuranCachedQuote.self, from: data)
        else {
            dailyQuranQuote = nil
            return
        }
        dailyQuranQuote = cached
    }

    private func openDailyQuranModal() {
        guard let reference = dailyQuranQuote?.reference else { return }
        var components = URLComponents()
        components.scheme = "waktu"
        components.host = "quran"
        components.queryItems = [URLQueryItem(name: "reference", value: reference)]
        if let url = components.url {
            openURL(url)
        }
    }

    private func postUIHeartbeat() {
        NotificationCenter.default.post(name: .uiContentHeartbeat, object: nil)
    }

    @ViewBuilder
    private var dateAndLocationSection: some View {
        Section(header: settings.defaultView ? Text("DATE AND LOCATION") : nil) {
            if let hijriDate = settings.hijriDate {
                hijriDateRow(hijriDate)
            }

            locationCard

            if settings.shouldPromptSetAutoForPrayerLocationMismatch {
                prayerLocationAutoPrompt
            }
        }
    }

    @ViewBuilder
    private func hijriDateRow(_ hijriDate: HijriDate) -> some View {
        #if !os(watchOS)
        NavigationLink(destination: HijriCalendarView()) {
            HStack {
                Text(hijriDate.english)
                    .multilineTextAlignment(.center)

                Spacer()

                Text(hijriDate.arabic)
            }
            .font(.footnote)
            .foregroundColor(settings.accentColor.color)
            .contextMenu {
                Button(action: {
                    settings.hapticFeedback()
                    UIPasteboard.general.string = hijriDate.english
                }) {
                    Text("Copy English Date")
                    Image(systemName: "doc.on.doc")
                }

                Button(action: {
                    settings.hapticFeedback()
                    UIPasteboard.general.string = hijriDate.arabic
                }) {
                    Text("Copy Arabic Date")
                    Image(systemName: "doc.on.doc")
                }
            }
        }
        #else
        HStack {
            Spacer()

            Text(hijriDate.english)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .font(.footnote)
        .foregroundColor(settings.accentColor.color)
        #endif
    }

    @ViewBuilder
    private var locationCard: some View {
        VStack {
            HStack {
                #if !os(watchOS)
                if let currentLoc = settings.currentLocation {
                    let currentDisplayLocation = settings.effectivePrayerLocationDisplayName ?? currentLoc.city
                    let shouldDisplayWaktuZoneTag = settings.shouldDisplayWaktuZoneTag
                    let currentWaktuZone = shouldDisplayWaktuZoneTag ? settings.currentWaktuZoneName : nil
                    let isResolvingWaktuZone = shouldDisplayWaktuZoneTag && settings.isResolvingAnyWaktuZone

                    Image(systemName: "location.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundColor(settings.accentColor.color)
                        .padding(.trailing, 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentDisplayLocation)
                            .font(.subheadline)
                            .lineLimit(nil)

                        if let currentWaktuZone {
                            Text("Waktu Zone: \(currentWaktuZone)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        if isResolvingWaktuZone {
                            Text("Resolving Waktu Zone...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .contextMenu {
                        Button(action: {
                            settings.hapticFeedback()
                            UIPasteboard.general.string = currentDisplayLocation
                        }) {
                            Text("Copy Address")
                            Image(systemName: "doc.on.doc")
                        }

                        if let currentWaktuZone {
                            Button(action: {
                                settings.hapticFeedback()
                                UIPasteboard.general.string = currentWaktuZone
                            }) {
                                Text("Copy Waktu Zone")
                                Image(systemName: "doc.on.doc")
                            }
                        }
                    }
                } else {
                    Image(systemName: "location.slash")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundColor(settings.accentColor.color)
                        .padding(.trailing, 8)

                    Text("No location")
                        .font(.subheadline)
                        .lineLimit(nil)
                }
                #else
                Group {
                    if settings.prayers != nil, let currentLoc = settings.currentLocation {
                        Text(currentLoc.city)
                    } else {
                        Text("No location")
                    }
                }
                .font(.subheadline)
                .lineLimit(2)
                #endif

                Spacer()

                QiblaView(size: showBigQibla ? 100 : 50)
                    .padding(.horizontal)
            }
            .foregroundColor(.primary)
            .font(.subheadline)
            .contentShape(Rectangle())

            #if os(watchOS)
            Text("Compass may not be accurate on Apple Watch")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            #endif
        }
        .animation(.easeInOut, value: showBigQibla)
        #if !os(watchOS)
        .onTapGesture {
            withAnimation {
                settings.hapticFeedback()
                showBigQibla.toggle()
            }
        }
        #endif
    }

    private var prayerLocationAutoPrompt: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(settings.prayerLocationMismatchMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)

            Spacer(minLength: 12)

            Button(settings.prayerLocationAutoPromptText) {
                settings.setPrayerLocationModeToAuto()
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 2)
    }

    var body: some View {
        NavigationView {
            List {
//                Section(header: settings.defaultView ? Text("DAILY QURAN") : nil) {
//                    DisclosureGroup(isExpanded: $showDailyQuranAccordion) {
//                        if let quote = dailyQuranQuote {
//                            Button(action: openDailyQuranModal) {
//                                VStack(alignment: .leading, spacing: 6) {
//                                    Text(quote.text)
//                                        .font(.footnote.weight(.semibold))
//                                        .multilineTextAlignment(.leading)
//                                        .foregroundColor(.primary)
//                                        .frame(maxWidth: .infinity, alignment: .leading)
//                                    Text("\(quote.surahName) \(quote.reference)")
//                                        .font(.caption)
//                                        .foregroundColor(.secondary)
//                                        .frame(maxWidth: .infinity, alignment: .leading)
//                                }
//                                .padding(.vertical, 4)
//                            }
//                            .buttonStyle(.plain)
//                        } else {
//                            Text("Open the Daily Quran lock screen widget once to load today’s summary here.")
//                                .font(.caption)
//                                .foregroundColor(.secondary)
//                        }
//                    } label: {
//                        HStack(spacing: 10) {
//                            Image(systemName: "book.closed.fill")
//                                .foregroundColor(settings.accentColor.color)
//                            Text("Daily Quran")
//                                .font(.subheadline.weight(.semibold))
//                                .foregroundColor(.primary)
//                        }
//                    }
//                }

                DateAndLocationSectionView(showBigQibla: $showBigQibla)
                    .environmentObject(settings)
                
                #if !os(watchOS)
                if settings.prayers != nil && settings.currentLocation != nil {
                    PrayerCountdown()
                    PrayerList()
                }
                #else
                if settings.prayers != nil {
                    PrayerCountdown()
                    PrayerList()
                }
                #endif
            }
            .refreshable {
                prayerTimeRefresh(force: true)
            }
            .onAppear {
                postUIHeartbeat()
                prayerTimeRefresh(force: false)
                loadDailyQuranQuote()
            }
            .onChange(of: scenePhase) { newScenePhase in
                if newScenePhase == .active {
                    postUIHeartbeat()
                    prayerTimeRefresh(force: false)
                    loadDailyQuranQuote()
                }
            }
            .navigationTitle("Waktu Solat")
            #if !os(watchOS)
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .navigationBarLeading) { EmptyView() }
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            NotificationCenter.default.post(name: .debugShowDailyQuranWidgetIntro, object: nil)
                        } label: {
                            Label("Show Daily Quran Intro", systemImage: "book")
                        }

                        Divider()

                        Button {
                            NotificationCenter.default.post(name: .debugShowSupportPromoToastVariant, object: "generic")
                        } label: {
                            Label("Donation Toast (Generic)", systemImage: "heart")
                        }

                        Button {
                            NotificationCenter.default.post(name: .debugShowSupportPromoToastVariant, object: "launch-5")
                        } label: {
                            Label("Donation Toast (Launch 5)", systemImage: "5.circle")
                        }

                        Button {
                            NotificationCenter.default.post(name: .debugShowSupportPromoToastVariant, object: "launch-6")
                        } label: {
                            Label("Donation Toast (Launch 6)", systemImage: "6.circle")
                        }

                        Button {
                            NotificationCenter.default.post(name: .debugShowSupportPromoToastVariant, object: "streak-7")
                        } label: {
                            Label("Donation Toast (Streak 7)", systemImage: "flame")
                        }

                        Button {
                            NotificationCenter.default.post(name: .debugShowSupportPromoToastVariant, object: "eid-pool")
                        } label: {
                            Label("Donation Toast (Eid Pool)", systemImage: "moon.stars")
                        }

                        Button {
                            NotificationCenter.default.post(name: .debugShowSupportPromoToastVariant, object: "month-pool")
                        } label: {
                            Label("Donation Toast (Monthly Pool)", systemImage: "calendar")
                        }

                        Divider()

                        Button {
                            NotificationCenter.default.post(name: .debugShowMalaysiaLocationToast, object: nil)
                        } label: {
                            Label("Malaysia Location Toast", systemImage: "mappin.circle")
                        }
                    } label: {
                        Image(systemName: "ladybug")
                    }
                    .accessibilityLabel("Debug options")
                }
                #endif

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        settings.hapticFeedback()
                        
                        showingSettingsSheet = true
                    } label: {
                        Image(systemName: "gear")
                        }
                    }
                }
            .sheet(isPresented: $showingSettingsSheet) {
                SettingsView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSupportSettingsSheet)) { _ in
                settings.hapticFeedback()
                showingSettingsSheet = true
            }
            #endif
            .applyConditionalListStyle(defaultView: settings.defaultView)
        }
        .confirmationDialog("", isPresented: Binding(
            get: { showAlert != nil },
            set: { if !$0 { showAlert = nil } }
        ), titleVisibility: .visible) {
            switch showAlert {
            case .travelTurnOnAutomatic:
                Button("Override: Turn Off", role: .destructive) {
                    settings.travelingModeManuallyToggled = true
                    withAnimation {
                        settings.travelingMode = false
                    }
                    settings.travelAutomatic = false
                    settings.travelTurnOnAutomatic = false
                    settings.travelTurnOffAutomatic = false
                    settings.fetchPrayerTimes(force: true)
                }
                
                Button("Confirm: Keep On", role: .cancel) {
                    settings.travelTurnOnAutomatic = false
                    settings.travelTurnOffAutomatic = false
                }
                
            case .travelTurnOffAutomatic:
                Button("Override: Keep On", role: .destructive) {
                    settings.travelingModeManuallyToggled = true
                    withAnimation {
                        settings.travelingMode = true
                    }
                    settings.travelAutomatic = false
                    settings.travelTurnOnAutomatic = false
                    settings.travelTurnOffAutomatic = false
                    settings.fetchPrayerTimes(force: true)
                }
                
                Button("Confirm: Turn Off", role: .cancel) {
                    settings.travelTurnOnAutomatic = false
                    settings.travelTurnOffAutomatic = false
                }

            case .locationAlert:
                Button("Open Settings") {
                    #if !os(watchOS)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                    #endif
                }
                Button("Never Ask Again", role: .destructive) {
                    settings.locationNeverAskAgain = true
                }
                Button("Ignore", role: .cancel) { }

            case .notificationAlert:
                Button("Open Settings") {
                    #if !os(watchOS)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                    #endif
                }
                Button("Never Ask Again", role: .destructive) {
                    settings.notificationNeverAskAgain = true
                }
                Button("Ignore", role: .cancel) { }

            case .none:
                EmptyView()
            }
        } message: {
            switch showAlert {
            case .travelTurnOnAutomatic:
                Text("Waktu Solat has automatically detected that you are traveling, so your prayers will be shortened.")
            case .travelTurnOffAutomatic:
                Text("Waktu Solat has automatically detected that you are no longer traveling, so your prayers will not be shortened.")
            case .locationAlert:
                Text("Please go to Settings and enable location services to accurately determine prayer times.")
            case .notificationAlert:
                Text("Please go to Settings and enable notifications to be notified of prayer times.")
            case .none:
                EmptyView()
            }
        }
        .navigationViewStyle(.stack)
    }
}

private struct DateAndLocationSectionView: View {
    @EnvironmentObject var settings: Settings
    @Binding var showBigQibla: Bool

    var body: some View {
        Section(header: settings.defaultView ? Text("DATE AND LOCATION") : nil) {
            if let hijriDate = settings.hijriDate {
                hijriDateRow(hijriDate)
            }

            locationCard

            if settings.shouldPromptSetAutoForPrayerLocationMismatch {
                prayerLocationAutoPrompt
            }
        }
    }

    @ViewBuilder
    private func hijriDateRow(_ hijriDate: HijriDate) -> some View {
        #if !os(watchOS)
        NavigationLink(destination: HijriCalendarView()) {
            HStack {
                Text(hijriDate.english)
                    .multilineTextAlignment(.center)

                Spacer()

                Text(hijriDate.arabic)
            }
            .font(.footnote)
            .foregroundColor(settings.accentColor.color)
            .contextMenu {
                Button(action: {
                    settings.hapticFeedback()
                    UIPasteboard.general.string = hijriDate.english
                }) {
                    Text("Copy English Date")
                    Image(systemName: "doc.on.doc")
                }

                Button(action: {
                    settings.hapticFeedback()
                    UIPasteboard.general.string = hijriDate.arabic
                }) {
                    Text("Copy Arabic Date")
                    Image(systemName: "doc.on.doc")
                }
            }
        }
        #else
        HStack {
            Spacer()

            Text(hijriDate.english)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .font(.footnote)
        .foregroundColor(settings.accentColor.color)
        #endif
    }

    @ViewBuilder
    private var locationCard: some View {
        VStack {
            HStack {
                #if !os(watchOS)
                if let currentLoc = settings.currentLocation {
                    let currentDisplayLocation = settings.effectivePrayerLocationDisplayName ?? currentLoc.city
                    let shouldDisplayWaktuZoneTag = settings.shouldDisplayWaktuZoneTag
                    let currentWaktuZone = shouldDisplayWaktuZoneTag ? settings.currentWaktuZoneName : nil
                    let isResolvingWaktuZone = shouldDisplayWaktuZoneTag && settings.isResolvingAnyWaktuZone

                    Image(systemName: "location.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundColor(settings.accentColor.color)
                        .padding(.trailing, 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentDisplayLocation)
                            .font(.subheadline)
                            .lineLimit(nil)

                        if let currentWaktuZone {
                            Text("Waktu Zone: \(currentWaktuZone)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        if isResolvingWaktuZone {
                            Text("Resolving Waktu Zone...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .contextMenu {
                        Button(action: {
                            settings.hapticFeedback()
                            UIPasteboard.general.string = currentDisplayLocation
                        }) {
                            Text("Copy Address")
                            Image(systemName: "doc.on.doc")
                        }

                        if let currentWaktuZone {
                            Button(action: {
                                settings.hapticFeedback()
                                UIPasteboard.general.string = currentWaktuZone
                            }) {
                                Text("Copy Waktu Zone")
                                Image(systemName: "doc.on.doc")
                            }
                        }
                    }
                } else {
                    Image(systemName: "location.slash")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundColor(settings.accentColor.color)
                        .padding(.trailing, 8)

                    Text("No location")
                        .font(.subheadline)
                        .lineLimit(nil)
                }
                #else
                Group {
                    if settings.prayers != nil, let currentLoc = settings.currentLocation {
                        Text(currentLoc.city)
                    } else {
                        Text("No location")
                    }
                }
                .font(.subheadline)
                .lineLimit(2)
                #endif

                Spacer()

                QiblaView(size: showBigQibla ? 100 : 50)
                    .padding(.horizontal)
            }
            .foregroundColor(.primary)
            .font(.subheadline)
            .contentShape(Rectangle())

            #if os(watchOS)
            Text("Compass may not be accurate on Apple Watch")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            #endif
        }
        .animation(.easeInOut, value: showBigQibla)
        #if !os(watchOS)
        .onTapGesture {
            withAnimation {
                settings.hapticFeedback()
                showBigQibla.toggle()
            }
        }
        #endif
    }

    private var prayerLocationAutoPrompt: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(settings.prayerLocationMismatchMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)

            Spacer(minLength: 12)

            Button(settings.prayerLocationAutoPromptText) {
                settings.setPrayerLocationModeToAuto()
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    AdhanView()
        .environmentObject(Settings.shared)
}
