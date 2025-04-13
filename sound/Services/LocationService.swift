import Foundation
import CoreLocation

class LocationService {
    private let locationManager = LocationManager()
    
    func startMonitoring() {
        locationManager.startLocationUpdates()
    }
    
    func stopMonitoring() {
        locationManager.stopLocationUpdates()
    }
    
    func getCurrentLocation() -> CLLocation? {
        locationManager.location
    }
    
    func getLocationStatus() -> CLAuthorizationStatus? {
        locationManager.locationStatus
    }
    
    func getLastError() -> Error? {
        locationManager.lastError
    }
}
