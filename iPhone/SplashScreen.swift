import SwiftUI

struct SplashScreen: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) private var systemColorScheme

    private var currentColorScheme: ColorScheme {
        settings.colorScheme ?? systemColorScheme
    }

    private var continueTextColor: Color {
        if settings.accentColor == .adaptive {
            return currentColorScheme == .dark ? .black : .white
        }
        return .primary
    }
            
    var body: some View {
        NavigationView {
            VStack {
                Text("Waktu Solat is privacy-focused, ensuring that all data remains on your device. Enjoy an ad-free and lightweight prayer time experience.")
                    .font(.title3)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.5)
                    .padding()
                
                Spacer()
                
                Image("CurrentAppIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(24)
                    .padding()
                
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Button(action: {
                        settings.hapticFeedback()
                        
                        withAnimation {
                            settings.firstLaunch = false
                        }
                    }) {
                        Text("Continue")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                            .background(settings.accentColor.color)
                            .foregroundColor(continueTextColor)
                            .cornerRadius(24)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 10)
            }
            .navigationTitle("Assalamualaikum")
        }
        .navigationViewStyle(.stack)
    }
}

#Preview {
    SplashScreen()
        .environmentObject(Settings.shared)
}
