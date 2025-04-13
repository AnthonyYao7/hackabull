import Foundation
import CoreLocation

struct Waypoint: Identifiable, Equatable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
    let requiredProximity: Double
    var isCompleted = false
    
    static func == (lhs: Waypoint, rhs: Waypoint) -> Bool { lhs.id == rhs.id }
}
