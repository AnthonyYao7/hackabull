import SwiftUI
import CoreLocation

let httpClient: HTTPClient = DefaultHTTPClient()
let locationService = LocationService()
var applicationState = ApplicationState()

@main
struct soundApp: App {
    init() {
        locationService.startMonitoring()
        applicationState.headphone_calibration = locationService.getCurrentHeading()
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
