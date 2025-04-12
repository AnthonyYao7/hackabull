import SwiftUI

struct ContentView: View {
    enum AppState {
        case listening
        case processing
        case caution
    }
    
    @State private var appState: AppState = .listening
    @State private var flashingAnimation = false
    @GestureState private var isDetectingLongPress = false
    
    var body: some View {
        ZStack {
            // Background color based on state
            backgroundColor
                .edgesIgnoringSafeArea(.all)
                .animation(appState == .caution ? Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default, value: flashingAnimation)
            
            VStack {
                // Text based on state
                Text(stateText)
                    .font(.system(size: 65, weight: .bold))
                    .foregroundColor(textColor)
                    .padding(.bottom, 200)
                    .transition(.opacity)
                    .id("text-\(appState)")
                    .animation(.easeInOut(duration: 0.3), value: appState)
                
                // Icon based on state
                stateIcon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
                    .foregroundColor(iconColor)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState)
        // Gesture for tap and hold
        .gesture(
            LongPressGesture(minimumDuration: 5)
                .updating($isDetectingLongPress) { currentValue, state, _ in
                    state = currentValue
                    if currentValue && appState == .listening {
                        withAnimation {
                            appState = .processing
                        }
                    }
                }
                .onEnded { _ in
                    if appState == .processing {
                        withAnimation {
                            appState = .caution
                            flashingAnimation = true
                        }
                    }
                }
        )
    }
    
    // Helper properties to determine appearance based on state
    
    private var backgroundColor: Color {
        switch appState {
        case .listening:
            return Color.white
        case .processing:
            return Color.blue
        case .caution:
            return flashingAnimation ? Color.red : Color.red.opacity(0.7)
        }
    }
    
    private var stateText: String {
        switch appState {
        case .listening:
            return "Listening..."
        case .processing:
            return "Processing..."
        case .caution:
            return "Caution!"
        }
    }
    
    private var stateIcon: Image {
        switch appState {
        case .listening:
            return Image(systemName: "mic.fill")
        case .processing:
            return Image(systemName: "waveform")
        case .caution:
            return Image(systemName: "exclamationmark.triangle.fill")
        }
    }
    
    private var textColor: Color {
        switch appState {
        case .listening:
            return .black
        case .processing, .caution:
            return .white
        }
    }
    
    private var iconColor: Color {
        switch appState {
        case .listening:
            return .black
        case .processing, .caution:
            return .white
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

@main
struct ListeningApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
