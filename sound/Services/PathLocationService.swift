import SwiftUI
import CoreLocation
import Combine

func decodePolyline(_ polyline: String) -> [CLLocationCoordinate2D] {
    var index = polyline.startIndex
    var lat = 0
    var lng = 0
    var coordinates: [(Double, Double)] = []
    
    while index < polyline.endIndex {
        var result = 0
        var shift = 0
        var b: Int
        
        // Decode latitude
        repeat {
            b = Int(polyline[index].asciiValue!) - 63
            index = polyline.index(after: index)
            result |= (b & 0x1F) << shift
            shift += 5
        } while b >= 0x20
        let deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        lat += deltaLat
        
        // Decode longitude
        result = 0
        shift = 0
        repeat {
            b = Int(polyline[index].asciiValue!) - 63
            index = polyline.index(after: index)
            result |= (b & 0x1F) << shift
            shift += 5
        } while b >= 0x20
        let deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        lng += deltaLng
        
        coordinates.append((Double(lat) / 1e5, Double(lng) / 1e5))
    }
    
    return coordinates.map {(lat, lon) in
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct PathNavigationView: View {
    @StateObject private var pathMonitor = PathMonitorService()
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // Example path using MapPath
    let testPath = MapPath(
        title: "Test Path",
        waypoints: [
            Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                     requiredProximity: 10.0),
            Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4190),
                     requiredProximity: 10.0),
            Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.7753, longitude: -122.4188),
                     requiredProximity: 15.0)
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
                        var valid = true
                        var waypoints = [] as [Waypoint]
                        if let directions = applicationState.path, let route = directions.routes.first, let leg = route.legs.first {
                            for i in (0 ..< leg.steps.count) {
                                let step = leg.steps[i]
                                let coords = decodePolyline(step.polyline.encodedPolyline)
                                for (j, coord) in coords.enumerated() {
                                    let waypoint = Waypoint(coordinate: coord, requiredProximity: 50.0)
                                    waypoints.append(waypoint)
                                }
                                
                                if waypoints.count > 0 {
                                    waypoints[waypoints.count - 1].instruction = step.navigationInstruction.instructions
                                }
                            }
                        }
                        let testPath = MapPath(title: "Route", waypoints: waypoints)
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
