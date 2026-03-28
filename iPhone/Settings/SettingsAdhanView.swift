import SwiftUI
import UserNotifications
import WidgetKit
#if os(iOS)
import AVFoundation
import AudioToolbox
import UIKit
#endif

struct SettingsAdhanView: View {
    @EnvironmentObject var settings: Settings
    
    @State private var showingMap = false
    
    @State private var showAlert: AlertType?
    enum AlertType: Identifiable {
        case travelTurnOnAutomatic, travelTurnOffAutomatic

        var id: Int {
            switch self {
            case .travelTurnOnAutomatic: return 1
            case .travelTurnOffAutomatic: return 2
            }
        }
    }
    
    @State var showNotifications: Bool
    
    var body: some View {
        List {
            #if !os(watchOS)
            if showNotifications {
                Section(header: Text("NOTIFICATIONS")) {
                    NavigationLink(destination: NotificationView()) {
                        Label(appLocalized("Notification Settings"), systemImage: "bell.badge")
                    }
                    
                    #if os(iOS)
                    Toggle(appLocalized("Live Next Prayer Activity"), isOn: $settings.liveNextPrayerEnabled.animation(.easeInOut))
                        .font(.subheadline)
                        .tint(settings.accentColor.toggleTint)

                    if settings.liveNextPrayerEnabled {
                        HStack {
                            Text(appLocalized("Show Before Prayer"))
                                .font(.subheadline)
                            Spacer()
                            Text("\(max(0, settings.liveActivityLeadMinutes)) \(appLocalized("minutes"))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Text("Live Activity appears \(max(0, settings.liveActivityLeadMinutes)) minutes before prayer time. This timing is fixed for now.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 2)
                    } else {
                        Text("Shows a live countdown to the next prayer on the Lock Screen when that prayer notification is enabled.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 2)
                    }

                    /*
                    #if DEBUG
                    if #available(iOS 16.2, *) {
                        Button {
                            settings.hapticFeedback()
                            settings.startDebugLiveNextPrayerActivity(prayerName: "Test Prayer", minutesUntilPrayer: 2)
                        } label: {
                            Label("Start Test Live Activity (2 min)", systemImage: "timer")
                                .foregroundColor(settings.accentColor.color)
                        }
                        .font(.subheadline)
                    }
                    #endif
                    */
                    #endif
                }
            }
            #endif
            
            Section(header: Text("TRAVELING MODE")) {
                #if !os(watchOS)
                Button(action: {
                    settings.hapticFeedback()
                    
                    showingMap = true
                }) {
                    HStack {
                        Text("Set Home City")
                            .font(.subheadline)
                            .foregroundColor(settings.accentColor.color)
                        if !(settings.homeLocation?.city.isEmpty ?? true) {
                            Spacer()
                            Text(settings.homeLocation?.city ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .sheet(isPresented: $showingMap) {
                    MapView(choosingPrayerTimes: false)
                        .environmentObject(settings)
                }
                
                Toggle("Traveling Mode Turns on Automatically", isOn: $settings.travelAutomatic.animation(.easeInOut))
                    .font(.subheadline)
                    .tint(settings.accentColor.toggleTint)
                #endif
                
                VStack(alignment: .leading) {
                    #if !os(watchOS)
                    Toggle("Traveling Mode", isOn: Binding(
                        get: { settings.travelingMode },
                        set: { settings.travelingModeManuallyToggled = true; settings.travelingMode = $0 }
                    ).animation(.easeInOut))
                        .font(.subheadline)
                        .tint(settings.accentColor.toggleTint)
                        .disabled(settings.travelAutomatic)
                    
                    Text("If you are traveling more than 48 mi (77.25 km), then it is permissible to pray Qasr, where you combine Dhuhr and Asr (2 rakahs each) and Maghrib and Isha (3 and 2 rakahs). Allah said in the Quran, “And when you (Muslims) travel in the land, there is no sin on you if you shorten As-Salah (the prayer)” [Quran, An-Nisa, 4:101]. \(settings.travelAutomatic ? "This feature turns on and off automatically, but you can also control it manually here." : "You can control traveling mode manually here.")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 2)
                    #else
                    Toggle("Traveling Mode", isOn: Binding(
                        get: { settings.travelingMode },
                        set: { settings.travelingModeManuallyToggled = true; settings.travelingMode = $0 }
                    ).animation(.easeInOut))
                        .font(.subheadline)
                        .tint(settings.accentColor.toggleTint)
                    #endif
                }
            }
            
        }
        .applyConditionalListStyle(defaultView: true)
        .navigationTitle(appLocalized("Waktu Solat Settings"))
        .onAppear {
            applyRegionDefaultCalculation()
        }
        .onChange(of: settings.currentLocation?.countryCode) { _ in
            applyRegionDefaultCalculation()
        }
        .onChange(of: settings.homeLocation) { _ in
            settings.fetchPrayerTimes() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if settings.travelTurnOnAutomatic {
                        showAlert = .travelTurnOnAutomatic
                    } else if settings.travelTurnOffAutomatic {
                        showAlert = .travelTurnOffAutomatic
                    }
                }
            }
        }
        .onChange(of: settings.travelAutomatic) { newValue in
            if newValue {
                settings.fetchPrayerTimes() {
                    if settings.homeLocation == nil {
                        withAnimation {
                            settings.travelingMode = false
                        }
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if settings.travelTurnOnAutomatic {
                                showAlert = .travelTurnOnAutomatic
                            } else if settings.travelTurnOffAutomatic {
                                showAlert = .travelTurnOffAutomatic
                            }
                        }
                    }
                }
            }
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
                
            case .none:
                EmptyView()
            }
        } message: {
            switch showAlert {
            case .travelTurnOnAutomatic:
                Text("Waktu Solat has automatically detected that you are traveling, so your prayers will be shortened.")
            case .travelTurnOffAutomatic:
                Text("Waktu Solat has automatically detected that you are no longer traveling, so your prayers will not be shortened.")
            case .none:
                EmptyView()
            }
        }
    }

    private func applyRegionDefaultCalculation() {
        let countryCode = settings.currentLocation?.countryCode?.uppercased() ?? ""

        guard !countryCode.isEmpty else {
            if settings.shouldUseMalaysiaPrayerAPI(for: settings.currentLocation) {
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
        case "ID":
            settings.prayerCalculation = "KEMENAG - Kementerian Agama Republik Indonesia"
            settings.hanafiMadhab = false
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
}

struct LiveActivitySettingsView: View {
    @EnvironmentObject var settings: Settings

    #if DEBUG
    private enum DebugTimingMode: String, CaseIterable, Identifiable {
        case relative
        case absolute
        var id: String { rawValue }
        var title: String {
            switch self {
            case .relative: return "Minutes from now"
            case .absolute: return "Exact time"
            }
        }
    }
    #endif

    #if DEBUG
    @State private var debugTimingMode: DebugTimingMode = .relative
    @State private var debugMinutesUntilPrayer: Int = 2
    @State private var debugExactPrayerTime: Date = Date().addingTimeInterval(2 * 60)
    @State private var debugSelectedPrayerName: String = "Test Prayer"
    @State private var debugLastStartedTargetTime: Date?
    private let debugPrayerNames: [String] = [
        "Test Prayer", "Fajr", "Shurooq", "Dhuhr", "Jumuah", "Asr", "Maghrib", "Isha"
    ]
    #endif

    var body: some View {
        List {
            Section(header: Text("LIVE ACTIVITY TIMING")) {
                HStack {
                    Text("Show Before Prayer")
                        .font(.subheadline)
                    Spacer()
                    Text("5 minutes")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text("Live Activity appears 5 minutes before prayer time.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 2)
            }

            Section(header: Text("LIVE ACTIVITY PRAYERS")) {
                Toggle("Fajr", isOn: $settings.liveActivityFajrEnabled.animation(.easeInOut))
                    .tint(settings.accentColor.toggleTint)
                Toggle("Shurooq", isOn: $settings.liveActivitySunriseEnabled.animation(.easeInOut))
                    .tint(settings.accentColor.toggleTint)
                Toggle("Dhuhr (Jumuah)", isOn: $settings.liveActivityDhuhrEnabled.animation(.easeInOut))
                    .tint(settings.accentColor.toggleTint)
                Toggle("Asr", isOn: $settings.liveActivityAsrEnabled.animation(.easeInOut))
                    .tint(settings.accentColor.toggleTint)
                Toggle("Maghrib", isOn: $settings.liveActivityMaghribEnabled.animation(.easeInOut))
                    .tint(settings.accentColor.toggleTint)
                Toggle("Isha", isOn: $settings.liveActivityIshaEnabled.animation(.easeInOut))
                    .tint(settings.accentColor.toggleTint)
            }

            #if false
            Section(header: Text("TRAVEL COMBINED PRAYERS")) {
                Toggle("Combined Traveling Dhuhr and Asr", isOn: $settings.liveActivityDhuhrAsrEnabled.animation(.easeInOut))
                    .tint(settings.accentColor.toggleTint)
                Toggle("Combined Traveling Maghrib and Isha", isOn: $settings.liveActivityMaghribIshaEnabled.animation(.easeInOut))
                    .tint(settings.accentColor.toggleTint)
                Text("Used when Traveling Mode combines prayers.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 2)
            }
            #endif

            /*
            #if DEBUG
            if #available(iOS 16.2, *) {
                Section(header: Text("DEBUG LIVE ACTIVITY")) {
                    Picker("Prayer Label", selection: $debugSelectedPrayerName) {
                        ForEach(debugPrayerNames, id: \.self) { prayer in
                            Text(prayer).tag(prayer)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Debug Timing Mode", selection: $debugTimingMode) {
                        ForEach(DebugTimingMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if debugTimingMode == .relative {
                        Stepper(
                            "Minutes Until Prayer: \(debugMinutesUntilPrayer)",
                            value: $debugMinutesUntilPrayer,
                            in: 1...180
                        )
                    } else {
                        DatePicker(
                            "Prayer Time",
                            selection: $debugExactPrayerTime,
                            in: Date().addingTimeInterval(60)...Date().addingTimeInterval(24 * 60 * 60),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }

                    Text("Starts a debug Live Activity immediately with your custom countdown so you can test without waiting for the real next prayer.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 2)

                    if let target = debugLastStartedTargetTime {
                        TimelineView(.periodic(from: Date(), by: 1)) { context in
                            let now = context.date
                            let remaining = max(0, Int(target.timeIntervalSince(now)))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Now: \(now.formatted(date: .omitted, time: .standard))")
                                Text("Target: \(target.formatted(date: .abbreviated, time: .standard))")
                                Text("Remaining: \(remaining)s")
                            }
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }

                    Button {
                        settings.hapticFeedback()
                        if debugTimingMode == .relative {
                            let target = Calendar.current.date(byAdding: .minute, value: debugMinutesUntilPrayer, to: Date()) ?? Date().addingTimeInterval(Double(debugMinutesUntilPrayer) * 60)
                            debugLastStartedTargetTime = target
                            settings.startDebugLiveNextPrayerActivity(
                                prayerName: debugSelectedPrayerName,
                                minutesUntilPrayer: debugMinutesUntilPrayer
                            )
                        } else {
                            debugLastStartedTargetTime = debugExactPrayerTime
                            settings.startDebugLiveNextPrayerActivity(
                                prayerName: debugSelectedPrayerName,
                                minutesUntilPrayer: 1,
                                debugPrayerTime: debugExactPrayerTime
                            )
                        }
                    } label: {
                        Label("Start Custom Debug Live Activity", systemImage: "play.circle")
                            .foregroundColor(settings.accentColor.color)
                    }
                    .font(.subheadline)

                    Button(role: .destructive) {
                        settings.hapticFeedback()
                        settings.stopDebugLiveNextPrayerActivity()
                        debugLastStartedTargetTime = nil
                    } label: {
                        Label("Stop Debug Live Activity", systemImage: "stop.circle")
                    }
                    .font(.subheadline)
                }
            }
            #endif
            */
        }
        .applyConditionalListStyle(defaultView: true)
        .navigationTitle("Live Activity Options")
    }
}

struct NotificationView: View {
    @EnvironmentObject var settings: Settings
    
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var showAlert: Bool = false
    @State private var notifSettings: UNNotificationSettings?
    @State private var requestAccessAlertMessage: String?
    #if os(iOS)
    @State private var previewPlayer: AVAudioPlayer?
    #endif
    
    var body: some View {
        List {
            #if !os(watchOS)
            Section {
                permissionCard
            }
            #endif
            
            Section(header: Text(appLocalized("PRAYER REMINDERS"))) {
                NavigationLink(destination: MoreNotificationView()) {
                    Label(appLocalized("Prayer Notifications"), systemImage: "bell.fill")
                        .font(.subheadline)
                }
            }

            Section(header: Text(appLocalized("PRAYER MESSAGE STYLE"))) {
                NotificationStylePreviewCard(
                    appName: "Waktu Solat",
                    title: prayerPreviewTitle,
                    messageBody: prayerPreviewBody,
                    accentColor: settings.accentColor.color
                )
                .listRowSeparator(.hidden)

                Picker(appLocalized("Prayer Notification Style"), selection: Binding(
                    get: { settings.prayerNotificationMessageStyle },
                    set: { settings.prayerNotificationMessageStyle = $0 }
                )) {
                    ForEach(PrayerNotificationMessageStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.menu)

                Text(settings.prayerNotificationMessageStyle.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text(appLocalized("DAILY ZIKIR REMINDERS"))) {
                Toggle(appLocalized("Send Daily Zikir Notifications"), isOn: $settings.zikirNotificationsEnabled.animation(.easeInOut))
                    .font(.subheadline)
                    .tint(settings.accentColor.toggleTint)

                if settings.zikirNotificationsEnabled {
                    NotificationStylePreviewCard(
                        appName: "Waktu Solat",
                        title: zikirPreviewTitle,
                        messageBody: zikirPreviewBody,
                        accentColor: settings.accentColor.color
                    )
                    .listRowSeparator(.hidden)

                    Picker(appLocalized("Zikir Notification Style"), selection: Binding(
                        get: { settings.zikirNotificationMessageStyle },
                        set: { settings.zikirNotificationMessageStyle = $0 }
                    )) {
                        ForEach(ZikirNotificationMessageStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(appLocalized("Zikir notifications rotate through morning, midday, evening, and night using the same prayer-aware timing as the zikir widget."))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(settings.zikirNotificationMessageStyle.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(appLocalized("Send a short Arabic zikir throughout the day, timed around your prayer windows."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text(appLocalized("NOTIFICATION SOUND"))) {
                Picker(
                    selection: Binding(
                        get: { settings.notificationSoundOption },
                        set: {
                            settings.setNotificationSoundOption($0)
                            playPreviewIfNeeded(for: $0)
                        }
                    )
                ) {
                    ForEach(NotificationSoundOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                } label: {
                    Label(appLocalized("Notification Sound"), systemImage: "speaker.wave.2.fill")
                        .font(.subheadline)
                }
                .pickerStyle(.menu)
            }
        }
        .task { await refresh() }
        .onAppear { syncNotificationState() }
        .onChange(of: scenePhase) { _ in
            if scenePhase == .active {
                syncNotificationState()
            }
        }
        .confirmationDialog("", isPresented: $showAlert, titleVisibility: .visible) {
            Button("Open Settings") { openSystemSettings() }
            Button("Ignore", role: .cancel) { }
        } message: {
            Text("Please go to Settings and enable notifications to be notified of prayer times.")
        }
        .confirmationDialog("Notifications", isPresented: Binding(
            get: { requestAccessAlertMessage != nil },
            set: { if !$0 { requestAccessAlertMessage = nil } }
        ), titleVisibility: .visible) {
            Button("OK", role: .cancel) { requestAccessAlertMessage = nil }
            Button("Open Settings") {
                requestAccessAlertMessage = nil
                openSystemSettings()
            }
        } message: {
            if let msg = requestAccessAlertMessage {
                Text(msg)
            }
        }
        .applyConditionalListStyle(defaultView: true)
        .navigationTitle(appLocalized("Notification Settings"))
    }

    private var prayerPreviewTitle: String {
        switch settings.prayerNotificationMessageStyle {
        case .standard:
            return "Waktu Solat"
        case .gentle:
            return isMalayAppLanguage() ? "Peringatan Solat" : "Prayer Reminder"
        case .concise:
            return localizedPrayerName("Asr")
        }
    }

    private var prayerPreviewBody: String {
        switch settings.prayerNotificationMessageStyle {
        case .standard:
            return isMalayAppLanguage()
                ? "Waktu Asar pada 4:25 PTG di Taiping, Perak"
                : "Time for Asr at 4:25 PM in Taiping, Perak"
        case .gentle:
            return isMalayAppLanguage()
                ? "Kini masuk waktu Asar di Taiping, Perak."
                : "It's now time for Asr in Taiping, Perak."
        case .concise:
            return isMalayAppLanguage()
                ? "Asar • 4:25 PTG • Taiping, Perak"
                : "Asr • 4:25 PM • Taiping, Perak"
        }
    }

    private var zikirPreviewTitle: String {
        switch settings.zikirNotificationMessageStyle {
        case .guided:
            return isMalayAppLanguage() ? "Zikir petang" : "Evening Zikir"
        case .reflective:
            return isMalayAppLanguage() ? "Makna zikir" : "Zikir Reflection"
        case .concise:
            return "سُبْحَانَ اللَّهِ"
        }
    }

    private var zikirPreviewBody: String {
        switch settings.zikirNotificationMessageStyle {
        case .guided:
            return isMalayAppLanguage()
                ? "Ulang dengan hadir hati\nسُبْحَانَ اللَّهِ وَبِحَمْدِهِ"
                : "Repeat with presence\nسُبْحَانَ اللَّهِ وَبِحَمْدِهِ"
        case .reflective:
            return isMalayAppLanguage()
                ? "Maha Suci Allah dan segala puji bagi-Nya.\nسُبْحَانَ اللَّهِ وَبِحَمْدِهِ"
                : "Glory be to Allah and praise be to Him.\nسُبْحَانَ اللَّهِ وَبِحَمْدِهِ"
        case .concise:
            return isMalayAppLanguage()
                ? "Maha Suci Allah • Taiping, Perak"
                : "Glory be to Allah • Taiping, Perak"
        }
    }

    private func playPreviewIfNeeded(for option: NotificationSoundOption) {
        #if os(iOS)
        switch option {
        case .azan:
            guard let url = Bundle.main.url(forResource: "azan_waktu", withExtension: "mp3") else {
                previewPlayer?.stop()
                previewPlayer = nil
                return
            }
            do {
                previewPlayer = try AVAudioPlayer(contentsOf: url)
                previewPlayer?.prepareToPlay()
                previewPlayer?.play()
            } catch {
                previewPlayer = nil
            }
        case .iosDefault:
            previewPlayer?.stop()
            previewPlayer = nil
            AudioServicesPlaySystemSound(1007)
        }
        #endif
    }
    
    #if !os(watchOS)
    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Prayer Reminders", systemImage: "bell.badge")
                    .font(.headline)
                    .foregroundColor(settings.accentColor.color)

                Spacer()

                Text(permissionPillText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(permissionPillTextColor)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Capsule().fill(permissionPillColor))
                    .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                    .padding(.trailing, -6)
            }
            .animation(.easeInOut(duration: 0.25), value: permissionPillText)

            if let s = notifSettings {
                VStack(spacing: 8) {
                    infoRow("Status", statusText(s.authorizationStatus))
                    infoRow("Alerts", notificationSettingText(s.alertSetting))
                    infoRow("Sounds", notificationSettingText(s.soundSetting))
                }
                .font(.footnote)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            Text("Turn on notifications to get prayer reminders and live countdown support. Waktu Solat will only show Apple's system prompt after you tap the button below.")
                .font(.footnote)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Button {
                    settings.hapticFeedback()
                    Task { @MainActor in await onRequestAccessTapped() }
                } label: {
                    smallButton("Enable Reminders", systemImage: "checkmark.seal")
                }
                .buttonStyle(.plain)

                Button {
                    settings.hapticFeedback()
                    openSystemSettings()
                } label: {
                    smallButton("Open Settings", systemImage: "gear")
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.25), value: notifSettings?.authorizationStatus.rawValue)
    }
    #endif
    
    private var permissionPillText: String {
        statusText(notifSettings?.authorizationStatus ?? .notDetermined)
    }
    
    private var permissionPillColor: Color {
        guard let status = notifSettings?.authorizationStatus else { return .secondary }
        switch status {
        case .authorized, .provisional, .ephemeral:
            return settings.accentColor.toggleTint
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .secondary
        }
    }

    private var permissionPillTextColor: Color {
        switch settings.accentColor {
        case .adaptive, .yellow, .mint, .lightPink:
            return .black
        default:
            return .white
        }
    }
    
    private func infoRow(_ left: String, _ right: String) -> some View {
        HStack {
            Text(left).foregroundColor(.secondary)
            Spacer()
            Text(right).foregroundColor(.primary)
        }
    }
    
    private func statusText(_ s: UNAuthorizationStatus) -> String {
        switch s {
        case .notDetermined: return "Not asked"
        case .denied: return "Denied"
        case .authorized: return "Allowed"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }
    
    private func notificationSettingText(_ s: UNNotificationSetting) -> String {
        switch s {
        case .enabled: return "On"
        case .disabled: return "Off"
        case .notSupported: return "N/A"
        @unknown default: return "Unknown"
        }
    }
    
    private func smallButton(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            
            Text(title)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(settings.accentColor.color.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(settings.accentColor.color.opacity(0.35), lineWidth: 1)
        )
    }
    
    private func openSystemSettings() {
        #if !os(watchOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        #endif
    }
    
    @MainActor
    private func refresh() async {
        let center = UNUserNotificationCenter.current()
        notifSettings = await center.notificationSettings()
    }
    
    private func syncNotificationState() {
        Task { @MainActor in
            await refresh()
            settings.fetchPrayerTimes(notification: true) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if settings.showNotificationAlert,
                       notifSettings?.authorizationStatus == .denied {
                        showAlert = true
                    }
                }
            }
        }
    }
    
    @MainActor
    private func onRequestAccessTapped() async {
        let center = UNUserNotificationCenter.current()
        let current = await center.notificationSettings()
        switch current.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            requestAccessAlertMessage = "Notifications are already turned on."
        case .denied:
            requestAccessAlertMessage = "Notifications are turned off. Open Settings to enable them."
        case .notDetermined:
            let granted = await settings.requestNotificationAuthorization()
            await refresh()
            if granted {
                settings.fetchPrayerTimes(notification: true)
            }
        @unknown default:
            requestAccessAlertMessage = "Unable to change notification settings."
        }
    }
}

private struct NotificationStylePreviewCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let appName: String
    let title: String
    let messageBody: String
    let accentColor: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("CurrentAppIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(appIconBorderColor, lineWidth: 0.8)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(appName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(headerPrimaryTextColor)

                    Spacer(minLength: 8)

                    Text(isMalayAppLanguage() ? "12m lalu" : "12m ago")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(headerSecondaryTextColor)
                        .fixedSize(horizontal: true, vertical: false)
                }

                if showsStandaloneTitle {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                        .lineLimit(1)
                }

                Text(messageBody)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(primaryTextColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 364)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 10, x: 0, y: 4)
        .listRowInsets(EdgeInsets())
        .padding(.vertical, 2)
    }

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.9)
            : Color(UIColor.secondarySystemBackground)
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.18)
            : Color.black.opacity(0.08)
    }

    private var appIconBorderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.14)
            : Color.black.opacity(0.10)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.96)
            : Color.primary
    }

    private var headerPrimaryTextColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.96)
            : Color.black.opacity(0.9)
    }

    private var headerSecondaryTextColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.62)
            : Color.black.opacity(0.5)
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? .black.opacity(0.2)
            : .black.opacity(0.08)
    }

    private var showsStandaloneTitle: Bool {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAppName = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !normalizedTitle.isEmpty && normalizedTitle.caseInsensitiveCompare(normalizedAppName) != .orderedSame
    }
}

struct WidgetPreviewGalleryView: View {
    private struct SelectionSnapshot {
        let prayerTimesStyleRaw: String
        let countdownBarStyleRaw: String
        let zikirAlignmentRaw: String
        let nextPrayerCircleStyleRaw: String
        let prayerListStyleRaw: String
        let dailyVerseStyleRaw: String
    }

    @EnvironmentObject var settings: Settings
    @EnvironmentObject var revenueCat: RevenueCatManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(LockScreenPrayerTimesStyle.storageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var prayerTimesStyleRaw = LockScreenPrayerTimesStyle.prayerTimelineWithLocation.rawValue
    @AppStorage(LockScreenPrayerCountdownBarStyle.storageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var countdownBarStyleRaw = LockScreenPrayerCountdownBarStyle.withLocation.rawValue
    @AppStorage(WidgetZikirAlignment.storageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var zikirAlignmentRaw = WidgetZikirAlignment.center.rawValue
    @AppStorage(NextPrayerCircleStyle.storageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var nextPrayerCircleStyleRaw = NextPrayerCircleStyle.classic.rawValue
    @AppStorage(PrayerListWidgetStyle.storageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var prayerListStyleRaw = PrayerListWidgetStyle.classic.rawValue
    @AppStorage(DailyVerseWidgetStyle.storageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var dailyVerseStyleRaw = DailyVerseWidgetStyle.classic.rawValue
    #if DEBUG
    @AppStorage(premiumWidgetsDebugOverrideStorageKey, store: UserDefaults(suiteName: sharedAppGroupID))
    private var premiumWidgetsDebugOverrideRaw = 0
    #endif
    @State private var pendingLockedSelectionSnapshot: SelectionSnapshot?

    private var selectedPrayerTimesStyle: LockScreenPrayerTimesStyle {
        LockScreenPrayerTimesStyle(rawValue: prayerTimesStyleRaw) ?? .prayerCountdownWithLocation
    }

    private var prayerTimesStyle: LockScreenPrayerTimesStyle {
        (LockScreenPrayerTimesStyle(rawValue: prayerTimesStyleRaw) ?? .prayerCountdownWithLocation).resolvedForWidgetAccess
    }

    private var selectedCountdownBarStyle: LockScreenPrayerCountdownBarStyle {
        LockScreenPrayerCountdownBarStyle(rawValue: countdownBarStyleRaw) ?? .withLocation
    }

    private var countdownBarStyle: LockScreenPrayerCountdownBarStyle {
        (LockScreenPrayerCountdownBarStyle(rawValue: countdownBarStyleRaw) ?? .withLocation).resolvedForWidgetAccess
    }

    private var selectedZikirAlignment: WidgetZikirAlignment {
        WidgetZikirAlignment(rawValue: zikirAlignmentRaw) ?? .center
    }

    private var zikirAlignment: WidgetZikirAlignment {
        (WidgetZikirAlignment(rawValue: zikirAlignmentRaw) ?? .center).resolvedForWidgetAccess
    }

    private var selectedNextPrayerCircleStyle: NextPrayerCircleStyle {
        NextPrayerCircleStyle(rawValue: nextPrayerCircleStyleRaw) ?? .classic
    }

    private var nextPrayerCircleStyle: NextPrayerCircleStyle {
        (NextPrayerCircleStyle(rawValue: nextPrayerCircleStyleRaw) ?? .classic).resolvedForWidgetAccess
    }

    private var selectedPrayerListStyle: PrayerListWidgetStyle {
        PrayerListWidgetStyle(rawValue: prayerListStyleRaw) ?? .classic
    }

    private var prayerListStyle: PrayerListWidgetStyle {
        (PrayerListWidgetStyle(rawValue: prayerListStyleRaw) ?? .classic).resolvedForWidgetAccess
    }

    private var selectedDailyVerseStyle: DailyVerseWidgetStyle {
        DailyVerseWidgetStyle(rawValue: dailyVerseStyleRaw) ?? .classic
    }

    private var dailyVerseStyle: DailyVerseWidgetStyle {
        (DailyVerseWidgetStyle(rawValue: dailyVerseStyleRaw) ?? .classic).resolvedForWidgetAccess
    }

    private var sortedNextPrayerCircleStyles: [NextPrayerCircleStyle] {
        orderedStyles(NextPrayerCircleStyle.allCases) { $0.requiresPremiumWidgets }
    }

    private var sortedPrayerTimesStyles: [LockScreenPrayerTimesStyle] {
        orderedStyles(LockScreenPrayerTimesStyle.allCases) { $0.requiresPremiumWidgets }
    }

    private var sortedPrayerListStyles: [PrayerListWidgetStyle] {
        orderedStyles(PrayerListWidgetStyle.allCases) { $0.requiresPremiumWidgets }
    }

    private var sortedCountdownBarStyles: [LockScreenPrayerCountdownBarStyle] {
        orderedStyles(LockScreenPrayerCountdownBarStyle.allCases) { $0.requiresPremiumWidgets }
    }

    private var sortedZikirAlignments: [WidgetZikirAlignment] {
        orderedStyles(WidgetZikirAlignment.allCases) { $0.requiresPremiumWidgets }
    }

    private var sortedDailyVerseStyles: [DailyVerseWidgetStyle] {
        orderedStyles(DailyVerseWidgetStyle.allCases) { $0.requiresPremiumWidgets }
    }

    private func orderedStyles<Style>(_ styles: [Style], requiresPremium: (Style) -> Bool) -> [Style] {
        styles.filter { !requiresPremium($0) } + styles.filter(requiresPremium)
    }

    private var hasPremiumWidgetAccess: Bool {
        #if DEBUG
        _ = premiumWidgetsDebugOverrideRaw
        return premiumWidgetsUnlocked()
        #else
        revenueCat.hasPremiumWidgetsUnlocked
        #endif
    }

    private var unlockCTAForegroundColor: Color {
        if settings.accentColor == .adaptive {
            return colorScheme == .dark ? .black : .white
        }

        #if os(iOS)
        let resolved = UIColor(settings.accentColor.color).resolvedColor(with: UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return .white
        }

        let luminance = (0.299 * red) + (0.587 * green) + (0.114 * blue)
        return luminance > 0.67 ? .black : .white
        #else
        return .white
        #endif
    }

    private func captureSelectionSnapshot() -> SelectionSnapshot {
        SelectionSnapshot(
            prayerTimesStyleRaw: prayerTimesStyleRaw,
            countdownBarStyleRaw: countdownBarStyleRaw,
            zikirAlignmentRaw: zikirAlignmentRaw,
            nextPrayerCircleStyleRaw: nextPrayerCircleStyleRaw,
            prayerListStyleRaw: prayerListStyleRaw,
            dailyVerseStyleRaw: dailyVerseStyleRaw
        )
    }

    private func restoreSelectionSnapshot(_ snapshot: SelectionSnapshot) {
        prayerTimesStyleRaw = snapshot.prayerTimesStyleRaw
        countdownBarStyleRaw = snapshot.countdownBarStyleRaw
        zikirAlignmentRaw = snapshot.zikirAlignmentRaw
        nextPrayerCircleStyleRaw = snapshot.nextPrayerCircleStyleRaw
        prayerListStyleRaw = snapshot.prayerListStyleRaw
        dailyVerseStyleRaw = snapshot.dailyVerseStyleRaw
    }

    private func handleWidgetStyleSelection(requiresPremiumWidgets: Bool, action: () -> Void) {
        settings.hapticFeedback()

        if requiresPremiumWidgets && !hasPremiumWidgetAccess {
            pendingLockedSelectionSnapshot = captureSelectionSnapshot()
        } else {
            pendingLockedSelectionSnapshot = nil
        }

        withAnimation(.easeInOut) {
            action()
        }

        guard hasPremiumWidgetAccess || !requiresPremiumWidgets else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(name: .openSupportDonationPaywall, object: nil)
            }
            return
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !hasPremiumWidgetAccess {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Support Waktu 🤍")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("Unlock premium widgets & keep the app ad-free")
                            .font(.caption)
                            .foregroundStyle(settings.accentColor.color)

                        Text("No ads, ever. Your support keeps Waktu running 🤍")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)

                        Button {
                            settings.hapticFeedback()
                            NotificationCenter.default.post(name: .openSupportDonationPaywall, object: nil)
                        } label: {
                            Text("Support Once • Unlock All Styles")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(unlockCTAForegroundColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(settings.accentColor.color)
                        .padding(.top, 8)
                    }
                }

                previewSection(
                    title: isMalayAppLanguage() ? "Bulatan Solat Seterusnya" : "Next Prayer Circle",
                    subtitle: isMalayAppLanguage()
                        ? "Pilih gaya untuk widget bulatan solat seterusnya."
                        : "Choose the style for the circular next prayer widget."
                ) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(sortedNextPrayerCircleStyles) { style in
                                Button {
                                    handleWidgetStyleSelection(requiresPremiumWidgets: style.requiresPremiumWidgets) {
                                        nextPrayerCircleStyleRaw = style.rawValue
                                    }
                                } label: {
                                    NextPrayerCircleStyleCard(
                                        style: style,
                                        isSelected: selectedNextPrayerCircleStyle == style,
                                        isLocked: style.requiresPremiumWidgets && !hasPremiumWidgetAccess
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                previewSection(
                    title: isMalayAppLanguage() ? "Waktu Solat" : "Prayer Times",
                    subtitle: isMalayAppLanguage()
                        ? "Pilih gaya titik atau graf untuk widget waktu solat pada skrin kunci."
                        : "Choose the dotted or graph styles for the Lock Screen prayer times widget."
                ) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(sortedPrayerTimesStyles) { style in
                                Button {
                                    handleWidgetStyleSelection(requiresPremiumWidgets: style.requiresPremiumWidgets) {
                                        prayerTimesStyleRaw = style.rawValue
                                    }
                                } label: {
                                    PrayerTimesStyleCard(
                                        style: style,
                                        isSelected: selectedPrayerTimesStyle == style,
                                        isLocked: style.requiresPremiumWidgets && !hasPremiumWidgetAccess
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                previewSection(
                    title: isMalayAppLanguage() ? "Senarai Solat" : "Prayer List",
                    subtitle: isMalayAppLanguage()
                        ? "Pilih gaya untuk widget senarai solat pada skrin kunci."
                        : "Choose the style for the Lock Screen prayer list widget."
                ) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(sortedPrayerListStyles) { style in
                                Button {
                                    handleWidgetStyleSelection(requiresPremiumWidgets: style.requiresPremiumWidgets) {
                                        prayerListStyleRaw = style.rawValue
                                    }
                                } label: {
                                    PrayerListStyleCard(
                                        style: style,
                                        isSelected: selectedPrayerListStyle == style,
                                        isLocked: style.requiresPremiumWidgets && !hasPremiumWidgetAccess
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                previewSection(
                    title: isMalayAppLanguage() ? "Kiraan Detik Solat" : "Prayer Countdown Bar",
                    subtitle: isMalayAppLanguage()
                        ? "Pilih paparan bar kiraan detik untuk widget kiraan detik solat."
                        : "Choose the progress-bar presentation for the Lock Screen prayer countdown widget."
                ) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(sortedCountdownBarStyles) { style in
                                Button {
                                    handleWidgetStyleSelection(requiresPremiumWidgets: style.requiresPremiumWidgets) {
                                        countdownBarStyleRaw = style.rawValue
                                    }
                                } label: {
                                    PrayerCountdownBarStyleCard(
                                        style: style,
                                        isSelected: selectedCountdownBarStyle == style,
                                        isLocked: style.requiresPremiumWidgets && !hasPremiumWidgetAccess
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                previewSection(
                    title: isMalayAppLanguage() ? "Zikir & Selawat" : "Zikir & Selawat",
                    subtitle: isMalayAppLanguage()
                        ? "Pilih gaya susunan untuk widget zikir pada skrin kunci."
                        : "Choose the layout style for the Lock Screen zikir widget."
                ) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(sortedZikirAlignments) { alignment in
                                Button {
                                    handleWidgetStyleSelection(requiresPremiumWidgets: alignment.requiresPremiumWidgets) {
                                        zikirAlignmentRaw = alignment.rawValue
                                    }
                                } label: {
                                    ZikirStyleCard(
                                        alignment: alignment,
                                        isSelected: selectedZikirAlignment == alignment,
                                        isLocked: alignment.requiresPremiumWidgets && !hasPremiumWidgetAccess
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                previewSection(
                    title: isMalayAppLanguage() ? "Inspirasi Al-Quran Harian" : "Daily Quran Inspiration",
                    subtitle: isMalayAppLanguage()
                        ? "Pilih gaya untuk widget inspirasi Al-Quran harian pada skrin kunci."
                        : "Choose the style for the Lock Screen daily Quran widget."
                ) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(sortedDailyVerseStyles) { style in
                                Button {
                                    handleWidgetStyleSelection(requiresPremiumWidgets: style.requiresPremiumWidgets) {
                                        dailyVerseStyleRaw = style.rawValue
                                    }
                                } label: {
                                    DailyVerseStyleCard(
                                        style: style,
                                        isSelected: selectedDailyVerseStyle == style,
                                        isLocked: style.requiresPremiumWidgets && !hasPremiumWidgetAccess
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Text(isMalayAppLanguage()
                     ? "Pilihan ini menandakan gaya pilihan anda di dalam aplikasi. iOS masih memerlukan pengguna menambah widget sebenar pada skrin kunci secara manual."
                     : "This marks your preferred style inside the app. iOS still requires users to add the actual widget to the Lock Screen manually.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .onReceive(NotificationCenter.default.publisher(for: .supportDonationPaywallDismissed)) { _ in
            guard !hasPremiumWidgetAccess, let snapshot = pendingLockedSelectionSnapshot else { return }
            withAnimation(.easeInOut) {
                restoreSelectionSnapshot(snapshot)
            }
            pendingLockedSelectionSnapshot = nil
        }
        .onChange(of: revenueCat.hasPremiumWidgetsUnlocked) { unlocked in
            if unlocked {
                pendingLockedSelectionSnapshot = nil
            }
        }
        .navigationTitle(appLocalized("Widgets"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func previewSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)

            content()
        }
    }
}

private struct PremiumWidgetBadge: View {
    var body: some View {
        EmptyView()
    }
}

private struct TopRoundedBannerShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(self.radius, rect.width / 2, rect.height)
        var path = Path()

        path.move(to: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: radius, y: rect.minY),
            control: CGPoint(x: 0, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct PremiumCardStatusText: View {
    let isSelected: Bool
    let isLocked: Bool
    let summary: String
    let selectedTint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(isSelected ? (isMalayAppLanguage() ? "Dipilih" : "Selected") : summary)
                .font(.subheadline)
                .foregroundStyle(isSelected ? selectedTint : .secondary)
                .lineLimit(2)

            if isLocked && !isSelected {
                Text("Premium")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LockedWidgetCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let isLocked: Bool
    let isSelected: Bool
    let cornerRadius: CGFloat
    let accentColor: Color

    private var bannerTextColor: Color {
        #if os(iOS)
        let resolved = UIColor(accentColor).resolvedColor(with: UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            let luminance = (0.299 * red) + (0.587 * green) + (0.114 * blue)
            return luminance > 0.67 ? .black : .white
        }
        #endif
        return colorScheme == .dark ? .white : .black
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if isLocked && !isSelected {
                    GeometryReader { proxy in
                        let bannerHeight = max(34, proxy.size.height / 6)
                        let bannerRadius = cornerRadius

                        ZStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(Color.black.opacity(colorScheme == .dark ? 0.12 : 0.08))

                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)

                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Locked")
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(bannerTextColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: bannerHeight)
                            .background(
                                accentColor,
                                in: TopRoundedBannerShape(radius: bannerRadius)
                            )
                            .overlay {
                                TopRoundedBannerShape(radius: bannerRadius)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
                            }
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(Color.primary.opacity(0.10))
                                    .frame(height: 0.8)
                            }
                        }
                    }
                }
            }
    }
}

private extension View {
    func lockedWidgetCardStyle(isLocked: Bool, isSelected: Bool, accentColor: Color, cornerRadius: CGFloat = 28) -> some View {
        modifier(LockedWidgetCardModifier(isLocked: isLocked, isSelected: isSelected, cornerRadius: cornerRadius, accentColor: accentColor))
    }
}

private struct NextPrayerCircleStyleCard: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    let style: NextPrayerCircleStyle
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black : Color(.systemBackground))

                LinearGradient(
                    colors: [
                        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03),
                        settings.accentColor.color.opacity(colorScheme == .dark ? 0.12 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))

                VStack(spacing: 0) {
                    HStack {
                        Text("Thu 26")
                        Spacer()
                        Text("8:14")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary.opacity(0.82))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    Spacer()

                    Group {
                        if style == .classic {
                            LockScreenCircularPreviewCard(title: localizedPrayerName("Isha"), time: "19:31")
                        } else if style == .minimal {
                            LockScreenCircularMinimalPreviewCard(title: localizedPrayerName("Isha"), time: "19:31")
                        } else if style == .percentageRing {
                            LockScreenCircularPercentagePreviewCard(percentage: 60, iconName: "moon.stars.fill")
                        } else if style == .countdownRing {
                            LockScreenCircularCountdownPreviewCard(title: localizedPrayerName("Maghrib"), progress: 0.34)
                        } else if style == .dualCountdownRing {
                            LockScreenCircularDualCountdownPreviewCard(title: localizedPrayerName("Maghrib"), innerProgress: 0.34, outerProgress: 0.62)
                        } else {
                            LockScreenCircularDualCountdownNextPrayerPreviewCard(title: localizedPrayerName("Isyak"), time: "19:31", innerProgress: 0.34, outerProgress: 0.62)
                        }
                    }
                    .padding(.bottom, 18)
                }
            }
            .frame(width: 160, height: 206)
            .overlay(
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .strokeBorder(isSelected ? settings.accentColor.color : Color.black.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
            )
            .lockedWidgetCardStyle(isLocked: isLocked, isSelected: isSelected, accentColor: settings.accentColor.color, cornerRadius: 40)
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                PremiumCardStatusText(
                    isSelected: isSelected,
                    isLocked: false,
                    summary: style.summary,
                    selectedTint: settings.accentColor.color
                )
            }
            .frame(width: 160, alignment: .leading)
        }
    }
}

private struct LockScreenCircularPercentagePreviewCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let percentage: Int
    let iconName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.secondarySystemBackground))
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)

            Circle()
                .stroke(Color.primary.opacity(0.25), lineWidth: 6)
                .padding(12)

            Circle()
                .trim(from: 0, to: 0.60)
                .stroke(
                    Color.primary,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(12)

            VStack(spacing: 1) {
                Text("\(percentage)%")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .monospacedDigit()

                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.9) : Color.primary.opacity(0.85))
            }
            .padding(.top, 2)
        }
        .frame(width: 98, height: 98)
    }
}

private struct PrayerListStyleCard: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    let style: PrayerListWidgetStyle
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black : Color(.systemBackground))

                LinearGradient(
                    colors: [
                        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03),
                        settings.accentColor.color.opacity(colorScheme == .dark ? 0.12 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(spacing: 0) {
                    HStack {
                        Text("Thu 26")
                        Spacer()
                        Text("8:14")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary.opacity(0.82))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    Spacer()

                    Group {
                        if style == .classic {
                            LockScreenPrayerListPreviewCard(footer: "Taiping, Perak")
                        } else if style == .focus {
                            LockScreenPrayerListFocusPreviewCard(footer: "Taiping, Perak", accentColor: settings.accentColor.color)
                        } else if style == .departuresBoard {
                            LockScreenPrayerListDeparturesPreviewCard(footer: "Taiping, Perak")
                        } else if style == .iconBoard {
                            LockScreenPrayerListIconBoardPreviewCard(columns: 3)
                        } else {
                            LockScreenPrayerListIconBoardPreviewCard(columns: 6)
                        }
                    }
                    .frame(width: 188)
                    .padding(.bottom, 20)
                }
            }
            .frame(width: 188, height: 220)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(isSelected ? settings.accentColor.color : Color.black.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
            )
            .lockedWidgetCardStyle(isLocked: isLocked, isSelected: isSelected, accentColor: settings.accentColor.color)
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                PremiumCardStatusText(
                    isSelected: isSelected,
                    isLocked: isLocked,
                    summary: style.summary,
                    selectedTint: settings.accentColor.color
                )
            }
            .frame(width: 188, alignment: .leading)
        }
    }
}

private struct LockScreenPrayerListIconBoardPreviewCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let columns: Int

    private let samples: [(time: String, icon: String, name: String)] = [
        ("6:16", "sun.horizon", "Subuh"),
        ("7:28", "sunrise", "Syuruk"),
        ("1:19", "sun.max", "Zuhur"),
        ("4:42", "sun.min", "Asar"),
        ("7:31", "sunset", "Maghrib"),
        ("8:44", "moon.stars.fill", "Isyak")
    ]

    var body: some View {
        let visibleSamples = Array(samples.prefix(columns))

        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.primary.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.primary.opacity(0.10), lineWidth: 1)
            )
            .overlay {
                HStack(alignment: .center, spacing: columns == 3 ? 10 : 6) {
                    ForEach(Array(visibleSamples.enumerated()), id: \.offset) { index, sample in
                        VStack(spacing: 3) {
                            Text(sample.time)
                                .font(.system(size: columns == 3 ? 10 : 8, weight: .bold, design: .rounded))
                                .foregroundStyle(index < 2 ? Color.primary : Color.secondary)
                                .monospacedDigit()
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .minimumScaleFactor(columns == 3 ? 0.75 : 0.9)

                            Image(systemName: sample.icon)
                                .font(.system(size: columns == 3 ? 15 : 13, weight: .semibold))
                                .foregroundStyle(index < 2 ? Color.primary : Color.secondary)
                                .frame(width: columns == 3 ? 18 : 16, height: columns == 3 ? 18 : 16)

                            Text(sample.name)
                                .font(.system(size: columns == 3 ? 9 : 7, weight: .bold, design: .rounded))
                                .foregroundStyle(index < 2 ? Color.primary : Color.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(columns == 3 ? 0.7 : 0.65)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, columns == 3 ? 12 : 8)
                .padding(.vertical, 10)
            }
            .frame(height: columns == 3 ? 74 : 78)
            .padding(.horizontal, 8)
    }
}
private struct DailyVerseStyleCard: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    let style: DailyVerseWidgetStyle
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black : Color(.systemBackground))

                LinearGradient(
                    colors: [
                        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03),
                        settings.accentColor.color.opacity(colorScheme == .dark ? 0.12 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(spacing: 0) {
                    HStack {
                        Text("Thu 26")
                        Spacer()
                        Text("8:14")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary.opacity(0.82))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    Spacer()

                    Group {
                        if style.isCentered == false {
                            LockScreenVersePreviewCard(
                                verse: "Be grateful for the favor of Allah.",
                                reference: "An-Nahl 16:114",
                                style: style
                            )
                        } else {
                            LockScreenVerseCenteredPreviewCard(
                                verse: "Be grateful for the favor of Allah.",
                                reference: "An-Nahl 16:114",
                                style: style
                            )
                        }
                    }
                    .frame(width: 188)
                    .padding(.bottom, 14)
                }
            }
            .frame(width: 188, height: 188)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(isSelected ? settings.accentColor.color : Color.black.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
            )
            .lockedWidgetCardStyle(isLocked: isLocked, isSelected: isSelected, accentColor: settings.accentColor.color)
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                PremiumCardStatusText(
                    isSelected: isSelected,
                    isLocked: isLocked,
                    summary: style.summary,
                    selectedTint: settings.accentColor.color
                )
            }
            .frame(width: 188, alignment: .leading)
        }
    }
}

private struct LockScreenSpotlightCard: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    let style: LockScreenWidgetPreviewStyle
    let isSelected: Bool

    private var widgetWidth: CGFloat {
        style == .nextPrayerCircular ? 160 : 188
    }

    private var widgetHeight: CGFloat {
        style == .nextPrayerCircular ? 206 : 220
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: style == .nextPrayerCircular ? 40 : 28, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black : Color(.systemBackground))

                LinearGradient(
                    colors: [
                        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03),
                        settings.accentColor.color.opacity(colorScheme == .dark ? 0.12 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: style == .nextPrayerCircular ? 40 : 28, style: .continuous))

                VStack(spacing: 0) {
                    HStack {
                        Text("Thu 26")
                        Spacer()
                        Text("8:14")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary.opacity(0.82))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    Spacer()

                    widgetBody
                        .frame(width: widgetWidth)
                        .padding(.bottom, style == .nextPrayerCircular ? 18 : 20)
                }
            }
            .frame(width: widgetWidth, height: widgetHeight)
            .overlay(
                RoundedRectangle(cornerRadius: style == .nextPrayerCircular ? 40 : 28, style: .continuous)
                    .strokeBorder(isSelected ? settings.accentColor.color : Color.black.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                PremiumCardStatusText(
                    isSelected: isSelected,
                    isLocked: false,
                    summary: style.summary,
                    selectedTint: settings.accentColor.color
                )
            }
            .frame(width: widgetWidth, alignment: .leading)
        }
    }

    @ViewBuilder
    private var widgetBody: some View {
        switch style {
        case .nextPrayerCircular:
            LockScreenCircularPreviewCard(title: localizedPrayerName("Isha"), time: "19:31")
        case .prayerTimeline:
            PrayerTimelineGraphPreviewCard(
                currentPrayer: localizedPrayerName("Maghrib"),
                nextPrayer: localizedPrayerName("Isha"),
                nextTime: "19:31",
                footer: "Taiping, Perak",
                accentColor: settings.accentColor.color
            )
        case .prayerList:
            LockScreenPrayerListPreviewCard(footer: "Taiping, Perak")
        case .prayerCountdown:
            LockScreenCountdownPreviewCard(
                prayer: localizedPrayerName("Isha"),
                timerText: "19:31",
                footer: "Taiping, Perak",
                accentColor: settings.accentColor.color,
                batteryStyle: false
            )
        case .zikir:
            LockScreenRectangularZikirPreviewCard(
                helperTitle: isMalayAppLanguage() ? "Zikir malam" : "Night Zikir",
                arabic: "أَسْتَغْفِرُ اللَّهَ",
                translation: isMalayAppLanguage() ? "Aku memohon ampun kepada Allah." : "I seek forgiveness from Allah.",
                alignment: .center
            )
        case .dailyVerse:
            LockScreenVersePreviewCard(
                verse: isMalayAppLanguage() ? "Maha Suci Allah dan segala puji bagi-Nya." : "Glory be to Allah and praise be to Him.",
                reference: "Al-Ahzab 56",
                style: .classic
            )
        }
    }
}

private struct PrayerTimesStyleCard: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    let style: LockScreenPrayerTimesStyle
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black : Color(.systemBackground))

                LinearGradient(
                    colors: [
                        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03),
                        settings.accentColor.color.opacity(colorScheme == .dark ? 0.12 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(spacing: 0) {
                    HStack {
                        Text("Thu 26")
                        Spacer()
                        Text("8:14")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary.opacity(0.82))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    Spacer()

                    if style == .prayerCountdownWithLocation {
                        PrayerDotsPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: "Taiping, Perak",
                            accentColor: settings.accentColor.color,
                            showsLabels: true,
                            centered: false
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else if style == .prayerCountdownWithoutLocation {
                        PrayerDotsPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: nil,
                            accentColor: settings.accentColor.color,
                            showsLabels: true,
                            centered: false
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else if style == .prayerCountdownClassicWithLocation {
                        PrayerDotsPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: "Taiping, Perak",
                            accentColor: settings.accentColor.color,
                            showsLabels: false,
                            centered: false
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else if style == .prayerCountdownClassicWithoutLocation {
                        PrayerDotsPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: nil,
                            accentColor: settings.accentColor.color,
                            showsLabels: false,
                            centered: false
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else if style == .prayerCountdownCenteredWithLocation {
                        PrayerDotsPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: "Taiping, Perak",
                            accentColor: settings.accentColor.color,
                            showsLabels: false,
                            centered: true
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else if style == .prayerCountdownCenteredWithoutLocation {
                        PrayerDotsPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: nil,
                            accentColor: settings.accentColor.color,
                            showsLabels: false,
                            centered: true
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else if style == .prayerTimelineWithLocation {
                        PrayerTimelineGraphPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: "Taiping, Perak",
                            accentColor: settings.accentColor.color
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else if style == .prayerTimelineWithoutLocation {
                        PrayerTimelineGraphPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: nil,
                            accentColor: settings.accentColor.color
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else if style == .prayerTimelinePlusWithLocation {
                        CurvierPrayerTimelineGraphPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: "Taiping, Perak",
                            accentColor: settings.accentColor.color
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else {
                        CurvierPrayerTimelineGraphPreviewCard(
                            currentPrayer: localizedPrayerName("Maghrib"),
                            nextPrayer: localizedPrayerName("Isha"),
                            nextTime: "19:31",
                            footer: nil,
                            accentColor: settings.accentColor.color
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    }
                }
            }
            .frame(width: 188, height: 220)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(isSelected ? settings.accentColor.color : Color.black.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
            )
            .lockedWidgetCardStyle(isLocked: isLocked, isSelected: isSelected, accentColor: settings.accentColor.color)
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                PremiumCardStatusText(
                    isSelected: isSelected,
                    isLocked: isLocked,
                    summary: style.summary,
                    selectedTint: settings.accentColor.color
                )
            }
            .frame(width: 188, alignment: .leading)
        }
    }
}

private struct PrayerCountdownBarStyleCard: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    let style: LockScreenPrayerCountdownBarStyle
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black : Color(.systemBackground))

                LinearGradient(
                    colors: [
                        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03),
                        settings.accentColor.color.opacity(colorScheme == .dark ? 0.12 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(spacing: 0) {
                    HStack {
                        Text("Thu 26")
                        Spacer()
                        Text("8:14")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary.opacity(0.82))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    Spacer()

                    if style == .withLocation || style == .withoutLocation {
                        LockScreenCountdownPreviewCard(
                            prayer: localizedPrayerName("Maghrib"),
                            timerText: "19:31",
                            footer: style == .withLocation ? "Taiping, Perak" : "",
                            accentColor: settings.accentColor.color,
                            batteryStyle: false
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    } else if style == .batteryWithLocation || style == .batteryWithoutLocation {
                        LockScreenCountdownPreviewCard(
                            prayer: localizedPrayerName("Maghrib"),
                            timerText: "1h 12m",
                            footer: style == .batteryWithLocation ? "Taiping, Perak" : "",
                            accentColor: settings.accentColor.color,
                            batteryStyle: true
                        )
                        .frame(width: 188)
                        .padding(.bottom, 20)
                    }
                }
            }
            .frame(width: 188, height: 220)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(isSelected ? settings.accentColor.color : Color.black.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
            )
            .lockedWidgetCardStyle(isLocked: isLocked, isSelected: isSelected, accentColor: settings.accentColor.color)
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                PremiumCardStatusText(
                    isSelected: isSelected,
                    isLocked: isLocked,
                    summary: style.summary,
                    selectedTint: settings.accentColor.color
                )
            }
            .frame(width: 188, alignment: .leading)
        }
    }
}

private struct ZikirStyleCard: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme

    let alignment: WidgetZikirAlignment
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(colorScheme == .dark ? Color.black : Color(.systemBackground))

                LinearGradient(
                    colors: [
                        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03),
                        settings.accentColor.color.opacity(colorScheme == .dark ? 0.12 : 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(spacing: 0) {
                    HStack {
                        Text("Thu 26")
                        Spacer()
                        Text("8:14")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary.opacity(0.82))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    Spacer()

                    LockScreenRectangularZikirPreviewCard(
                        helperTitle: isMalayAppLanguage() ? "Zikir malam" : "Night Zikir",
                        arabic: "أَسْتَغْفِرُ اللَّهَ",
                        translation: isMalayAppLanguage() ? "Aku memohon ampun kepada Allah." : "I seek forgiveness from Allah.",
                        alignment: alignment
                    )
                    .frame(width: 188)
                    .padding(.bottom, 20)
                }
            }
            .frame(width: 188, height: 220)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(isSelected ? settings.accentColor.color : Color.black.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
            )
            .lockedWidgetCardStyle(isLocked: isLocked, isSelected: isSelected, accentColor: settings.accentColor.color)
            .shadow(color: Color.black.opacity(0.10), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(alignment.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                PremiumCardStatusText(
                    isSelected: isSelected,
                    isLocked: isLocked,
                    summary: alignment.summary,
                    selectedTint: settings.accentColor.color
                )
            }
            .frame(width: 188, alignment: .leading)
        }
    }
}

private struct LockScreenCircularPreviewCard: View {
    let title: String
    let time: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.secondarySystemBackground))
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)

            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(time)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .monospacedDigit()
            }
            .padding(8)
        }
        .frame(width: 98, height: 98)
    }
}

private struct LockScreenCircularMinimalPreviewCard: View {
    let title: String
    let time: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.secondarySystemBackground))
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)

            VStack(spacing: 4) {
                Text(time)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(8)
        }
        .frame(width: 98, height: 98)
    }
}

private struct LockScreenCircularCountdownPreviewCard: View {
    let title: String
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.secondarySystemBackground))
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)

            Circle()
                .stroke(Color.primary.opacity(0.18), lineWidth: 6)
                .padding(12)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(12)

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
                .padding(20)
        }
        .frame(width: 98, height: 98)
    }
}

private struct LockScreenCircularDualCountdownPreviewCard: View {
    let title: String
    let innerProgress: Double
    let outerProgress: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.secondarySystemBackground))
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)

            Circle()
                .stroke(Color.primary.opacity(0.10), lineWidth: 4)
                .padding(8)

            Circle()
                .trim(from: 0, to: outerProgress)
                .stroke(Color.primary.opacity(0.46), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(8)

            Circle()
                .stroke(Color.primary.opacity(0.18), lineWidth: 6)
                .padding(16)

            Circle()
                .trim(from: 0, to: innerProgress)
                .stroke(Color.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(16)

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
                .padding(22)
        }
        .frame(width: 98, height: 98)
    }
}

private struct LockScreenCircularDualCountdownNextPrayerPreviewCard: View {
    let title: String
    let time: String
    let innerProgress: Double
    let outerProgress: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.secondarySystemBackground))
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)

            Circle()
                .stroke(Color.primary.opacity(0.10), lineWidth: 4)
                .padding(8)

            Circle()
                .trim(from: 0, to: outerProgress)
                .stroke(Color.primary.opacity(0.46), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(8)

            Circle()
                .stroke(Color.primary.opacity(0.18), lineWidth: 6)
                .padding(16)

            Circle()
                .trim(from: 0, to: innerProgress)
                .stroke(Color.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(16)

            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)

                Text(time)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .padding(16)
        }
        .frame(width: 98, height: 98)
    }
}

private struct LockScreenTimelinePreviewCard: View {
    let currentPrayer: String
    let nextPrayer: String
    let nextTime: String
    let footer: String?
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(index < 3 ? Color.primary.opacity(0.92) : Color.primary.opacity(0.26))
                        .frame(width: index == 2 ? 10 : 8, height: index == 2 ? 10 : 8)
                }
            }
            .frame(height: 16)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(currentPrayer)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextTime)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextPrayer)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct LockScreenPrayerListPreviewCard: View {
    let footer: String

    private let rows: [(String, String)] = [
        (localizedPrayerName("Asr"), "16:46"),
        (localizedPrayerName("Maghrib"), "19:26"),
        (localizedPrayerName("Isha"), "20:38")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(rows, id: \.0) { row in
                HStack {
                    Text(row.0)
                        .fontWeight(.bold)
                        .lineLimit(1)
                    Spacer()
                    Text(row.1)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
            }

            Text(footer)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .padding(.top, 2)
        }
        .font(.caption)
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct LockScreenPrayerListFocusPreviewCard: View {
    let footer: String
    let accentColor: Color

    private let rows: [(String, String)] = [
        (localizedPrayerName("Maghrib"), "19:26"),
        (localizedPrayerName("Isha"), "20:38"),
        (localizedPrayerName("Fajr"), "05:52")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(rows[0].0)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
                Spacer()
                Text(rows[0].1)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
            }

            ForEach(rows.dropFirst(), id: \.0) { row in
                HStack {
                    Text(row.0)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text(row.1)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Text(footer)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .padding(.top, 2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct LockScreenPrayerListDeparturesPreviewCard: View {
    let footer: String

    private let rows: [(String, String)] = [
        (localizedPrayerName("Maghrib").uppercased(), "19:26"),
        (localizedPrayerName("Isha").uppercased(), "20:38"),
        (localizedPrayerName("Fajr").uppercased(), "05:52")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(rows, id: \.0) { row in
                HStack(spacing: 8) {
                    Text(row.0)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 4)

                    Text(row.1)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.14), lineWidth: 0.8)
                )
            }

            Text(footer)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .padding(.top, 2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct LockScreenCountdownPreviewCard: View {
    let prayer: String
    let timerText: String
    let footer: String
    let accentColor: Color
    let batteryStyle: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(prayer)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 6)
                if batteryStyle {
                    Text(localizedPrayerName("Isyak"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(timerText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            if batteryStyle {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.28), lineWidth: 1.4)
                        .frame(height: 28)

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(accentColor.opacity(0.9))
                        .frame(width: 44, height: 22)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 3)

                    Text(timerText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.82))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .frame(height: 28)
            } else {
                ProgressView(value: 0.62)
                    .progressViewStyle(.linear)
                    .tint(accentColor)
            }

            Text(isMalayAppLanguage() ? "Berakhir pada 20:34" : "Ends at 20:34")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(footer)
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct LockScreenRectangularZikirPreviewCard: View {
    @EnvironmentObject var settings: Settings

    let helperTitle: String
    let arabic: String
    let translation: String
    let alignment: WidgetZikirAlignment

    private var horizontalAlignment: HorizontalAlignment {
        switch alignment {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        case .center, .centerAmiri:
            return .center
        }
    }

    private var textAlignment: TextAlignment {
        switch alignment {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        case .center, .centerAmiri:
            return .center
        }
    }

    private var supportingFont: Font {
        alignment == .centerAmiri
            ? .system(size: 10, weight: .regular, design: .serif)
            : .system(size: 10, weight: .regular)
    }

    private var quranArabicFontName: String {
        if alignment == .centerAmiri {
            let amiriCandidates = [
                "AmiriQuran-Regular",
                "Amiri Quran",
                "Amiri-Regular",
                "Amiri"
            ]
            #if os(iOS)
            for name in amiriCandidates where !name.isEmpty {
                if UIFont(name: name, size: 19) != nil {
                    return name
                }
            }
            #endif
        }
        let candidates = [
            settings.fontArabic,
            "KFGQPCUthmanicScriptHAFS",
            "Uthmani",
            "KFGQPC Uthmanic Script HAFS",
            "UthmanicHafs1 Ver09",
            "AmiriQuran-Regular",
            "Amiri Quran"
        ]
        #if os(iOS)
        for name in candidates where !name.isEmpty {
            if UIFont(name: name, size: 19) != nil {
                return name
            }
        }
        #endif
        return settings.fontArabic
    }

    var body: some View {
        VStack(alignment: horizontalAlignment, spacing: 3) {
            Text(helperTitle)
                .font(alignment == .centerAmiri ? .system(size: 10, weight: .medium, design: .serif) : .system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(arabic)
                .font(.custom(quranArabicFontName, size: 19))
                .multilineTextAlignment(textAlignment)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
            Text(translation)
                .font(supportingFont)
                .foregroundColor(.secondary)
                .multilineTextAlignment(textAlignment)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        case .center, .centerAmiri:
            return .center
        }
    }
}

private struct CurvierPrayerTimelineGraphPreviewCard: View {
    let currentPrayer: String
    let nextPrayer: String
    let nextTime: String
    let footer: String?
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CurvierPreviewPrayerMiniGraph(
                sampleMinutes: [330, 430, 780, 1000, 1166, 1238],
                activeDotIndex: 2
            )

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(currentPrayer)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextTime)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextPrayer)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct CurvierPreviewPrayerMiniGraph: View {
    @Environment(\.colorScheme) private var colorScheme
    let sampleMinutes: [Double]
    let activeDotIndex: Int

    private func normalizedCurveY(_ t: CGFloat) -> CGFloat {
        let clamped = min(max(t, 0), 1)
        let p0: CGFloat = 0.76
        let c1: CGFloat = 0.38
        let c2: CGFloat = 0.02
        let p3: CGFloat = 0.88
        let oneMinusT = 1 - clamped
        return
            (oneMinusT * oneMinusT * oneMinusT * p0) +
            (3 * oneMinusT * oneMinusT * clamped * c1) +
            (3 * oneMinusT * clamped * clamped * c2) +
            (clamped * clamped * clamped * p3)
    }

    private func markerPoints(in size: CGSize) -> [CGPoint] {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let values = sampleMinutes.isEmpty ? [0, 1] : sampleMinutes
        let first = values.first ?? 0
        let last = max(values.last ?? 1, first + 1)
        let range = max(last - first, 1)
        let leftInset = width * 0.03
        let usableWidth = width * 0.94

        return values.map { minute in
            let t = CGFloat((minute - first) / range)
            let x = leftInset + usableWidth * t
            let y = height * normalizedCurveY(t)
            return CGPoint(x: x, y: y)
        }
    }

    private func sampledCurvePath(in size: CGSize) -> Path {
        var path = Path()
        let leftInset = size.width * 0.03
        let usableWidth = size.width * 0.94
        let steps = 48
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let point = CGPoint(
                x: leftInset + usableWidth * t,
                y: size.height * normalizedCurveY(t)
            )
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

    var body: some View {
        GeometryReader { geo in
            let baseLineColor = colorScheme == .light ? Color.black.opacity(0.42) : Color.white.opacity(0.68)
            let futureDotStrokeColor = colorScheme == .light ? Color.black.opacity(0.55) : Color.white.opacity(0.72)
            let activeLineColor = colorScheme == .light ? Color.black.opacity(0.90) : Color.white.opacity(0.95)
            let markers = markerPoints(in: geo.size)
            let peakIndex = markers.enumerated().min(by: { $0.element.y < $1.element.y })?.offset ?? 0
            let clampedActiveIndex = min(max(activeDotIndex, -1), max(markers.count - 1, -1))

            ZStack {
                let curve = sampledCurvePath(in: geo.size)

                ZStack {
                    curve
                        .stroke(baseLineColor, style: .init(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

                    ForEach(Array(markers.enumerated()), id: \.offset) { index, point in
                        Circle()
                            .fill(Color.black)
                            .frame(width: index == peakIndex ? 13 : 11, height: index == peakIndex ? 13 : 11)
                            .position(point)
                            .blendMode(.destinationOut)
                    }
                }
                .compositingGroup()

                ForEach(Array(markers.enumerated()), id: \.offset) { index, point in
                    let isReached = index <= clampedActiveIndex
                    Circle()
                        .fill(isReached ? activeLineColor : Color.clear)
                        .overlay(
                            Circle().stroke(
                                isReached ? activeLineColor : futureDotStrokeColor,
                                lineWidth: 1.8
                            )
                        )
                        .frame(width: index == peakIndex ? 10 : 8, height: index == peakIndex ? 10 : 8)
                        .position(point)
                }
            }
        }
        .frame(height: 30)
    }
}

private struct LockScreenVersePreviewCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let verse: String
    let reference: String
    let style: DailyVerseWidgetStyle
    private let verseFontSize: CGFloat = 13
    private let referenceFontSize: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(reference)
                .font(.custom(style.referenceFontName, size: referenceFontSize))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.9) : Color.primary.opacity(0.82))
                .lineLimit(1)

            Text(verse)
                .font(.custom(style.verseFontName, size: verseFontSize))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.96) : Color.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color.white.opacity(0.18), Color.white.opacity(0.12)]
                            : [Color.black.opacity(0.06), Color.black.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

private struct LockScreenVerseCenteredPreviewCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let verse: String
    let reference: String
    let style: DailyVerseWidgetStyle
    private let verseFontSize: CGFloat = 13
    private let referenceFontSize: CGFloat = 16

    var body: some View {
        VStack(spacing: 4) {
            Text(verse)
                .font(.custom(style.verseFontName, size: verseFontSize))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.96) : Color.primary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.78)

            Text(reference)
                .font(.custom(style.referenceFontName, size: referenceFontSize))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.9) : Color.primary.opacity(0.82))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color.white.opacity(0.18), Color.white.opacity(0.12)]
                            : [Color.black.opacity(0.06), Color.black.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

struct NotificationSoundSelectionView: View {
    @EnvironmentObject var settings: Settings
    #if os(iOS)
    @State private var previewPlayer: AVAudioPlayer?
    #endif

    private func playPreviewIfNeeded(for option: NotificationSoundOption) {
        #if os(iOS)
        guard option == .azan,
              let url = Bundle.main.url(forResource: "azan_waktu", withExtension: "mp3")
        else {
            previewPlayer?.stop()
            previewPlayer = nil
            return
        }
        do {
            previewPlayer = try AVAudioPlayer(contentsOf: url)
            previewPlayer?.prepareToPlay()
            previewPlayer?.play()
        } catch {
            previewPlayer = nil
        }
        #endif
    }

    var body: some View {
        List {
            Section(header: Text("ALERT NOTIFICATION SOUND")) {
                ForEach(NotificationSoundOption.allCases) { option in
                    Button {
                        settings.hapticFeedback()
                        settings.setNotificationSoundOption(option)
                        playPreviewIfNeeded(for: option)
                    } label: {
                        HStack {
                            Text(option.title)
                                .foregroundColor(.primary)
                            Spacer()
                            if settings.notificationSoundOption == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(settings.accentColor.color)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .applyConditionalListStyle(defaultView: true)
        .navigationTitle("Notification Sound")
    }
}

struct MoreNotificationView: View {
    @EnvironmentObject var settings: Settings
    
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var showAlert: Bool = false

    private var notificationPageToggleTint: Color {
        settings.accentColor.toggleTint
    }
    
    private func turnOffNaggingModeIfAllOff() {
        if !settings.naggingFajr &&
           !settings.naggingSunrise &&
           !settings.naggingDhuhr &&
           !settings.naggingAsr &&
           !settings.naggingMaghrib &&
           !settings.naggingIsha {
            
            withAnimation {
                settings.naggingMode = false
            }
        }
    }
    
    var body: some View {
        List {
            Section(header: Text(appLocalized("NAGGING MODE"))) {
                Text(appLocalized("Nagging mode helps those who struggle to pray on time. Once enabled, you'll get a notification at the chosen start time before each prayer, then another every 15 minutes, plus final reminders at 10 and 5 minutes remaining."))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Toggle(appLocalized("Turn on Nagging Mode"), isOn: Binding(
                    get: { settings.naggingMode },
                    set: { newValue in
                        withAnimation {
                            settings.naggingMode = newValue
                            
                            if newValue {
                                settings.notificationFajr = true
                                settings.notificationSunrise = true
                                settings.notificationDhuhr = true
                                settings.notificationAsr = true
                                settings.notificationMaghrib = true
                                settings.notificationIsha = true
                                
                                settings.naggingFajr = true
                                settings.naggingSunrise = true
                                settings.naggingDhuhr = true
                                settings.naggingAsr = true
                                settings.naggingMaghrib = true
                                settings.naggingIsha = true
                            } else {
                                settings.naggingFajr = false
                                settings.naggingSunrise = false
                                settings.naggingDhuhr = false
                                settings.naggingAsr = false
                                settings.naggingMaghrib = false
                                settings.naggingIsha = false
                            }
                        }
                    }
                ).animation(.easeInOut))
                .font(.subheadline)
                .tint(notificationPageToggleTint)
                
                if settings.naggingMode {
                    Picker(appLocalized("Starting Time"), selection: $settings.naggingStartOffset.animation(.easeInOut)) {
                        Text(appLocalized("45 mins")).tag(45)
                        Text(appLocalized("30 mins")).tag(30)
                        Text(appLocalized("15 mins")).tag(15)
                        Text(appLocalized("10 mins")).tag(10)
                    }
                    #if !os(watchOS)
                    .pickerStyle(.segmented)
                    #endif
                    
                    Group {
                        Toggle(appLocalized("Nagging before Fajr"), isOn: Binding(
                            get: { settings.naggingFajr },
                            set: { newValue in
                                settings.naggingFajr = newValue
                                turnOffNaggingModeIfAllOff()
                            }
                        ).animation(.easeInOut))
                        
                        Toggle(appLocalized("Nagging before Sunrise"), isOn: Binding(
                            get: { settings.naggingSunrise },
                            set: { newValue in
                                settings.naggingSunrise = newValue
                                turnOffNaggingModeIfAllOff()
                            }
                        ).animation(.easeInOut))
                        
                        Toggle(appLocalized("Nagging before Dhuhr"), isOn: Binding(
                            get: { settings.naggingDhuhr },
                            set: { newValue in
                                settings.naggingDhuhr = newValue
                                turnOffNaggingModeIfAllOff()
                            }
                        ).animation(.easeInOut))
                        
                        Toggle(appLocalized("Nagging before Asr"), isOn: Binding(
                            get: { settings.naggingAsr },
                            set: { newValue in
                                settings.naggingAsr = newValue
                                turnOffNaggingModeIfAllOff()
                            }
                        ).animation(.easeInOut))
                        
                        Toggle(appLocalized("Nagging before Maghrib"), isOn: Binding(
                            get: { settings.naggingMaghrib },
                            set: { newValue in
                                settings.naggingMaghrib = newValue
                                turnOffNaggingModeIfAllOff()
                            }
                        ).animation(.easeInOut))
                        
                        Toggle(appLocalized("Nagging before Isha"), isOn: Binding(
                            get: { settings.naggingIsha },
                            set: { newValue in
                                settings.naggingIsha = newValue
                                turnOffNaggingModeIfAllOff()
                            }
                        ).animation(.easeInOut))
                    }
                    .tint(notificationPageToggleTint)
                }
            }
            
            if !settings.naggingMode {
                Section(header: Text(appLocalized("ALL PRAYER NOTIFICATIONS"))) {
                    Toggle(appLocalized("Turn On All Prayer Notifications"), isOn: Binding(
                        get: {
                            settings.notificationFajr &&
                            settings.notificationSunrise &&
                            settings.notificationDhuhr &&
                            settings.notificationAsr &&
                            settings.notificationMaghrib &&
                            settings.notificationIsha
                        },
                        set: { newValue in
                            withAnimation {
                                settings.notificationFajr = newValue
                                settings.notificationSunrise = newValue
                                settings.notificationDhuhr = newValue
                                settings.notificationAsr = newValue
                                settings.notificationMaghrib = newValue
                                settings.notificationIsha = newValue
                            }
                        }
                    ).animation(.easeInOut))
                    .font(.subheadline)
                    .tint(notificationPageToggleTint)
                    
                    Stepper(value: Binding(
                        get: { settings.preNotificationFajr },
                        set: { newValue in
                            withAnimation {
                                settings.preNotificationFajr = newValue
                                settings.preNotificationSunrise = newValue
                                settings.preNotificationDhuhr = newValue
                                settings.preNotificationAsr = newValue
                                settings.preNotificationMaghrib = newValue
                                settings.preNotificationIsha = newValue
                            }
                        }
                    ), in: 0...30, step: 5) {
                        Text(appLocalized("All Prayer Prenotifications:"))
                            .font(.subheadline)
                        Text("\(settings.preNotificationFajr) \(appLocalized(settings.preNotificationFajr != 1 ? "minutes" : "minute"))")
                            .font(.subheadline)
                            .foregroundColor(settings.accentColor.color)
                    }
                }
            }
            
            if !settings.naggingMode {
                NotificationSettingsSection(prayerName: "Fajr", preNotificationTime: $settings.preNotificationFajr, isNotificationOn: $settings.notificationFajr)
                NotificationSettingsSection(prayerName: "Shurooq", preNotificationTime: $settings.preNotificationSunrise, isNotificationOn: $settings.notificationSunrise)
                NotificationSettingsSection(prayerName: "Dhuhr", preNotificationTime: $settings.preNotificationDhuhr, isNotificationOn: $settings.notificationDhuhr)
                NotificationSettingsSection(prayerName: "Asr", preNotificationTime: $settings.preNotificationAsr, isNotificationOn: $settings.notificationAsr)
                NotificationSettingsSection(prayerName: "Maghrib", preNotificationTime: $settings.preNotificationMaghrib, isNotificationOn: $settings.notificationMaghrib)
                NotificationSettingsSection(prayerName: "Isha", preNotificationTime: $settings.preNotificationIsha, isNotificationOn: $settings.notificationIsha)
            } else {
                if !settings.naggingFajr {
                    NotificationSettingsSection(prayerName: "Fajr", preNotificationTime: $settings.preNotificationFajr, isNotificationOn: $settings.notificationFajr)
                }
                if !settings.naggingSunrise {
                    NotificationSettingsSection(prayerName: "Shurooq", preNotificationTime: $settings.preNotificationSunrise, isNotificationOn: $settings.notificationSunrise)
                }
                if !settings.naggingDhuhr {
                    NotificationSettingsSection(prayerName: "Dhuhr", preNotificationTime: $settings.preNotificationDhuhr, isNotificationOn: $settings.notificationDhuhr)
                }
                if !settings.naggingAsr {
                    NotificationSettingsSection(prayerName: "Asr", preNotificationTime: $settings.preNotificationAsr, isNotificationOn: $settings.notificationAsr)
                }
                if !settings.naggingMaghrib {
                    NotificationSettingsSection(prayerName: "Maghrib", preNotificationTime: $settings.preNotificationMaghrib, isNotificationOn: $settings.notificationMaghrib)
                }
                if !settings.naggingIsha {
                    NotificationSettingsSection(prayerName: "Isha", preNotificationTime: $settings.preNotificationIsha, isNotificationOn: $settings.notificationIsha)
                }
            }
        }
        .onAppear { syncNotificationSettingsPage() }
        .onChange(of: scenePhase) { _ in
            if scenePhase == .active {
                syncNotificationSettingsPage()
            }
        }
        .onDisappear {
            settings.fetchPrayerTimes(notification: true)
        }
        .confirmationDialog("", isPresented: $showAlert, titleVisibility: .visible) {
            Button("Open Settings") {
                #if !os(watchOS)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
                #endif
            }
            Button("Ignore", role: .cancel) { }
        } message: {
            Text(appLocalized("Please go to Settings and enable notifications to be notified of prayer times."))
        }
        .applyConditionalListStyle(defaultView: true)
        .navigationTitle(appLocalized("Prayer Notifications"))
    }

    private func syncNotificationSettingsPage() {
        Task { @MainActor in
            let authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            settings.fetchPrayerTimes(notification: true) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if settings.showNotificationAlert && authorizationStatus == .denied {
                        showAlert = true
                    }
                }
            }
        }
    }
}

private struct PrayerTimelineGraphPreviewCard: View {
    let currentPrayer: String
    let nextPrayer: String
    let nextTime: String
    let footer: String?
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PreviewPrayerMiniGraph(
                tint: accentColor,
                dotCount: 6,
                activeDotIndex: 2
            )

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(currentPrayer)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(accentColor)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextTime)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextPrayer)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct PrayerDotsPreviewCard: View {
    let currentPrayer: String
    let nextPrayer: String
    let nextTime: String
    let footer: String?
    let accentColor: Color
    let showsLabels: Bool
    let centered: Bool
    private let labels = ["SB", "SY", "ZH", "AS", "MG", "IS"]

    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 7) {
            HStack(spacing: showsLabels ? 5 : 3) {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    VStack(spacing: 3) {
                        Circle()
                            .fill(index <= 4 ? Color.primary.opacity(0.92) : Color.primary.opacity(0.26))
                            .frame(width: index == 4 ? 10 : 8, height: index == 4 ? 10 : 8)

                        if showsLabels {
                            Text(label)
                                .font(.system(size: 7, weight: .semibold, design: .rounded))
                                .foregroundStyle(index == 4 ? accentColor : .secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: showsLabels ? .infinity : nil)
                }
            }
            .frame(height: showsLabels ? 26 : 16)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(currentPrayer)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(accentColor)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextTime)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(nextPrayer)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: centered ? .center : .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct PreviewPrayerMiniGraph: View {
    @Environment(\.colorScheme) private var colorScheme
    let tint: Color
    let dotCount: Int
    let activeDotIndex: Int

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = max(geo.size.height, 1)
            let p: (CGFloat, CGFloat) -> CGPoint = { x, y in .init(x: x * width, y: y * height) }

            let p0 = p(0.06, 0.70)
            let p1 = p(0.52, 0.10)
            let p2 = p(0.78, 0.26)
            let p3 = p(0.94, 0.66)
            let c01a = p(0.22, 0.70)
            let c01b = p(0.38, 0.08)
            let c12a = p(0.60, 0.10)
            let c12b = p(0.70, 0.24)
            let c23a = p(0.84, 0.30)
            let c23b = p(0.90, 0.66)
            let clampedDots = min(max(dotCount, 2), 6)

            let cubicPoint: (CGPoint, CGPoint, CGPoint, CGPoint, CGFloat) -> CGPoint = { a, b, c, d, t in
                let oneMinusT = 1 - t
                let x = (oneMinusT * oneMinusT * oneMinusT * a.x)
                    + (3 * oneMinusT * oneMinusT * t * b.x)
                    + (3 * oneMinusT * t * t * c.x)
                    + (t * t * t * d.x)
                let y = (oneMinusT * oneMinusT * oneMinusT * a.y)
                    + (3 * oneMinusT * oneMinusT * t * b.y)
                    + (3 * oneMinusT * t * t * c.y)
                    + (t * t * t * d.y)
                return CGPoint(x: x, y: y)
            }

            let baseLineColor = colorScheme == .light ? Color.black.opacity(0.42) : Color.white.opacity(0.68)
            let activeLineColor = colorScheme == .light ? Color.black.opacity(0.90) : Color.white.opacity(0.95)
            let futureDotStrokeColor = colorScheme == .light ? Color.black.opacity(0.55) : Color.white.opacity(0.72)
            let clampedActiveIndex = min(max(activeDotIndex, -1), max(clampedDots - 1, -1))

            let markers: [CGPoint] = {
                let m1 = cubicPoint(p0, c01a, c01b, p1, 0.50)
                let m3 = cubicPoint(p2, c23a, c23b, p3, 0.50)
                return Array([p0, m1, p1, p2, m3, p3].prefix(clampedDots))
            }()

            let peakIndex = markers.enumerated().min(by: { $0.element.y < $1.element.y })?.offset ?? 0

            ZStack {
                let curve = Path { path in
                    path.move(to: p0)
                    path.addCurve(to: p1, control1: c01a, control2: c01b)
                    path.addCurve(to: p2, control1: c12a, control2: c12b)
                    path.addCurve(to: p3, control1: c23a, control2: c23b)
                }

                ZStack {
                    curve
                        .stroke(baseLineColor, style: .init(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

                    ForEach(Array(markers.enumerated()), id: \.offset) { index, point in
                        Circle()
                            .fill(Color.black)
                            .frame(
                                width: index == peakIndex ? 13 : 11,
                                height: index == peakIndex ? 13 : 11
                            )
                            .position(point)
                            .blendMode(.destinationOut)
                    }
                }
                .compositingGroup()

                ForEach(Array(markers.enumerated()), id: \.offset) { index, point in
                    let isReached = index <= clampedActiveIndex
                    Circle()
                        .fill(isReached ? activeLineColor : Color.clear)
                        .overlay(
                            Circle().stroke(
                                isReached ? activeLineColor : futureDotStrokeColor,
                                lineWidth: 1.8
                            )
                        )
                        .frame(
                            width: index == peakIndex ? 10 : 8,
                            height: index == peakIndex ? 10 : 8
                        )
                        .position(point)
                }
            }
        }
        .frame(height: 20)
    }
}

struct NotificationSettingsSection: View {
    @EnvironmentObject var settings: Settings
    
    let prayerName: String
    
    @Binding var preNotificationTime: Int
    @Binding var isNotificationOn: Bool

    private var notificationPageToggleTint: Color {
        settings.accentColor.toggleTint
    }

    var body: some View {
        Section(header: Text(localizedPrayerName(prayerName).uppercased())) {
            Toggle(appLocalized("Notification"), isOn: $isNotificationOn.animation(.easeInOut))
                .font(.subheadline)
                .tint(notificationPageToggleTint)
            
            if isNotificationOn {
                Stepper(value: $preNotificationTime.animation(.easeInOut), in: 0...30, step: 5) {
                    Text(appLocalized("Prenotification Time:"))
                        .font(.subheadline)
                    
                    Text("\(preNotificationTime) \(appLocalized(preNotificationTime != 1 ? "minutes" : "minute"))")
                        .font(.subheadline)
                        .foregroundColor(settings.accentColor.color)
                }
            }
        }
    }
}


#Preview {
    SettingsAdhanView(showNotifications: true)
        .environmentObject(Settings.shared)
}
