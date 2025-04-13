import SwiftUI
import AVFoundation

struct MicrophoneView: View {
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordStatus = "Not Recording"

    var body: some View {
        VStack(spacing: 20) {
            Text("Microphone View")
                .font(.title)
            Text(recordStatus)
                .font(.headline)
                .foregroundColor(isRecording ? .green : .red)
            Button(action: {
                isRecording ? stopRecording() : startRecording()
            }) {
                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
            }
        }
        .padding()
    }

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            session.requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    if allowed {
                        let settings: [String: Any] = [
                            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                            AVSampleRateKey: 12000,
                            AVNumberOfChannelsKey: 1,
                            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                        ]
                        let fileName = UUID().uuidString + ".m4a"
                        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                        do {
                            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
                            audioRecorder?.record()
                            recordStatus = "Recording..."
                            isRecording = true
                        } catch {
                            recordStatus = "Recording error: \(error.localizedDescription)"
                        }
                    } else {
                        recordStatus = "Microphone permission denied"
                    }
                }
            }
        } catch {
            recordStatus = "AVAudioSession error: \(error.localizedDescription)"
        }
    }

    private func stopRecording() {
        if audioRecorder?.isRecording == true { audioRecorder?.stop(); recordStatus = "Recording stopped" }
        isRecording = false
    }
}

struct MicrophoneView_Previews: PreviewProvider {
    static var previews: some View { MicrophoneView() }
}
