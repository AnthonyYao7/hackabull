import SwiftUI
import AVFoundation
import Combine

struct MicrophoneView: View {
    enum AppState {
        case listening
        case processing
        case caution
        case uploading // New state for uploading
    }
    
    @State private var appState: AppState = .listening
    @State private var flashingAnimation = false
    @GestureState private var isDetectingLongPress = false
    @State private var completedLongPress = true
    @State private var audioRecorder: AVAudioRecorder?

    @State private var audioUploadService = AudioUploadService()
    @State private var sessionRecordingURL: URL? // To store the temp recording URL
//    @State private var uploadCancellable: AnyCancellable?
    
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
                
//                // Show cancel button during uploading
//                if appState == .processing || appState == .uploading {
//                    Button("Cancel Upload") {
//                        cancelUpload()
//                    }
//                    .padding()
//                    .background(Color.gray.opacity(0.7))
//                    .foregroundColor(.white)
//                    .cornerRadius(8)
//                    .padding(.top, 50)
//                }
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
                    stopRecordingAndUpload()
                    withAnimation {
                        appState = .uploading
                    }
                }
        )
    }
    
    private func startRecording() {
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
                        self.sessionRecordingURL = url
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
    
    private func stopRecordingAndUpload() {
        if let recorder = audioRecorder, recorder.isRecording {
            recorder.stop()
            print("🛑 Recording stopped")
            
            // Upload the recording
            audioUploadService.uploadFromRecorder(recorder) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let responseData):
                        print("✅ Audio uploaded successfully: \(responseData)")
                        withAnimation {
                            appState = .caution
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            flashingAnimation = true
                        }
                        
                    case .failure(let error):
                        print("❌ Upload failed: \(error.localizedDescription)")
                        withAnimation {
                            appState = .listening
                        }
                    }
                    
                }
            }
        } else {
            withAnimation {
                appState = .listening
            }
        }
    }
    
    // Alternative direct recording and upload approach
    private func directRecordAndUpload(duration: TimeInterval = 5.0) {
        withAnimation {
            appState = .processing
        }
        
        audioUploadService.recordAndUpload(duration: duration) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    withAnimation {
                        appState = .caution
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        flashingAnimation = true
                    }
                    
                case .failure(let error):
                    print("❌ Direct recording and upload failed: \(error.localizedDescription)")
                    withAnimation {
                        appState = .listening
                    }
                }
            }
        }
    }
    
//    private func cancelUpload() {
//        uploadCancellable?.cancel()
//        uploadCancellable = nil
//        print("🚫 Upload cancelled")
//        withAnimation { appState = .listening }
//    }
    
    // Helper properties to determine appearance based on state
    
    private var backgroundColor: Color {
        switch appState {
        case .listening:
            return Color.white
        case .processing, .uploading:
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
        case .uploading:
            return "Uploading..."
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
        case .uploading:
            return Image(systemName: "arrow.up.circle")
        case .caution:
            return Image(systemName: "exclamationmark.triangle.fill")
        }
    }
    
    private var textColor: Color {
        switch appState {
        case .listening:
            return .black
        case .processing, .uploading, .caution:
            return .white
        }
    }
    
    private var iconColor: Color {
        switch appState {
        case .listening:
            return .black
        case .processing, .uploading, .caution:
            return .white
        }
    }
}
