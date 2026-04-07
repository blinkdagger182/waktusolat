import SwiftUI

extension View {
    func applyConditionalListStyle(defaultView: Bool) -> some View {
        self.modifier(ConditionalListStyle(defaultView: defaultView))
    }
    
    func endEditing() {
        #if !os(watchOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
    
    func dismissKeyboardOnScroll() -> some View {
        self.modifier(DismissKeyboardOnScrollModifier())
    }

    @ViewBuilder
    func hidesSystemTabBar() -> some View {
        if #available(iOS 16.0, *) {
            toolbar(.hidden, for: .tabBar)
        } else {
            self
        }
    }
}

struct ConditionalListStyle: ViewModifier {
    @EnvironmentObject var settings: Settings
    
    @Environment(\.colorScheme) var systemColorScheme
    @Environment(\.customColorScheme) var customColorScheme
    
    var defaultView: Bool
    
    var currentColorScheme: ColorScheme {
        if let colorScheme = settings.colorScheme {
            return colorScheme
        } else {
            return systemColorScheme
        }
    }

    func body(content: Content) -> some View {
        let canvasColor = currentColorScheme == .dark ? Color.black : Color(uiColor: .systemGroupedBackground)

        Group {
            #if !os(watchOS)
            Group {
                if defaultView {
                    defaultListContent(content: content, canvasColor: canvasColor)
                } else {
                    plainListContent(content: content, canvasColor: canvasColor)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            #else
            content
            #endif
        }
        .accentColor(settings.accentColor.color)
        .tint(settings.accentColor.color)
    }

    @ViewBuilder
    private func defaultListContent(content: Content, canvasColor: Color) -> some View {
        if #available(iOS 17.0, *) {
            content
                .listSectionSpacing(.compact)
                .apply {
                    if #available(iOS 16.0, *) {
                        $0.scrollContentBackground(.hidden)
                    } else {
                        $0
                    }
                }
                .background(canvasColor)
        } else if #available(iOS 16.0, *) {
            content
                .scrollContentBackground(.hidden)
                .background(canvasColor)
        } else {
            content
                .background(canvasColor)
        }
    }

    @ViewBuilder
    private func plainListContent(content: Content, canvasColor: Color) -> some View {
        if #available(iOS 16.0, *) {
            content
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(canvasColor)
        } else {
            content
                .listStyle(.plain)
                .background(canvasColor)
        }
    }
}

extension View {
    func apply<V: View>(@ViewBuilder _ block: (Self) -> V) -> V { block(self) }
}

#if os(iOS)
struct ScrollOffsetObserver: UIViewRepresentable {
    let onChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> ScrollOffsetObservationView {
        let view = ScrollOffsetObservationView()
        view.onChange = onChange
        return view
    }

    func updateUIView(_ uiView: ScrollOffsetObservationView, context: Context) {
        uiView.onChange = onChange
        uiView.attachIfNeeded()
    }
}

final class ScrollOffsetObservationView: UIView {
    var onChange: ((CGFloat) -> Void)?

    private weak var observedScrollView: UIScrollView?
    private var observation: NSKeyValueObservation?
    private var pendingAttachWorkItem: DispatchWorkItem?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        attachIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        attachIfNeeded()
    }

    func attachIfNeeded() {
        guard let scrollView = resolveScrollView() else {
            scheduleAttachRetry()
            return
        }
        guard observedScrollView !== scrollView else { return }

        pendingAttachWorkItem?.cancel()
        observation?.invalidate()
        observedScrollView = scrollView
        observation = scrollView.observe(\.contentOffset, options: [.initial, .new]) { [weak self] scrollView, _ in
            DispatchQueue.main.async {
                self?.onChange?(scrollView.contentOffset.y)
            }
        }
    }

    private func resolveScrollView() -> UIScrollView? {
        if let directAncestor = enclosingScrollView() {
            return directAncestor
        }

        if let nearbyAncestor = nearestAncestorWithScrollViewDescendant() {
            return findScrollView(in: nearbyAncestor)
        }

        if let window {
            return findScrollView(in: window)
        }

        return nil
    }

    private func enclosingScrollView() -> UIScrollView? {
        var candidate = superview
        while let current = candidate {
            if let scrollView = current as? UIScrollView {
                return scrollView
            }
            candidate = current.superview
        }
        return nil
    }

    private func nearestAncestorWithScrollViewDescendant() -> UIView? {
        var candidate = superview
        while let current = candidate {
            if findScrollView(in: current) != nil {
                return current
            }
            candidate = current.superview
        }
        return nil
    }

    private func findScrollView(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView {
            return scrollView
        }

        for subview in view.subviews {
            if let scrollView = findScrollView(in: subview) {
                return scrollView
            }
        }

        return nil
    }

    private func scheduleAttachRetry() {
        pendingAttachWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.attachIfNeeded()
        }

        pendingAttachWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }

    deinit {
        pendingAttachWorkItem?.cancel()
        observation?.invalidate()
    }
}

@MainActor
final class BottomBarVisibilityController: ObservableObject {
    @Published private(set) var isHidden = false

    private var activeSource = ""
    private var hidesOnScroll = false
    private var lastOffsets: [String: CGFloat] = [:]
    private var initialOffsets: [String: CGFloat] = [:]
    private let hideThreshold: CGFloat = 4

    func activate(source: String, hidesOnScroll: Bool) {
        activeSource = source
        self.hidesOnScroll = hidesOnScroll
        lastOffsets[source] = nil
        initialOffsets[source] = nil
        setHidden(false)
    }

    func handleScroll(offset: CGFloat, source: String) {
        guard source == activeSource else { return }
        guard hidesOnScroll else {
            lastOffsets[source] = offset
            setHidden(false)
            return
        }

        // First call: capture the actual initial offset as the "top" reference,
        // regardless of whether it is 0 or negative (NavigationView insets).
        guard let previousOffset = lastOffsets[source] else {
            lastOffsets[source] = offset
            initialOffsets[source] = offset
            return
        }

        let initial = initialOffsets[source] ?? offset
        let delta = offset - previousOffset

        // Within 40pt of the initial top position: always snap-show.
        if offset <= initial + 40 {
            lastOffsets[source] = offset
            setHidden(false)
            return
        }

        guard abs(delta) > hideThreshold else { return }

        lastOffsets[source] = offset
        // contentOffset.y increases when scrolling DOWN, so delta > 0 → hide.
        setHidden(delta > 0)
    }

    private func setHidden(_ hidden: Bool) {
        guard isHidden != hidden else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            isHidden = hidden
        }
    }
}

private struct NavigationBarSwipeHider: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.applyNavigationBehavior()
    }

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyNavigationBehavior()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            navigationController?.hidesBarsOnSwipe = false
        }

        func applyNavigationBehavior() {
            navigationController?.hidesBarsOnSwipe = true
        }
    }
}

extension View {
    func enablesScrollChromeHiding() -> some View {
        background(NavigationBarSwipeHider().frame(width: 0, height: 0))
    }
}
#else
extension View {
    func enablesScrollChromeHiding() -> some View { self }
    func hidesSystemTabBar() -> some View { self }
}
#endif
