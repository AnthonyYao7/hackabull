//
//  State.swift
//  sound
//
//  Created by Cole Smith on 4/13/25.
//

import Foundation
import CoreLocation
import Combine

class ApplicationState : ObservableObject {
//    @Published var path: MapPath? = nil
    @Published var path: Directions?;
    @Published var current_location: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 60.0, longitude: -140.0);
    @Published var headphone_calibration: CLHeading? = nil;
    
    var in_route: Bool { path != nil }
    
    init() {
        path = nil;
    }
}
