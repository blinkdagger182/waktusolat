import SwiftUI

// MARK: - Shared brand components used by SplashScreen and Onboarding

struct WaktuHeroIconView: View {
    @Environment(\.colorScheme) var colorScheme

    var glowColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.28)
    }

    @State private var drift = false

    var body: some View {
        ZStack {
            Circle()
                .fill(glowColor)
                .frame(width: 250, height: 250)
                .blur(radius: 22)

            Image("CurrentAppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1)
                }
                .shadow(color: Color.primary.opacity(0.10), radius: 20, x: 0, y: 8)
                .offset(y: drift ? -6 : 6)
                .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: drift)
        }
        .onAppear { drift = true }
    }
}

struct WaktuFloatingWordsBackground: View {
    @EnvironmentObject private var settings: Settings

    private var words: [WaktuWordConfig] {
        isMalaysiaCountry ? malaysiaWords : globalWords
    }

    private var isMalaysiaCountry: Bool {
        let detectedCountryCode = settings.currentLocation?.countryCode?.uppercased()
        guard let detectedCountryCode, !detectedCountryCode.isEmpty else {
            return true
        }
        return detectedCountryCode == "MY"
    }

    private let malaysiaWords: [WaktuWordConfig] = [
        WaktuWordConfig(text: "waktu", size: 132, bx: 110, by: 120, dx: 105, dy: 12, speed: 0.18, phase: 0.0, dir: 1, rot: 2.0, blur: 1.0, opacity: 0.12),
        WaktuWordConfig(text: "وقت", size: 138, bx: 295, by: 195, dx: 118, dy: 14, speed: 0.16, phase: 1.0, dir: -1, rot: 2.0, blur: 1.0, opacity: 0.11),
        WaktuWordConfig(text: "masa", size: 120, bx: 100, by: 360, dx: 88, dy: 10, speed: 0.20, phase: 2.0, dir: 1, rot: 1.6, blur: 0.8, opacity: 0.11),
        WaktuWordConfig(text: "زمن", size: 142, bx: 305, by: 520, dx: 110, dy: 13, speed: 0.18, phase: 2.5, dir: -1, rot: 2.4, blur: 0.7, opacity: 0.13),
        WaktuWordConfig(text: "jam", size: 114, bx: 115, by: 700, dx: 94, dy: 10, speed: 0.19, phase: 0.6, dir: 1, rot: 1.7, blur: 0.8, opacity: 0.12),
    ]

    private let globalWords: [WaktuWordConfig] = [
        WaktuWordConfig(text: "waktu",  size: 128, bx: 110, by: 110, dx: 105, dy: 12, speed: 0.18, phase: 0.0, dir:  1, rot: 2.0, blur: 1.0, opacity: 0.12),
        WaktuWordConfig(text: "وقت",   size: 138, bx: 295, by: 170, dx: 120, dy: 14, speed: 0.16, phase: 1.2, dir: -1, rot: 2.0, blur: 1.2, opacity: 0.11),
        WaktuWordConfig(text: "время", size: 110, bx:  90, by: 290, dx:  92, dy: 10, speed: 0.20, phase: 2.0, dir:  1, rot: 1.8, blur: 0.9, opacity: 0.12),
        WaktuWordConfig(text: "時間",   size: 145, bx: 312, by: 325, dx: 112, dy: 15, speed: 0.17, phase: 0.7, dir: -1, rot: 2.8, blur: 0.8, opacity: 0.14),
        WaktuWordConfig(text: "tiempo", size: 120, bx: 110, by: 560, dx: 100, dy: 11, speed: 0.19, phase: 1.6, dir:  1, rot: 2.0, blur: 0.7, opacity: 0.13),
        WaktuWordConfig(text: "زمان",  size: 150, bx: 300, by: 640, dx: 128, dy: 17, speed: 0.18, phase: 2.6, dir: -1, rot: 3.0, blur: 0.5, opacity: 0.16),
        WaktuWordConfig(text: "Zeit",  size: 125, bx:  95, by: 740, dx:  96, dy: 10, speed: 0.21, phase: 0.5, dir:  1, rot: 1.7, blur: 0.8, opacity: 0.12),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(words) { w in WaktuPassingWord(config: w, time: t) }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

struct WaktuWordConfig: Identifiable {
    let id = UUID()
    let text: String
    let size: CGFloat
    let bx, by, dx, dy: CGFloat
    let speed, phase: Double
    let dir: CGFloat
    let rot: Double
    let blur: CGFloat
    let opacity: Double
}

struct WaktuPassingWord: View {
    let config: WaktuWordConfig
    let time: TimeInterval

    var body: some View {
        let progress = sin(time * config.speed + config.phase)
        let sway     = cos(time * config.speed * 0.7 + config.phase)
        Text(config.text)
            .font(.system(size: config.size, weight: .regular, design: .serif))
            .foregroundStyle(Color.primary.opacity(config.opacity))
            .blur(radius: config.blur)
            .rotationEffect(.degrees(Double(progress) * config.rot))
            .position(x: config.bx + progress * config.dx * config.dir,
                      y: config.by + sway * config.dy)
    }
}
