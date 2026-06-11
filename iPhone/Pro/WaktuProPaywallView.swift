import SwiftUI
import StoreKit
#if canImport(RevenueCat)
import RevenueCat
#endif

// MARK: - Phone frame constants

private let kPhoneW:       CGFloat = 174
private let kPhoneH:       CGFloat = 358
private let kScreenW:      CGFloat = 162
private let kScreenH:      CGFloat = 346
private let kCornerPhone:  CGFloat = 42
private let kCornerScreen: CGFloat = 38
private let kIslandW:      CGFloat = 78
private let kIslandH:      CGFloat = 20
private let kIslandY:      CGFloat = -(kScreenH / 2 - 13 - kIslandH / 2) // -150

// MARK: - Slide transform constants

private let kTiltDeg:      Double  = 28       // 3/4 perspective angle
private let kTiltPersp:    CGFloat = 0.45
private let kZoomScale:    CGFloat = 2.2
private let kZoomOffsetY:  CGFloat = 210      // shifts phone so island is in view

struct WaktuProPaywallView: View {
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var revenueCat: RevenueCatManager
    var onPurchaseCompleted: (() -> Void)?
    var onDismiss: (() -> Void)?

    @State private var selectedIndex: Int = 1
    @State private var carouselPage: Int = 0
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var purchaseError: String?

    private let autoScrollTimer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    private let slideTitles = ["Custom App Icons", "Premium Widgets", "Live Activities"]
    private let slideSubtitles = [
        "Express your style with beautifully crafted icons.",
        "Rich prayer insights right on your Home Screen.",
        "Real-time prayer countdowns on your Lock Screen.",
    ]

    // MARK: - RevenueCat

    #if canImport(RevenueCat)
    private var proOffering: Offering? {
        revenueCat.offerings?.all["waktu_pro"] ?? revenueCat.offerings?.all["Waktu Plus Supporter"]
    }
    private var monthlyPackage: Package? {
        proOffering?.availablePackages.first { $0.packageType == .monthly }
    }
    private var annualPackage: Package? {
        proOffering?.availablePackages.first { $0.packageType == .annual }
    }
    private var packages: [Package] {
        [monthlyPackage, annualPackage].compactMap { $0 }
    }
    private var selectedPackage: Package? {
        packages.indices.contains(selectedIndex) ? packages[selectedIndex] : packages.first
    }
    private var savingsPercent: Int? {
        guard let m = monthlyPackage, let a = annualPackage else { return nil }
        let m12 = m.storeProduct.price * 12
        guard m12 > 0 else { return nil }
        let pct = ((m12 - a.storeProduct.price) / m12 * 100) as NSDecimalNumber
        return max(1, Int(truncating: pct))
    }
    #endif

    // MARK: - Per-slide phone transforms

    private var phoneRotationY: Double {
        carouselPage == 1 ? kTiltDeg : 0
    }
    private var phoneScale: CGFloat {
        switch carouselPage {
        case 1: return 0.93   // slight shrink during 3/4 tilt looks more natural
        case 2: return kZoomScale
        default: return 1.0
        }
    }
    private var phoneOffsetY: CGFloat {
        carouselPage == 2 ? kZoomOffsetY : 0
    }
    private var phoneShadowX: CGFloat {
        carouselPage == 1 ? 22 : 0
    }
    private var phoneShadowRadius: CGFloat {
        carouselPage == 2 ? 0 : 24  // no shadow when zoomed (clipped anyway)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection

                    carouselSection
                        .padding(.top, 20)

                    featuresSection
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 280)
                }
                .frame(maxWidth: .infinity)
            }
            .ignoresSafeArea(edges: .top)
        }
        // Bottom panel overlaid — always gets full view width
        .overlay(alignment: .bottom) {
            bottomPanel
        }
        .overlay(alignment: .topTrailing) {
            if onDismiss != nil {
                Button { onDismiss?() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 28, height: 28)
                        .background(Color(.systemGray5), in: Circle())
                }
                .padding(.top, 8)
                .padding(.trailing, 16)
            }
        }
        .onReceive(autoScrollTimer) { _ in
            withAnimation(.spring(response: 0.65, dampingFraction: 0.78)) {
                carouselPage = (carouselPage + 1) % 3
            }
        }
        .task { await revenueCat.refreshOfferings() }
        .alert("Error", isPresented: Binding(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )) {
            Button("OK") { purchaseError = nil }
        } message: {
            Text(purchaseError ?? "")
        }
    }

    // MARK: - Hero
    // Full-bleed, scrolls behind status bar. Bottom gradient only.

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            Image("proHeroBanner")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .clipped()

            LinearGradient(
                colors: [.clear, Color(.systemBackground)],
                startPoint: UnitPoint(x: 0.5, y: 0.0),
                endPoint: .bottom
            )
            .frame(height: 90)
        }
        .frame(height: 240)
    }

    // MARK: - Carousel
    // One iPhone model. Transforms animate on the outer ZStack.
    // Screen content cross-fades independently inside the phone.

    private var carouselSection: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("Choose your style")
                    .font(.system(size: 20, weight: .bold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Text("Unlock custom app icons crafted for Waktu Pro.")
                    .font(.subheadline)
                    .foregroundColor(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)

            // The phone — same model across all slides, transforms driven by carouselPage
            ZStack {
                // Phone body
                RoundedRectangle(cornerRadius: kCornerPhone, style: .continuous)
                    .fill(Color(white: 0.09))
                    .frame(width: kPhoneW, height: kPhoneH)
                    .shadow(
                        color: .black.opacity(0.28),
                        radius: phoneShadowRadius,
                        x: phoneShadowX, y: 10
                    )

                // Screen area — content cross-fades on carouselPage change
                ZStack {
                    screenSlide0
                        .opacity(carouselPage == 0 ? 1 : 0)
                    screenSlide1
                        .opacity(carouselPage == 1 ? 1 : 0)
                    screenSlide2
                        .opacity(carouselPage == 2 ? 1 : 0)
                }
                .frame(width: kScreenW, height: kScreenH)
                .clipShape(RoundedRectangle(cornerRadius: kCornerScreen, style: .continuous))

                // Dynamic island — always on top
                Capsule()
                    .fill(Color(white: 0.09))
                    .frame(width: kIslandW, height: kIslandH)
                    .offset(y: kIslandY)
            }
            // Animate the whole phone smoothly between slides
            .rotation3DEffect(
                .degrees(phoneRotationY),
                axis: (x: 0, y: 1, z: 0),
                perspective: kTiltPersp
            )
            .scaleEffect(phoneScale)
            .offset(y: phoneOffsetY)
            .animation(.spring(response: 0.65, dampingFraction: 0.78), value: carouselPage)
            // Clip overflow (needed for zoom slide to stay within frame)
            .frame(width: kPhoneW, height: kPhoneH)
            .clipShape(RoundedRectangle(cornerRadius: kCornerPhone, style: .continuous))
            // Swipe to advance
            .gesture(
                DragGesture(minimumDistance: 28, coordinateSpace: .local)
                    .onEnded { value in
                        withAnimation(.spring(response: 0.65, dampingFraction: 0.78)) {
                            if value.translation.width < -28 {
                                carouselPage = min(carouselPage + 1, 2)
                            } else if value.translation.width > 28 {
                                carouselPage = max(carouselPage - 1, 0)
                            }
                        }
                    }
            )

            // Page dots
            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i == carouselPage ? Color.primary : Color(.systemGray4))
                        .frame(width: i == carouselPage ? 18 : 6, height: 6)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: carouselPage)
                }
            }

            // Slide label — cross-fades
            VStack(spacing: 4) {
                Text(slideTitles[carouselPage])
                    .font(.system(size: 17, weight: .bold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Text(slideSubtitles[carouselPage])
                    .font(.subheadline)
                    .foregroundColor(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .id(carouselPage)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: carouselPage)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Screen slide 0: App icon on dark home screen

    private var screenSlide0: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.07), Color(white: 0.13)],
                startPoint: .top, endPoint: .bottom
            )
            VStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 74, height: 74)
                        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
                    Image("proIconDark")
                        .resizable().scaledToFit()
                        .frame(width: 56, height: 56)
                }
                Text("Waktu")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    // MARK: - Screen slide 1: Widget screenshot (zoomed in via scaledToFill)

    private var screenSlide1: some View {
        Image("proCarousel2")
            .resizable()
            .scaledToFill()
            .frame(width: kScreenW, height: kScreenH)
            .clipped()
    }

    // MARK: - Screen slide 2: Lock screen with Live Activity near island

    private var screenSlide2: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.06, blue: 0.14),
                         Color(red: 0.09, green: 0.10, blue: 0.24)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(spacing: 3) {
                Text("4:30")
                    .font(.system(size: 52, weight: .thin))
                    .foregroundColor(.white)
                Text("Tuesday, 10 June")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
            }
            .offset(y: 24)

            // Live activity pill — rendered just below the island overlay
            ZStack {
                Capsule()
                    .fill(Color.black.opacity(0.88))
                    .frame(width: kScreenW - 20, height: 40)
                HStack(spacing: 8) {
                    Image("proIconDark")
                        .resizable().scaledToFit()
                        .frame(width: 18, height: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Asr")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                        Text("In 15 mins")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    Spacer()
                    Text("4:30 PM")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .frame(width: kScreenW - 20, height: 40)
            }
            // Position just below the island (island bottom = kIslandY + kIslandH/2)
            .offset(y: kIslandY + kIslandH / 2 + 28)
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        let sectionW = UIScreen.main.bounds.width - 40
        return VStack(spacing: 0) {
            featureRow(icon: "paintpalette.fill",
                       title: "Custom Icons",
                       subtitle: "Express your style with beautifully crafted app icons.",
                       rowWidth: sectionW)
            Divider().padding(.leading, 58)
            featureRow(icon: "square.grid.2x2.fill",
                       title: "Premium Widgets",
                       subtitle: "Advanced widgets with more prayer insights at a glance.",
                       rowWidth: sectionW)
            Divider().padding(.leading, 58)
            featureRow(icon: "dot.radiowaves.left.and.right",
                       title: "Live Activities",
                       subtitle: "Real-time prayer updates on your Lock Screen.",
                       rowWidth: sectionW)
        }
        .frame(width: sectionW)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(.systemGray5), lineWidth: 1)
        )
    }

    private func featureRow(icon: String, title: String, subtitle: String, rowWidth: CGFloat) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundColor(Color(.secondaryLabel))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: rowWidth)
    }

    // MARK: - Bottom panel (pricing + CTA + footer, always visible)

    private var bottomPanel: some View {
        VStack(spacing: 12) {
            #if canImport(RevenueCat)
            if !packages.isEmpty {
                let cardW = (UIScreen.main.bounds.width - 52) / 2
                HStack(spacing: 12) {
                    if let monthly = monthlyPackage {
                        priceCard(label: "Monthly",
                                  price: monthly.storeProduct.localizedPriceString,
                                  period: "/ month", badge: nil,
                                  isSelected: selectedIndex == 0) { selectedIndex = 0 }
                        .frame(width: cardW)
                    }
                    if let annual = annualPackage {
                        priceCard(label: "Yearly",
                                  price: annual.storeProduct.localizedPriceString,
                                  period: "/ year",
                                  badge: savingsPercent.map { "Save \($0)%" },
                                  isSelected: selectedIndex == 1) { selectedIndex = 1 }
                        .frame(width: cardW)
                    }
                }
                .padding(.horizontal, 20)
            }
            #endif
            ctaButton
                .padding(.horizontal, 20)
            footerSection
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    #if canImport(RevenueCat)
    private func priceCard(
        label: String, price: String, period: String,
        badge: String?, isSelected: Bool, onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isSelected ? .white : Color(.secondaryLabel))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(isSelected ? Color.black : Color(.systemGray5), in: Capsule())
                    } else {
                        Color.clear.frame(height: 22)
                    }
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(.secondaryLabel))
                    Text(price)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.primary)
                    Text(period)
                        .font(.caption)
                        .foregroundColor(Color(.secondaryLabel))
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .primary : Color(.systemGray3))
                    .padding(.top, 2)
            }
            .padding(13)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? Color.primary : Color(.systemGray5),
                              lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: .black.opacity(isSelected ? 0.07 : 0.02),
                radius: isSelected ? 8 : 2, x: 0, y: isSelected ? 3 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
    }
    #endif

    // MARK: - CTA

    private var ctaButton: some View {
        Button { purchase() } label: {
            ZStack {
                if isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    VStack(spacing: 2) {
                        Text("Continue with Pro")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        #if canImport(RevenueCat)
                        if let pkg = selectedPackage {
                            Text(selectedIndex == 0
                                 ? "\(pkg.storeProduct.localizedPriceString) / month"
                                 : "\(pkg.storeProduct.localizedPriceString) / year · billed annually")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        #endif
                    }
                }
            }
            .frame(width: UIScreen.main.bounds.width - 40, height: 56)
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.label)))
        .disabled(isPurchasing || isRestoring)
        .opacity((isPurchasing || isRestoring) ? 0.6 : 1)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 6) {
            Button { restore() } label: {
                Group {
                    if isRestoring {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Text("Restore Purchases").font(.footnote).underline()
                    }
                }
                .foregroundColor(Color(.secondaryLabel))
            }
            .disabled(isRestoring || isPurchasing)

            HStack(spacing: 6) {
                Text("Cancel anytime")
                Text("·")
                Link("Terms", destination: URL(string: "https://getwaktu.app/terms")!)
                Text("·")
                Link("Privacy", destination: URL(string: "https://getwaktu.app/privacy")!)
            }
            .font(.caption2)
            .foregroundColor(Color(.secondaryLabel))
        }
    }

    // MARK: - Actions

    private func purchase() {
        #if canImport(RevenueCat)
        guard let package = selectedPackage, !isPurchasing else { return }
        isPurchasing = true
        Task {
            do {
                let result = try await Purchases.shared.purchase(package: package)
                await MainActor.run {
                    isPurchasing = false
                    if !result.userCancelled { onPurchaseCompleted?() }
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    purchaseError = error.localizedDescription
                }
            }
        }
        #endif
    }

    private func restore() {
        #if canImport(RevenueCat)
        guard !isRestoring else { return }
        isRestoring = true
        Task {
            do {
                _ = try await Purchases.shared.restorePurchases()
                await revenueCat.refreshCustomerInfo()
                await MainActor.run {
                    isRestoring = false
                    if revenueCat.hasPro { onPurchaseCompleted?() }
                }
            } catch {
                await MainActor.run {
                    isRestoring = false
                    purchaseError = error.localizedDescription
                }
            }
        }
        #endif
    }
}
