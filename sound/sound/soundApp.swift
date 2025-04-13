import SwiftUI

let httpClient: HTTPClient = DefaultHTTPClient()
let locationService = LocationService()

@main
struct soundApp: App {
    @State private var appState = ApplicationState()
    
    init() {
        locationService.startMonitoring()
    }
    
    var body: some Scene {
        WindowGroup {
            TabView {
                MicrophoneView()
                    .tabItem {
                        Image(systemName: "mic.fill")
                        Text("Record")
                    }
                    .environmentObject(appState)
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
