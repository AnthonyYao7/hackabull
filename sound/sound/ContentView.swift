import SwiftUI
import AVFoundation

struct ContentView: View {
    enum AppState {
        case listening
        case processing
        case caution
    }
    
    @State private var appState: AppState = .listening
    @State private var flashingAnimation = false
    @GestureState private var isDetectingLongPress = false
    @State private var completedLongPress = true
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioService = SpatialAudioService()
    
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
        .animation(.easeInOut(duration: 1), value: appState)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if appState != .processing {
                        withAnimation {
                            appState = .processing
                        }
                        startRecording()
                    }
                }
                .onEnded { _ in
                    stopRecording()
                    withAnimation {
                        appState = .caution
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        flashingAnimation = true
                    }
                }
        )
    }
    
    private func startRecording() {
        audioService.stop();
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            session.requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    if allowed {
                        let settings = [
                            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                            AVSampleRateKey: 12000,
                            AVNumberOfChannelsKey: 1,
                            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                        ]

                        let fileName = UUID().uuidString + ".m4a"
                        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                        print("🎙️ Recording started. File saved at: \(url)")

                        do {
                            self.audioRecorder = try AVAudioRecorder(url: url, settings: settings)
                            self.audioRecorder?.record()
                            print("🎙️ Recording started: \(url.lastPathComponent)")
                        } catch {
                            print("❌ Could not start recording: \(error.localizedDescription)")
                        }
                    } else {
                        print("❌ Microphone permission denied")
                    }
                }
            }
        } catch {
            print("❌ AVAudioSession setup failed: \(error.localizedDescription)")
        }
    }
    
    private func stopRecording() {
        if audioRecorder?.isRecording == true {
            audioRecorder?.stop()
            print("🛑 Recording stopped")
        }
        
        self.audioService.start()
    }


    
    // Helper properties to determine appearance based on state
    
    private var backgroundColor: Color {
        switch appState {
        case .listening:
            return Color.white
        case .processing:
            return Color.blue
        case .caution:
            return flashingAnimation ? Color.red : Color.white
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

struct ListeningApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
