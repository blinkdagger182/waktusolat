import SwiftUI
#if os(iOS)
import UIKit
import PhotosUI
#endif
#if DEBUG && canImport(Inject)
import Inject
#endif
#if canImport(RevenueCat)
import RevenueCat
#endif
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

#if os(iOS)
private typealias WidgetPreviewImage = UIImage
#else
private struct WidgetPreviewImage {}
#endif

extension View {
    @ViewBuilder
    func hotReloadable() -> some View {
        #if DEBUG && canImport(Inject)
        self.enableInjection()
        #else
        self
        #endif
    }
}

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

    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor [weak self] in
            self?.customerInfo = customerInfo
        }
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
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.lastErrorMessage = error.localizedDescription
                    return
                }
                self.customerInfo = info
            }
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

                Section(header: Text("WIDGETS")) {
                    NavigationLink {
                        WidgetPreviewDebugView()
                    } label: {
                        Label("Aura Backgrounds (6 Waktu)", systemImage: "rectangle.grid.1x2")
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

#if os(iOS)
private struct AuraImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedImage: $selectedImage)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 1
        configuration.filter = .images
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        @Binding var selectedImage: UIImage?

        init(selectedImage: Binding<UIImage?>) {
            _selectedImage = selectedImage
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let itemProvider = results.first?.itemProvider else { return }

            if itemProvider.canLoadObject(ofClass: UIImage.self) {
                itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }
}

private struct AuraImageCropperView: View {
    let sourceImage: UIImage
    let aspectRatio: CGFloat
    let onSave: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var gestureStartScale: CGFloat = 1
    @State private var cropSize: CGSize = .zero

    var body: some View {
        NavigationView {
            GeometryReader { geo in
                let width = geo.size.width - 32
                let height = min(geo.size.height * 0.65, width / aspectRatio)
                let size = CGSize(width: width, height: height)

                ZStack {
                    Color.black.opacity(0.88).ignoresSafeArea()

                    VStack(spacing: 18) {
                        ZStack {
                            Color.black.opacity(0.35)

                            Image(uiImage: sourceImage)
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(dragGesture(in: size))
                                .simultaneousGesture(pinchGesture(in: size))
                        }
                        .frame(width: size.width, height: size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.7), lineWidth: 1.5)
                        )
                        .onAppear {
                            cropSize = size
                            initializeScale(for: size)
                        }
                        .onChange(of: size) { newSize in
                            cropSize = newSize
                            initializeScale(for: newSize)
                        }

                        Text("Drag and zoom to fit the Aura widget.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let cropped = cropImage() {
                            onSave(cropped)
                        }
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func initializeScale(for size: CGSize) {
        let fitSize = fittedImageSize(for: size)
        let minScaleX = size.width / max(fitSize.width, 1)
        let minScaleY = size.height / max(fitSize.height, 1)
        baseScale = max(1, minScaleX, minScaleY)
        scale = max(scale, baseScale)
        gestureStartScale = scale
        clampOffset(in: size)
    }

    private func fittedImageSize(for size: CGSize) -> CGSize {
        let imageRatio = sourceImage.size.width / max(sourceImage.size.height, 1)
        let frameRatio = size.width / max(size.height, 1)
        if imageRatio > frameRatio {
            let width = size.width
            return CGSize(width: width, height: width / imageRatio)
        } else {
            let height = size.height
            return CGSize(width: height * imageRatio, height: height)
        }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                clampOffset(in: size)
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func pinchGesture(in size: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = max(baseScale, min(6, gestureStartScale * value))
                clampOffset(in: size)
            }
            .onEnded { _ in
                gestureStartScale = scale
                clampOffset(in: size)
                lastOffset = offset
            }
    }

    private func clampOffset(in size: CGSize) {
        let fit = fittedImageSize(for: size)
        let scaled = CGSize(width: fit.width * scale, height: fit.height * scale)
        let limitX = max(0, (scaled.width - size.width) / 2)
        let limitY = max(0, (scaled.height - size.height) / 2)
        offset.width = min(max(offset.width, -limitX), limitX)
        offset.height = min(max(offset.height, -limitY), limitY)
    }

    private func cropImage() -> UIImage? {
        guard cropSize.width > 0, cropSize.height > 0 else { return nil }

        let fit = fittedImageSize(for: cropSize)
        let scaled = CGSize(width: fit.width * scale, height: fit.height * scale)

        let imageOriginInCrop = CGPoint(
            x: (cropSize.width - scaled.width) / 2 + offset.width,
            y: (cropSize.height - scaled.height) / 2 + offset.height
        )

        let pixelsPerPointX = sourceImage.size.width / max(scaled.width, 1)
        let pixelsPerPointY = sourceImage.size.height / max(scaled.height, 1)

        let cropRectInImage = CGRect(
            x: (0 - imageOriginInCrop.x) * pixelsPerPointX,
            y: (0 - imageOriginInCrop.y) * pixelsPerPointY,
            width: cropSize.width * pixelsPerPointX,
            height: cropSize.height * pixelsPerPointY
        ).integral

        let boundedRect = cropRectInImage.intersection(
            CGRect(origin: .zero, size: sourceImage.size)
        )

        guard
            boundedRect.width > 0,
            boundedRect.height > 0,
            let cgImage = sourceImage.cgImage?.cropping(to: boundedRect)
        else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: sourceImage.scale, orientation: sourceImage.imageOrientation)
    }
}
#endif

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

private struct WidgetPreviewDebugView: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) private var colorScheme
    #if DEBUG && canImport(Inject)
    @ObserveInjection var inject
    #endif
    #if os(iOS)
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingCropper = false
    @State private var selectedPrayerKey: AuraPrayerBackgroundKey?
    @State private var imageErrorMessage: String?
    @State private var expandedCardKey: AuraPrayerBackgroundKey?
    #endif

    private let waktuCards: [WidgetPreviewCardModel] = AuraPrayerBackgroundKey.allCases.enumerated().map { index, key in
        let sampleTimes = [("5:52", "AM", "In 3 hrs 7 mins"),
                           ("7:08", "AM", "In 4 hrs 23 mins"),
                           ("1:23", "PM", "In 8 hrs 38 mins"),
                           ("4:46", "PM", "In 12 hrs 1 min"),
                           ("7:26", "PM", "In 14 hrs 41 mins"),
                           ("8:39", "PM", "In 15 hrs 54 mins")]
        let sample = sampleTimes[min(index, sampleTimes.count - 1)]
        return .init(
            key: key,
            title: key.title,
            time: sample.0,
            period: sample.1,
            countdown: sample.2,
            assetName: key.defaultAssetName
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(waktuCards) { card in
                    #if os(iOS)
                    ZStack(alignment: .top) {
                        WidgetPreviewCard(
                            model: card,
                            customImage: customImage(for: card.key)
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedCardKey == card.key {
                                    expandedCardKey = nil
                                } else {
                                    expandedCardKey = card.key
                                }
                            }
                        }

                        if expandedCardKey == card.key {
                            VStack(spacing: 6) {
                                HStack(spacing: 8) {
                                    Button {
                                        settings.hapticFeedback()
                                        selectedPrayerKey = card.key
                                        showingImagePicker = true
                                    } label: {
                                        Text("Upload")
                                            .font(.caption2.weight(.semibold))
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(uploadButtonTint)
                                    .foregroundStyle(uploadButtonTextColor)

                                    Button {
                                        settings.hapticFeedback()
                                        let success = settings.applyCustomAuraBackgroundToAll(from: card.key)
                                        if !success {
                                            imageErrorMessage = "Could not apply this background to all prayer times."
                                        }
                                    } label: {
                                        Text("All")
                                            .font(.caption2.weight(.semibold))
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(uploadButtonTint)
                                    .foregroundStyle(uploadButtonTextColor)
                                    .disabled(!settings.hasCustomAuraBackground(for: card.key))

                                    Button(role: .destructive) {
                                        settings.hapticFeedback()
                                        settings.removeCustomAuraBackground(for: card.key)
                                    } label: {
                                        Text("Reset")
                                            .font(.caption2.weight(.semibold))
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(!settings.hasCustomAuraBackground(for: card.key))
                                }
                                .frame(maxWidth: .infinity, alignment: .center)

                                Text("\(card.title) background")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.95))
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .padding(.top, 8)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    #else
                    WidgetPreviewCard(
                        model: card,
                        customImage: customImage(for: card.key)
                    )
                    #endif
                }
            }
            .padding()
        }
        .navigationTitle("Widget Preview")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .hotReloadable()
        #if os(iOS)
        .sheet(isPresented: $showingImagePicker) {
            AuraImagePicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingCropper) {
            if let selectedImage {
                AuraImageCropperView(
                    sourceImage: selectedImage,
                    aspectRatio: 2.12
                ) { cropped in
                    guard let key = selectedPrayerKey else { return }
                    let saved = settings.saveCustomAuraBackground(cropped, for: key)
                    if !saved {
                        imageErrorMessage = "Could not save the cropped image."
                    }
                    self.selectedImage = nil
                }
            }
        }
        .onChange(of: selectedImage) { newValue in
            if newValue != nil {
                showingCropper = true
            }
        }
        .alert("Image Error", isPresented: Binding(
            get: { imageErrorMessage != nil },
            set: { if !$0 { imageErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                imageErrorMessage = nil
            }
        } message: {
            Text(imageErrorMessage ?? "Unknown image error.")
        }
        #endif
    }

    #if os(iOS)
    private var uploadButtonTint: Color {
        settings.accentColor.toggleTint
    }

    private var uploadButtonTextColor: Color {
        switch settings.accentColor {
        case .yellow, .mint, .cyan:
            return .black
        case .adaptive:
            return colorScheme == .dark ? .white : .primary
        default:
            return .primary
        }
    }

    private func customImage(for key: AuraPrayerBackgroundKey) -> WidgetPreviewImage? {
        _ = settings.auraBackgroundVersion
        return settings.customAuraBackgroundImage(for: key)
    }
    #else
    private func customImage(for key: AuraPrayerBackgroundKey) -> WidgetPreviewImage? {
        nil
    }
    #endif
}

private struct WidgetPreviewCardModel: Identifiable {
    let id = UUID()
    let key: AuraPrayerBackgroundKey
    let title: String
    let time: String
    let period: String
    let countdown: String
    let assetName: String
}

private struct WidgetPreviewCard: View {
    let model: WidgetPreviewCardModel
    let customImage: WidgetPreviewImage?

    var body: some View {
        ZStack(alignment: .leading) {
            #if os(iOS)
            if let customImage {
                Image(uiImage: customImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 170)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                Image(model.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 170)
                    .frame(maxWidth: .infinity)
                    .clipped()
            }
            #else
            Image(model.assetName)
                .resizable()
                .scaledToFill()
                .frame(height: 170)
                .frame(maxWidth: .infinity)
                .clipped()
            #endif

            LinearGradient(
                colors: [Color.black.opacity(0.12), Color.black.opacity(0.30)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill")
                        .font(.headline)
                    Text(model.title)
                        .font(.title2.weight(.bold))
                }
                .foregroundColor(.white)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(model.time)
                        .font(.system(size: 46, weight: .bold))
                    Text(model.period)
                        .font(.title2.weight(.semibold))
                }
                .foregroundColor(.white)

                Text(model.countdown)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white.opacity(0.95))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
