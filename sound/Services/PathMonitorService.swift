import Foundation
import CoreLocation
import Combine
import SwiftUI

class PathMonitorService: ObservableObject {
    private let locationManager = LocationManager()
    
    @Published var currentPath: MapPath?
    @Published var isActive = false
    @Published var currentUserLocation: CLLocation?
    
    private var cancellables = Set<AnyCancellable>()
    private var simulationTimer: Timer?
    
    init() {
        setupLocationUpdates()
    }
    
    deinit {
        simulationTimer?.invalidate()
    }
    
    private func setupLocationUpdates() {
        // Subscribe to location updates
        locationManager.$location
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                guard let self = self else { return }
                self.currentUserLocation = location
                
                if self.isActive, let path = self.currentPath {
                    self.updatePathProgress(with: location)
                }
            }
            .store(in: &cancellables)
    }
    
    func loadPathFromAPI() async {
        // Since we don't have a real API, create a test path
        let newPath = MapPath(
            title: "Demo Path",
            waypoints: [
                Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                         title: "Start", requiredProximity: 10.0),
                Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.7752, longitude: -122.4190),
                         title: "Checkpoint 1", requiredProximity: 10.0),
                Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.7755, longitude: -122.4188),
                         title: "Checkpoint 2", requiredProximity: 10.0),
                Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.7760, longitude: -122.4185),
                         title: "Finish", requiredProximity: 15.0)
            ],
            maxDeviationDistance: 30.0
        )
        
        await MainActor.run {
            self.currentPath = newPath
            
            // Initialize with a default location if none exists
            if self.currentUserLocation == nil {
                self.currentUserLocation = CLLocation(
                    latitude: newPath.waypoints.first?.coordinate.latitude ?? 37.7749,
                    longitude: newPath.waypoints.first?.coordinate.longitude ?? -122.4194
                )
            }
        }
    }
    
    func generateRandomPath() async {
        // Generate a random path near the current location or default location
        let baseLocation = currentUserLocation ?? CLLocation(latitude: 37.7749, longitude: -122.4194)
        let baseLat = baseLocation.coordinate.latitude
        let baseLon = baseLocation.coordinate.longitude
        
        // Create a random path with 3-6 waypoints
        let waypointCount = Int.random(in: 3...6)
        var waypoints: [Waypoint] = []
        
        // First waypoint is near current location
        waypoints.append(
            Waypoint(
                coordinate: CLLocationCoordinate2D(
                    latitude: baseLat + Double.random(in: -0.0005...0.0005),
                    longitude: baseLon + Double.random(in: -0.0005...0.0005)
                ),
                title: "Start",
                requiredProximity: 10.0
            )
        )
        
        // Add intermediate waypoints
        for i in 1..<waypointCount-1 {
            // Each waypoint is increasingly further from the start
            let distanceFactor = Double(i) / Double(waypointCount - 1)
            waypoints.append(
                Waypoint(
                    coordinate: CLLocationCoordinate2D(
                        latitude: baseLat + Double.random(in: 0.001...0.004) * distanceFactor,
                        longitude: baseLon + Double.random(in: 0.001...0.004) * distanceFactor
                    ),
                    title: "Checkpoint \(i)",
                    requiredProximity: Double.random(in: 8.0...15.0)
                )
            )
        }
        
        // Add final waypoint
        waypoints.append(
            Waypoint(
                coordinate: CLLocationCoordinate2D(
                    latitude: baseLat + Double.random(in: 0.004...0.008),
                    longitude: baseLon + Double.random(in: 0.004...0.008)
                ),
                title: "Finish",
                requiredProximity: 15.0
            )
        )
        
        // Create the new path
        let newPath = MapPath(
            title: "Random Path \(Int.random(in: 100...999))",
            waypoints: waypoints,
            maxDeviationDistance: Double.random(in: 20.0...50.0)
        )
        
        await MainActor.run {
            self.currentPath = newPath
            // Reset user location to start of path for better visualization
            if let startCoord = waypoints.first?.coordinate {
                self.currentUserLocation = CLLocation(
                    latitude: startCoord.latitude,
                    longitude: startCoord.longitude
                )
            }
        }
    }
    
    func startPath(_ path: MapPath) {
        currentPath = path
        path.reset()
        isActive = true
        locationManager.startLocationUpdates()
        
        // If we don't have a location yet, use the start of the path
        if currentUserLocation == nil, let startWaypoint = path.waypoints.first {
            currentUserLocation = CLLocation(
                latitude: startWaypoint.coordinate.latitude,
                longitude: startWaypoint.coordinate.longitude
            )
        }
    }
    
    func stopCurrentPath() {
        isActive = false
        locationManager.stopLocationUpdates()
        stopSimulation()
    }
    
    private func updatePathProgress(with location: CLLocation) {
        guard let path = currentPath, !path.isCompleted else { return }
        
        // Calculate distance from the path
        let dfp = path.calculateDistanceFromPath(location: location)
        path.distanceFromPath = dfp
        path.isDeviatingFromPath = dfp > path.maxDeviationDistance
        
        // Check if close enough to current waypoint
        if let wp = path.currentWaypoint {
            let wpLoc = CLLocation(latitude: wp.coordinate.latitude,
                                  longitude: wp.coordinate.longitude)
            let dtn = location.distance(from: wpLoc)
            path.distanceToNextWaypoint = dtn
            
            if dtn <= wp.requiredProximity {
                path.moveToNextWaypoint()
                
                // Check if path is completed
                if path.isCompleted {
                    stopSimulation()
                }
            }
        }
    }
    
    // MARK: - Simulation Functions
    
    func startSimulation() {
        // Stop any existing simulation
        stopSimulation()
        
        // Start a new simulation timer
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.simulateStep()
        }
    }
    
    func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
    }
    
    func simulateStep() {
        guard isActive,
              let path = currentPath,
              !path.isCompleted,
              let currentWaypoint = path.currentWaypoint,
              let currentLocation = currentUserLocation else { return }
        
        // Get target location (current waypoint)
        let targetLocation = CLLocation(
            latitude: currentWaypoint.coordinate.latitude,
            longitude: currentWaypoint.coordinate.longitude
        )
        
        // Calculate distance and direction
        let distance = currentLocation.distance(from: targetLocation)
        
        if distance <= currentWaypoint.requiredProximity {
            // We've reached the waypoint
            updatePathProgress(with: currentLocation)
            return
        }
        
        // Calculate step size (10-20 meters, or less if close to destination)
        let stepSize = min(Double.random(in: 10.0...20.0), distance * 0.8)
        
        // Calculate new position
        let bearing = calculateBearing(from: currentLocation, to: targetLocation)
        let newLocation = calculateDestination(start: currentLocation, distance: stepSize, bearing: bearing)
        
        // Add some randomness to the path for realism
        let jitterLat = Double.random(in: -0.00005...0.00005)
        let jitterLon = Double.random(in: -0.00005...0.00005)
        
        let simulatedLocation = CLLocation(
            latitude: newLocation.coordinate.latitude + jitterLat,
            longitude: newLocation.coordinate.longitude + jitterLon
        )
        
        // Update with new simulated location
        DispatchQueue.main.async {
            self.currentUserLocation = simulatedLocation
            self.updatePathProgress(with: simulatedLocation)
        }
    }
    
    // Calculate bearing (direction) from one point to another
    private func calculateBearing(from start: CLLocation, to end: CLLocation) -> Double {
        let lat1 = start.coordinate.latitude * .pi / 180
        let lon1 = start.coordinate.longitude * .pi / 180
        let lat2 = end.coordinate.latitude * .pi / 180
        let lon2 = end.coordinate.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        var bearing = atan2(y, x) * 180 / .pi
        if bearing < 0 {
            bearing += 360
        }
        
        return bearing * .pi / 180 // Convert back to radians for further calculations
    }
    
    // Calculate destination point given a starting point, distance, and bearing
    private func calculateDestination(start: CLLocation, distance: Double, bearing: Double) -> CLLocation {
        let earthRadius = 6371000.0 // Earth radius in meters
        
        let lat1 = start.coordinate.latitude * .pi / 180
        let lon1 = start.coordinate.longitude * .pi / 180
        
        let angularDistance = distance / earthRadius
        
        let lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearing))
        let lon2 = lon1 + atan2(
            sin(bearing) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * sin(lat2)
        )
        
        return CLLocation(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }
}
