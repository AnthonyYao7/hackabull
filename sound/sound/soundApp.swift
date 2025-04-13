import SwiftUI

@main
struct soundApp: App {
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
    var body: some View {
        NavigationView {
            PathNavigationView()
                .navigationTitle("Navigation")
        }
    }
}
