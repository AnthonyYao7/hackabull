import SwiftUI
import CoreLocation
import Combine

struct PathNavigationView: View {
    @StateObject private var pathMonitor = PathMonitorService()
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // Example path using MapPath
    let testPath = MapPath(
        title: "Test Path",
        waypoints: [
            Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                     title: "Start", requiredProximity: 10.0),
            Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4190),
                     title: "Checkpoint 1", requiredProximity: 10.0),
            Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.7753, longitude: -122.4188),
                     title: "Finish", requiredProximity: 15.0)
        ],
        maxDeviationDistance: 30.0
    )
    
    var body: some View {
        VStack {
            Text("Path Navigation")
                .font(.largeTitle)
                .padding()
            
            if let path = pathMonitor.currentPath {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Path: \(path.title)")
                        .font(.headline)
                    if path.isCompleted {
                        Text("Path completed! 🎉")
                            .foregroundColor(.green)
                            .font(.title2)
                    } else if let wp = path.currentWaypoint {
                        Text("Next waypoint: \(wp.title)")
                        Text("Distance: \(Int(path.distanceToNextWaypoint)) meters")
                        if path.isDeviatingFromPath {
                            Text("WARNING: You are too far from the path!")
                                .foregroundColor(.red)
                                .font(.headline)
                        } else {
                            Text("On path: \(Int(path.distanceFromPath)) meters from the route")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding()
            }
            
            Spacer()
            HStack(spacing: 20) {
                Button(pathMonitor.isActive ? "Stop Navigation" : "Start Navigation") {
                    if pathMonitor.isActive {
                        pathMonitor.stopCurrentPath()
                    } else {
                        pathMonitor.startPath(testPath)
                    }
                }
                .padding()
                .background(pathMonitor.isActive ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Button("Reset Path") {
                    if let path = pathMonitor.currentPath {
                        path.reset()
                        showAlert = true
                        alertMessage = "Path has been reset."
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(!pathMonitor.isActive)
            }
            .padding(.bottom, 30)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Path Navigation"), message: Text(alertMessage),
                  dismissButton: .default(Text("OK")))
        }
    }
}
