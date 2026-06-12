import SwiftUI
import StoreKit
#if canImport(RevenueCat)
import RevenueCat
#endif


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

    // MARK: - Per-slide 3D phone angle (Y-axis degrees)

    private var slideAngle: Double {
        switch carouselPage {
        case 0: return -28   // left tilt — angled icon reference
        case 1: return  2    // near-straight — widget front view
        case 2: return  22   // right tilt — lock screen depth
        default: return 0
        }
    }

    private func screenImageForSlide(_ page: Int) -> UIImage? {
        switch page {
        case 0: return UIImage(named: "proCarousel1")
        case 1: return UIImage(named: "proCarousel2")
        case 2: return UIImage(named: "proCarousel3")
        default: return nil
        }
    }

    private var slideShadeX: CGFloat {
        switch carouselPage {
        case 0: return -14
        case 1: return 0
        case 2: return 12
        default: return 0
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection

                    carouselSection
                        .padding(.top, 16)
                        .padding(.bottom, 170)
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
                .padding(.top, 12)
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

    private var carouselSection: some View {
        VStack(spacing: 10) {
            VStack(spacing: 5) {
                Text("Make Waktu feel like yours")
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Text("Unlock custom icons, premium widgets, and live prayer updates across your iPhone.")
                    .font(.subheadline)
                    .foregroundColor(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)

            // Images have iPhone mockup built in — show at natural aspect ratio, no tilt
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    if let img = screenImageForSlide(i) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 260, maxHeight: 280)
                            .opacity(i == carouselPage ? 1 : 0)
                            .animation(.easeInOut(duration: 0.28), value: carouselPage)
                    }
                }
            }
            .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 6)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 28, coordinateSpace: .local)
                    .onEnded { value in
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
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

            // Slide label
            VStack(spacing: 3) {
                Text(slideTitles[carouselPage])
                    .font(.system(size: 15, weight: .bold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Text(slideSubtitles[carouselPage])
                    .font(.footnote)
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
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        VStack(spacing: 1) {
                            Text("Unlock Waktu Pro")
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
