import Foundation
import CoreLocation
import Combine

class PathMonitorService: ObservableObject {
    private let locationService = LocationService()
    
    @Published var currentPath: MapPath?
    @Published var isActive = false
    
    private var cancellables = Set<AnyCancellable>()
    private var locationUpdateTimer: Timer?
    
    init() { setupLocationUpdates() }
    
    private func setupLocationUpdates() {
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self,
                  self.isActive,
                  let path = self.currentPath,
                  let loc = self.locationService.getCurrentLocation() else { return }
            self.updatePathProgress(with: loc)
        }
    }
    
    func startPath(_ path: MapPath) {
        currentPath = path
        path.reset()
        isActive = true
        locationService.startMonitoring()
    }
    
    func stopCurrentPath() {
        isActive = false
        locationService.stopMonitoring()
    }
    
    private func updatePathProgress(with location: CLLocation) {
        guard let path = currentPath, !path.isCompleted else { return }
        
        let dfp = path.calculateDistanceFromPath(location: location)
        path.distanceFromPath = dfp
        path.isDeviatingFromPath = dfp > path.maxDeviationDistance
        print("In update path progress")
        if let wp = path.currentWaypoint {
            print("found waypoint")
            let wpLoc = CLLocation(latitude: wp.coordinate.latitude,
                                   longitude: wp.coordinate.longitude)
            let dtn = location.distance(from: wpLoc)
            path.distanceToNextWaypoint = dtn
            print("distance to next waypoint: \(dtn)")
            if dtn <= wp.requiredProximity {
                print("moving to next waypoint")
                path.moveToNextWaypoint()
                let dfp = path.calculateDistanceFromPath(location: location)
                path.distanceFromPath = dfp
                if path.isCompleted { handlePathCompletion(); print("path completed") }
            }

        }
    }
    
    private func handlePathCompletion() {
        print("Path completed!")
    }
}
