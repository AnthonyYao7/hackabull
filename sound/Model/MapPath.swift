import Foundation
import CoreLocation
import Combine

class MapPath: Identifiable, ObservableObject {
    let id = UUID()
    let title: String
    let waypoints: [Waypoint]
    let maxDeviationDistance: Double
    
    @Published var currentWaypointIndex = 0
    @Published var isCompleted = false
    @Published var isDeviatingFromPath = false
    @Published var distanceToNextWaypoint: Double = 0
    @Published var distanceFromPath: Double = 0
    
    var currentWaypoint: Waypoint? {
        currentWaypointIndex < waypoints.count ? waypoints[currentWaypointIndex] : nil
    }
    
    init(title: String, waypoints: [Waypoint], maxDeviationDistance: Double = 50.0) {
        self.title = title
        self.waypoints = waypoints
        self.maxDeviationDistance = maxDeviationDistance
    }
    
    func calculateDistanceFromPath(location: CLLocation) -> Double {
        if currentWaypointIndex == 0 {
            let wpLoc = CLLocation(latitude: waypoints[0].coordinate.latitude,
                                   longitude: waypoints[0].coordinate.longitude)
            return location.distance(from: wpLoc)
        } else if currentWaypointIndex >= waypoints.count {
            let lastLoc = CLLocation(latitude: waypoints.last!.coordinate.latitude,
                                     longitude: waypoints.last!.coordinate.longitude)
            return location.distance(from: lastLoc)
        } else {
            let prevLoc = CLLocation(latitude: waypoints[currentWaypointIndex - 1].coordinate.latitude,
                                     longitude: waypoints[currentWaypointIndex - 1].coordinate.longitude)
            let nextLoc = CLLocation(latitude: waypoints[currentWaypointIndex].coordinate.latitude,
                                     longitude: waypoints[currentWaypointIndex].coordinate.longitude)
            return min(location.distance(from: prevLoc), location.distance(from: nextLoc))
        }
    }
    
    func moveToNextWaypoint() {
        guard currentWaypointIndex < waypoints.count else { return }
        currentWaypointIndex += 1
        if currentWaypointIndex >= waypoints.count { isCompleted = true }
    }
    
    func reset() {
        currentWaypointIndex = 0
        isCompleted = false
        isDeviatingFromPath = false
    }
}
