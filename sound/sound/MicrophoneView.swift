import AVFoundation

import Combine

import SwiftUI

struct MicrophoneView: View {
    enum AppState {
        case neutral
        case listening
        case uploading

        // Separate use in the path screen
        case caution
    }

    @State private var appState: AppState = .neutral
    @State private var flashingAnimation = false
    @GestureState private var isDetectingLongPress = false
    @State private var completedLongPress = true
    @State private var audioRecorder: AVAudioRecorder?

    @StateObject private var audioUploadService = AudioUploadService()
    @State private var sessionRecordingURL: URL?  // To store the temp recording URL
    //    @State private var uploadCancellable: AnyCancellable?

    var body: some View {
        ZStack {
            // Background color based on state
            backgroundColor
                .edgesIgnoringSafeArea(.all)
                .animation(
                    appState == .caution
                        ? Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                        : .default, value: flashingAnimation)

            VStack {
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
                    .transition(
                        .asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))

                //                // Show cancel button during uploading
                //                if appState == .listening || appState == .uploading {
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
                    if appState == .neutral {
                        withAnimation { appState = .listening }
                        startRecording()
                    }
                }
                .onEnded { _ in
                    stopRecordingAndUpload()
                    withAnimation {
                        appState = .neutral
                    }
                }
        )
    }

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            AVAudioApplication.requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    if allowed {
                        let settings = [
                            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                            AVSampleRateKey: 12000,
                            AVNumberOfChannelsKey: 1,
                            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                        ]

                        let fileName = UUID().uuidString + ".m4a"
                        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
                            fileName)
                        self.sessionRecordingURL = url
                        speakMessage("Recording started. File saved at: \(url)")

                        do {
                            self.audioRecorder = try AVAudioRecorder(url: url, settings: settings)
                            self.audioRecorder?.record()
                            speakMessage("Recording started: \(url.lastPathComponent)")
                        } catch {
                            speakMessage("Could not start recording: \(error.localizedDescription)")
                        }
                    } else {
                        speakMessage("Microphone permission denied")
                    }
                }
            }
        } catch {
            speakMessage("❌ AVAudioSession setup failed: \(error.localizedDescription)")
        }
    }

    private func stopRecordingAndUpload() {
        if let recorder = audioRecorder, recorder.isRecording {
            recorder.stop()
            // print("Recording stopped")

            withAnimation {
                appState = .uploading
            }

            // Upload the recording
            audioUploadService.uploadFromRecorder(recorder) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let responseData):
                        speakMessage("✅ Audio uploaded successfully: \(responseData)")
                        withAnimation {
                            appState = .neutral
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            flashingAnimation = true
                        }
                    case .failure(let error):
                        speakMessage("❌ Upload failed: \(error.localizedDescription)")
                        withAnimation {
                            appState = .neutral
                        }
                    }

                }
            }
        } else {
            print("Recording stopped at unknown state")
            withAnimation {
                appState = .neutral
            }
        }
    }

    //    private func cancelUpload() {
    //        uploadCancellable?.cancel()
    //        uploadCancellable = nil
    //        print("🚫 Upload cancelled")
    //        withAnimation { appState =  }
    //    }

    // Helper properties to determine appearance based on state

    private var backgroundColor: Color {
        switch appState {
        case .neutral:
            return Color.white
        case .listening:
            return Color.blue
        case .uploading:
            return Color.purple
        case .caution:
            // TODO: Fix
            return flashingAnimation ? Color.red : Color.white
        }
    }

    private var stateText: String {
        switch appState {
        case .neutral:
            return "Hold to speak..."
        case .listening:
            return "Listening..."
        case .uploading:
            return "Uploading..."
        case .caution:
            return "Caution!"
        }
    }

    private var stateIcon: Image {
        switch appState {
        case .neutral:
            return Image(systemName: "dot.circle")
        case .listening:
            return Image(systemName: "waveform")  // mic.fill
        case .uploading:
            return Image(systemName: "arrow.up.circle")
        case .caution:
            return Image(systemName: "exclamationmark.triangle.fill")
        }
    }

    private var textColor: Color {
        switch appState {
        case .neutral:
            return .black
        case .listening:
            return .white
        case _:
            return .gray
        }
    }

    private var iconColor: Color {
        switch appState {
        case .listening:
            return .white
        case _:
            return .gray
        }
    }
}
