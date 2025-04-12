import SwiftUI
import SwiftData
import ARKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    @State private var showARView = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                    // LiDAR is available
                    Button(action: {
                        showARView = true
                    }) {
                        Text("Start Spatial Audio Scanner")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding()
                    
                    Text("This app uses LiDAR to scan your environment and play sounds based on object distances.")
                        .padding()
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                    
                    if showARView {
                        ARSpatialAudioView()
                            .edgesIgnoringSafeArea(.all)
                    }
                } else {
                    // No LiDAR available
                    VStack(spacing: 20) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        
                        Text("LiDAR Not Available")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("This app requires a device with LiDAR scanner (iPhone 12 Pro or newer, or recent iPad Pro).")
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .padding()
                    Spacer()
                }
            }
            .navigationTitle("Spatial Audio Scanner")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
