import SwiftUI
import CoreLocation
import Combine

struct PathNavigationView: View {
    @StateObject private var pathMonitor = PathMonitorService()
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var simulationActive = false
    
    var body: some View {
        ZStack {
            // Background gradient for better visual appeal
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.green.opacity(0.2)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                Text("Path Navigation")
                    .font(.system(size: 28, weight: .bold))
                    .padding()
                
                // Map visualization (placeholder)
                pathVisualization
                    .frame(height: 250)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(16)
                    .shadow(radius: 4)
                    .padding(.horizontal)
                
                // Path information
                pathInfoView
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(16)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                
                Spacer()
                
                // Control buttons
                controlButtonsView
                    .padding(.bottom, 30)
            }
            .padding()
        }
        .task {
            // Load an initial path when the view appears
            await pathMonitor.loadPathFromAPI()
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Path Navigation"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - Path Visualization
    private var pathVisualization: some View {
        ZStack {
            if let path = pathMonitor.currentPath {
                // Display the path and current position
                Path { pathDrawing in
                    // Starting point
                    if let firstWaypoint = path.waypoints.first {
                        pathDrawing.move(to: convertCoordinateToPoint(firstWaypoint.coordinate))
                    }
                    
                    // Draw lines to each waypoint
                    for waypoint in path.waypoints.dropFirst() {
                        pathDrawing.addLine(to: convertCoordinateToPoint(waypoint.coordinate))
                    }
                }
                .stroke(Color.blue, lineWidth: 3)
                
                // Draw waypoints as circles
                ForEach(0..<path.waypoints.count, id: \.self) { index in
                    let waypoint = path.waypoints[index]
                    let point = convertCoordinateToPoint(waypoint.coordinate)
                    
                    ZStack {
                        Circle()
                            .fill(waypointColor(for: index, in: path))
                            .frame(width: 20, height: 20)
                        
                        if index == path.currentWaypointIndex {
                            Circle()
                                .stroke(Color.red, lineWidth: 2)
                                .frame(width: 24, height: 24)
                        }
                    }
                    .position(point)
                    
                    // Waypoint labels
                    Text(waypoint.title)
                        .font(.caption)
                        .foregroundColor(.black)
                        .background(Color.white.opacity(0.7))
                        .padding(2)
                        .position(x: point.x, y: point.y - 20)
                }
                
                // Current user position
                if let location = pathMonitor.currentUserLocation {
                    let userPoint = convertCoordinateToPoint(location.coordinate)
                    
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .position(userPoint)
                    
                    Circle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: 20, height: 20)
                        .position(userPoint)
                }
            } else {
                Text("No path available")
                    .foregroundColor(.gray)
            }
        }
    }
    
    // Helper function to convert GPS coordinates to screen position
    private func convertCoordinateToPoint(_ coordinate: CLLocationCoordinate2D) -> CGPoint {
        guard let path = pathMonitor.currentPath else { return .zero }
        
        // Find path boundaries for scaling
        let minLat = path.waypoints.map { $0.coordinate.latitude }.min() ?? 0
        let maxLat = path.waypoints.map { $0.coordinate.latitude }.max() ?? 0
        let minLon = path.waypoints.map { $0.coordinate.longitude }.min() ?? 0
        let maxLon = path.waypoints.map { $0.coordinate.longitude }.max() ?? 0
        
        // Add some padding
        let latPadding = (maxLat - minLat) * 0.1
        let lonPadding = (maxLon - minLon) * 0.1
        
        let totalLatRange = (maxLat - minLat) + 2 * latPadding
        let totalLonRange = (maxLon - minLon) + 2 * lonPadding
        
        // Normalize to 0-1 range with padding
        let normalizedLat = 1.0 - ((coordinate.latitude - minLat + latPadding) / totalLatRange)
        let normalizedLon = (coordinate.longitude - minLon + lonPadding) / totalLonRange
        
        // Scale to view size (assuming 200x200 for visualization)
        return CGPoint(x: normalizedLon * 200, y: normalizedLat * 200)
    }
    
    // Color for waypoints based on completion status
    private func waypointColor(for index: Int, in path: MapPath) -> Color {
        if index < path.currentWaypointIndex {
            return .green // Completed waypoint
        } else if index == path.currentWaypointIndex {
            return .orange // Current target
        } else {
            return .gray // Future waypoint
        }
    }
    
    // MARK: - Path Information Panel
    private var pathInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let path = pathMonitor.currentPath {
                Text("Current Path: \(path.title)")
                    .font(.headline)
                
                if path.isCompleted {
                    Text("Path completed! 🎉")
                        .foregroundColor(.green)
                        .font(.title2)
                } else if let wp = path.currentWaypoint {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Next waypoint: \(wp.title)")
                            if pathMonitor.currentUserLocation != nil {
                                Text("Distance: \(Int(path.distanceToNextWaypoint)) meters")
                            } else {
                                Text("Waiting for location...")
                                    .italic()
                            }
                        }
                        
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .stroke(Color.gray, lineWidth: 2)
                                .frame(width: 40, height: 40)
                            
                            Circle()
                                .fill(path.isDeviatingFromPath ? Color.red : Color.green)
                                .frame(width: 20, height: 20)
                        }
                    }
                    
                    if path.isDeviatingFromPath {
                        Text("WARNING: You are too far from the path!")
                            .foregroundColor(.red)
                            .font(.headline)
                    } else {
                        Text("On path: \(Int(path.distanceFromPath)) meters from the route")
                            .foregroundColor(.blue)
                    }
                    
                    // Progress indicator
                    HStack {
                        Text("Progress:")
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .foregroundColor(.gray.opacity(0.3))
                                    .frame(height: 8)
                                    .cornerRadius(4)
                                
                                Rectangle()
                                    .foregroundColor(.blue)
                                    .frame(
                                        width: CGFloat(path.currentWaypointIndex) / CGFloat(path.waypoints.count) * geometry.size.width,
                                        height: 8
                                    )
                                    .cornerRadius(4)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            } else {
                Text("No path loaded")
                    .italic()
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - Control Buttons
    private var controlButtonsView: some View {
        VStack(spacing: 15) {
            HStack(spacing: 15) {
                // Start/Stop Navigation
                Button(action: {
                    if pathMonitor.isActive {
                        pathMonitor.stopCurrentPath()
                        simulationActive = false
                        showAlert = true
                        alertMessage = "Navigation stopped"
                    } else if let path = pathMonitor.currentPath {
                        pathMonitor.startPath(path)
                        showAlert = true
                        alertMessage = "Navigation started"
                    } else {
                        showAlert = true
                        alertMessage = "No path available!"
                    }
                }) {
                    Text(pathMonitor.isActive ? "Stop Navigation" : "Start Navigation")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(pathMonitor.isActive ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                }
                
                // Reset Path
                Button(action: {
                    if let path = pathMonitor.currentPath {
                        path.reset()
                        simulationActive = false
                        showAlert = true
                        alertMessage = "Path has been reset"
                    }
                }) {
                    Text("Reset Path")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                }
                .disabled(pathMonitor.currentPath == nil)
            }
            
            HStack(spacing: 15) {
                // Generate Random Path
                Button(action: {
                    Task {
                        await pathMonitor.generateRandomPath()
                        showAlert = true
                        alertMessage = "New random path generated"
                    }
                }) {
                    Text("Generate Random Path")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                }
                
                // Simulate Movement
                Button(action: {
                    if !simulationActive && pathMonitor.isActive {
                        simulationActive = true
                        pathMonitor.startSimulation()
                    } else if simulationActive {
                        simulationActive = false
                        pathMonitor.stopSimulation()
                    } else {
                        showAlert = true
                        alertMessage = "Start navigation first"
                    }
                }) {
                    Text(simulationActive ? "Stop Simulation" : "Simulate Movement")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(simulationActive ? Color.orange : Color.teal)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                }
            }
            
            // Manual Step Forward button
            Button(action: {
                if pathMonitor.isActive {
                    pathMonitor.simulateStep()
                } else {
                    showAlert = true
                    alertMessage = "Start navigation first"
                }
            }) {
                Text("Step Forward")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(radius: 2)
            }
            .disabled(!pathMonitor.isActive || pathMonitor.currentPath?.isCompleted == true)
        }
    }
}
