import SwiftUI
import CoreLocation
import AVFoundation

let httpClient: HTTPClient = DefaultHTTPClient()
let locationService = LocationService()
var applicationState = ApplicationState()

var speechSynthesizer = AVSpeechSynthesizer()


func speakMessage(text: String) {
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Siri_female_en-US")
    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    speechSynthesizer.speak(utterance)
}

@main
struct soundApp: App {
    init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Fail to enable session")
        }
        
        locationService.startMonitoring()
        applicationState.headphone_calibration = locationService.getCurrentHeading()
        
        speakMessage(text: "Where would you like to go?")
    }
    
    var body: some Scene {
        WindowGroup {
            TabView {
                MicrophoneView()
                    .tabItem {
                        Image(systemName: "mic.fill")
                        Text("Record")
                    }
                PathView()
                    .tabItem {
                        Image(systemName: "location.fill")
                        Text("Path")
                    }
            }
        }
    }
}

struct PathView: View {
    @State private var audioService = SpatialAudioService()
    
    var body: some View {
        NavigationView {
            PathNavigationView()
                .navigationTitle("Navigation")
        }
        .onAppear {
            audioService.start()
        }
        .onDisappear {
            audioService.stop()
        }
    }
}
