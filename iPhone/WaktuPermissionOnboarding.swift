import SwiftUI
import CoreLocation

struct WaktuPermissionOnboarding: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) var colorScheme

    @State private var currentSlide = 0
    @State private var locationStatus: CLAuthorizationStatus = CLLocationManager.authorizationStatus()

    private var bgColor: Color {
        colorScheme == .dark
            ? Color(red: 0.08, green: 0.08, blue: 0.08)
            : Color(red: 0.92, green: 0.92, blue: 0.92)
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            WaktuFloatingWordsBackground()
                .opacity(0.6)

            VStack(spacing: 0) {
                // Slide indicator
                HStack(spacing: 6) {
                    ForEach(0..<2) { i in
                        Capsule()
                            .fill(i == currentSlide ? Color.primary : Color.primary.opacity(0.2))
                            .frame(width: i == currentSlide ? 22 : 8, height: 6)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentSlide)
                    }
                }
                .padding(.top, 24)

                Spacer()

                if currentSlide == 0 {
                    locationSlide
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    allSetSlide
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }

                Spacer()

                bottomButton
                    .padding(.horizontal, 28)
                    .padding(.bottom, 34)
            }
        }
    }

    // MARK: - Slide 1: Location

    private var locationSlide: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 140, height: 140)

                Image(systemName: locationIconName)
                    .font(.system(size: 58, weight: .light))
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .modifier(PulseIfAvailable(isActive: locationStatus == .notDetermined))
            }

            VStack(spacing: 12) {
                Text("Prayer times,\nwherever you are")
                    .font(.system(size: 32, weight: .semibold, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text("Waktu uses your location to calculate precise prayer times. Your location never leaves your device.")
                    .font(.system(size: 15, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.primary.opacity(0.58))
                    .padding(.horizontal, 24)
            }

            if locationStatus == .denied || locationStatus == .restricted {
                Label("Location access denied — enable it in Settings to get prayer times.", systemImage: "exclamationmark.triangle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.orange.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            } else if locationStatus == .notDetermined {
                Text("When prompted, choose **Always Allow** so Waktu can quietly refresh your prayer times as you move — without needing to open the app first.")
                    .font(.system(size: 12, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.primary.opacity(0.42))
                    .padding(.horizontal, 32)
            }
        }
    }

    // MARK: - Slide 2: All set

    private var allSetSlide: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 140, height: 140)

                Image(systemName: "checkmark")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(Color.primary.opacity(0.85))
            }

            VStack(spacing: 12) {
                Text("You're all set")
                    .font(.system(size: 32, weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)

                Text("Prayer times, azan reminders, and daily\nreflections are ready whenever you are.")
                    .font(.system(size: 15, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.primary.opacity(0.58))
                    .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Bottom button

    private var bottomButton: some View {
        Button(action: handleButtonTap) {
            Text(buttonLabel)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(UIColor.systemBackground))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.primary)
                )
        }
    }

    private var buttonLabel: String {
        switch currentSlide {
        case 0:
            switch locationStatus {
            case .notDetermined: return "Allow Location Access"
            case .authorizedAlways: return "Continue"
            case .authorizedWhenInUse: return "Continue"
            default: return "Continue Anyway"
            }
        default:
            return "Get Started"
        }
    }

    private var locationIconName: String {
        switch locationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return "location.fill"
        case .denied, .restricted: return "location.slash"
        default: return "location"
        }
    }

    private func handleButtonTap() {
        settings.hapticFeedback()

        if currentSlide == 0 {
            if locationStatus == .notDetermined {
                settings.requestLocationAuthorization()
                // Observe status change then advance
                observeLocationStatus()
            } else {
                advanceSlide()
            }
        } else {
            // Done
            withAnimation {
                settings.firstLaunch = false
            }
        }
    }

    private func advanceSlide() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
            currentSlide = 1
        }
    }

    private func observeLocationStatus() {
        // Poll briefly after requesting — the system dialog dismissal updates CLLocationManager
        Task { @MainActor in
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                let status = CLLocationManager.authorizationStatus()
                if status != .notDetermined {
                    locationStatus = status
                    advanceSlide()
                    return
                }
            }
            // User dismissed without deciding — allow advancing anyway
            advanceSlide()
        }
    }
}

private struct PulseIfAvailable: ViewModifier {
    let isActive: Bool
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.symbolEffect(.pulse, isActive: isActive)
        } else {
            content
        }
    }
}

#Preview {
    WaktuPermissionOnboarding()
        .environmentObject(Settings.shared)
}
