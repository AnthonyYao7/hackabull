import Foundation
import CoreLocation

// MARK: - Path & Waypoint Models
class MapPath: ObservableObject {
    let id = UUID()
    let title: String
    let waypoints: [Waypoint]
    let maxDeviationDistance: Double
    
    @Published var currentWaypointIndex: Int = 0
    @Published var distanceToNextWaypoint: Double = 0
    @Published var distanceFromPath: Double = 0
    @Published var isDeviatingFromPath: Bool = false
    
    var isCompleted: Bool {
        return currentWaypointIndex >= waypoints.count
    }
    
    var currentWaypoint: Waypoint? {
        guard currentWaypointIndex < waypoints.count else { return nil }
        return waypoints[currentWaypointIndex]
    }
    
    init(title: String, waypoints: [Waypoint], maxDeviationDistance: Double = 30.0) {
        self.title = title
        self.waypoints = waypoints
        self.maxDeviationDistance = maxDeviationDistance
    }
    
    func reset() {
        currentWaypointIndex = 0
        distanceToNextWaypoint = 0
        distanceFromPath = 0
        isDeviatingFromPath = false
    }
    
    func moveToNextWaypoint() {
        if currentWaypointIndex < waypoints.count {
            currentWaypointIndex += 1
        }
    }
    
    func calculateDistanceFromPath(location: CLLocation) -> Double {
        // If we're at the start or end of the path
        guard currentWaypointIndex > 0 && currentWaypointIndex < waypoints.count else {
            if let waypoint = currentWaypoint {
                let waypointLocation = CLLocation(
                    latitude: waypoint.coordinate.latitude,
                    longitude: waypoint.coordinate.longitude
                )
                return location.distance(from: waypointLocation)
            }
            return 0
        }
        
        // Calculate distance from the line segment between previous and current waypoint
        let prevWaypoint = waypoints[currentWaypointIndex - 1]
        let currentWaypointTarget = waypoints[currentWaypointIndex]
        
        let prevLocation = CLLocation(
            latitude: prevWaypoint.coordinate.latitude,
            longitude: prevWaypoint.coordinate.longitude
        )
        
        let targetLocation = CLLocation(
            latitude: currentWaypointTarget.coordinate.latitude,
            longitude: currentWaypointTarget.coordinate.longitude
        )
        
        // Simple distance to line segment calculation
        return distanceToLineSegment(
            point: location,
            lineStart: prevLocation,
            lineEnd: targetLocation
        )
    }
    
    private func distanceToLineSegment(point: CLLocation, lineStart: CLLocation, lineEnd: CLLocation) -> Double {
        // Convert to simple 2D geometry for distance calculation
        let x = point.coordinate.longitude
        let y = point.coordinate.latitude
        let x1 = lineStart.coordinate.longitude
        let y1 = lineStart.coordinate.latitude
        let x2 = lineEnd.coordinate.longitude
        let y2 = lineEnd.coordinate.latitude
        
        // Calculate vector components
        let A = x - x1
        let B = y - y1
        let C = x2 - x1
        let D = y2 - y1
        
        // Calculate dot product and squared length
        let dot = A * C + B * D
        let len_sq = C * C + D * D
        
        // Calculate parameter for closest point
        var param = -1.0
        if len_sq != 0 {
            param = dot / len_sq
        }
        
        // Find closest point
        var xx, yy: Double
        
        if param < 0 {
            xx = x1
            yy = y1
        } else if param > 1 {
            xx = x2
            yy = y2
        } else {
            xx = x1 + param * C
            yy = y1 + param * D
        }
        
        // Create location for closest point
        let closestPoint = CLLocation(latitude: yy, longitude: xx)
        
        // Calculate distance
        return point.distance(from: closestPoint)
    }
}
