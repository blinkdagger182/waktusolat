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

    override func didMoveToWindow() {
        super.didMoveToWindow()
        attachIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        attachIfNeeded()
    }

    func attachIfNeeded() {
        guard let scrollView = enclosingScrollView() else { return }
        guard observedScrollView !== scrollView else { return }

        observation?.invalidate()
        observedScrollView = scrollView
        observation = scrollView.observe(\.contentOffset, options: [.initial, .new]) { [weak self] scrollView, _ in
            DispatchQueue.main.async {
                self?.onChange?(scrollView.contentOffset.y)
            }
        }
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

    deinit {
        observation?.invalidate()
    }
}

@MainActor
final class BottomBarVisibilityController: ObservableObject {
    @Published private(set) var isHidden = false

    private var activeSource = ""
    private var lastOffsets: [String: CGFloat] = [:]
    private let hideThreshold: CGFloat = 18

    func activate(source: String) {
        activeSource = source
        lastOffsets[source] = 0
        setHidden(false)
    }

    func handleScroll(offset: CGFloat, source: String) {
        guard source == activeSource else { return }

        let previousOffset = lastOffsets[source] ?? offset
        let delta = offset - previousOffset

        if offset > -24 {
            lastOffsets[source] = offset
            setHidden(false)
            return
        }

        guard abs(delta) > hideThreshold else { return }

        lastOffsets[source] = offset
        setHidden(delta < 0)
    }

    private func setHidden(_ hidden: Bool) {
        guard isHidden != hidden else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
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
