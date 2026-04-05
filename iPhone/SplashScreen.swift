import SwiftUI

struct SplashScreen: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) var colorScheme

    @State private var showPermissions = false

    private var bgColor: Color {
        colorScheme == .dark
            ? Color(red: 0.08, green: 0.08, blue: 0.08)
            : Color(red: 0.92, green: 0.92, blue: 0.92)
    }

    var body: some View {
        if showPermissions {
            WaktuPermissionOnboarding()
                .environmentObject(settings)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        } else {
            brandScreen
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
    }

    private var brandScreen: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            WaktuFloatingWordsBackground()

            VStack(spacing: 0) {
                Spacer()

                WaktuHeroIconView()
                    .padding(.bottom, 28)

                VStack(spacing: 14) {
                    Text("Waktu")
                        .font(.system(size: 40, weight: .semibold, design: .serif))
                        .foregroundStyle(.primary)

                    Text("Prayer times that feel calm,\nbeautiful, and easy to return to.")
                        .font(.system(size: 17, weight: .regular))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.primary.opacity(0.62))
                        .padding(.horizontal, 34)
                }

                Spacer()

                Button(action: {
                    settings.hapticFeedback()
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                        showPermissions = true
                    }
                }) {
                    Text("Let's Begin")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(UIColor.systemBackground))
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.primary)
                        )
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 34)
            }
        }
    }
}

#Preview {
    SplashScreen()
        .environmentObject(Settings.shared)
}
