import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var heading: CLHeading?
    @Published var locationStatus: CLAuthorizationStatus?
    @Published var lastError: Error?
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.requestWhenInUseAuthorization()
        
        locationManager.headingFilter = 1.0 // Update when heading changes by 1 degree
        locationManager.headingOrientation = .portrait // Set the orientation reference
    }
    
    func startLocationUpdates() {
        locationManager.startUpdatingLocation()
        
        // Check if heading is available before starting updates
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        } else {
            speakMessage("Heading updates not available on this device")
        }
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            startLocationUpdates()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if newHeading.headingAccuracy >= 0 {
            self.heading = newHeading
            speakMessage("Heading updated: \(newHeading.magneticHeading)° accuracy: \(newHeading.headingAccuracy)°")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error
        speakMessage("Location error: \(error.localizedDescription)")
    }
}
