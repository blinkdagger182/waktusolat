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
        Group {
            #if !os(watchOS)
            Group {
                if defaultView {
                    content
                        .apply {
                            if #available(iOS 17.0, *) {
                                $0.listSectionSpacing(.compact)
                            }
                        }
                } else {
                    content
                        .listStyle(.plain)
                        .background(currentColorScheme == .dark ? Color.black : Color.white)
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
}

extension View {
    func apply<V: View>(@ViewBuilder _ block: (Self) -> V) -> V { block(self) }
}

#if os(iOS)
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

    @ViewBuilder
    func minimizesTabBarOnScroll() -> some View {
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}
#else
extension View {
    func enablesScrollChromeHiding() -> some View { self }
    func minimizesTabBarOnScroll() -> some View { self }
}
#endif
