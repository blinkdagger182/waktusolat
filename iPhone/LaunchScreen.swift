import SwiftUI

struct LaunchScreen: View {
    @Binding var isLaunching: Bool
    @Environment(\.colorScheme) var colorScheme

    @State private var phase: SplashPhase = .hidden

    private var bgColor: Color {
        colorScheme == .dark
            ? Color(red: 0.08, green: 0.08, blue: 0.08)
            : Color(red: 0.92, green: 0.92, blue: 0.92)
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            WaktuFloatingWordsBackground()
                .opacity(phase == .visible ? 1 : 0)
                .animation(.easeIn(duration: 1.2), value: phase)

            VStack(spacing: 0) {
                Spacer()

                WaktuHeroIconView()
                    .scaleEffect(phase == .hidden ? 0.72 : 1.0)
                    .opacity(phase == .hidden ? 0 : 1)
                    .animation(
                        .spring(response: 0.72, dampingFraction: 0.68).delay(0.15),
                        value: phase
                    )
                    .padding(.bottom, 28)

                Text("Waktu")
                    .font(.system(size: 42, weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)
                    .offset(y: phase == .hidden ? 18 : 0)
                    .opacity(phase == .hidden ? 0 : 1)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.75).delay(0.38),
                        value: phase
                    )

                Spacer()
            }
        }
        .onAppear {
            phase = .visible
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                withAnimation(.easeInOut(duration: 0.45)) { phase = .hidden }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isLaunching = false
                }
            }
        }
    }
}

private enum SplashPhase { case hidden, visible }

#Preview {
    LaunchScreen(isLaunching: .constant(true))
}
