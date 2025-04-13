//
//  MapStep.swift
//  sound
//
//  Created by Cole Smith on 4/13/25.
//

import Foundation
import CoreLocation
import Combine


class MapStep: Identifiable {
    var distance_meters: Double
    var duration_seconds: Int
    var start_location: CLLocation
    var end_location: CLLocation
    var waypoints: [Waypoint]
    var instruction: String
    
    init(distance_meters: Double, duration_seconds: Int, start_location: CLLocation, end_location: CLLocation, waypoints: [Waypoint], instruction: String) {
        self.distance_meters = distance_meters
        self.duration_seconds = duration_seconds
        self.start_location = start_location
        self.end_location = end_location
        self.waypoints = waypoints
        self.instruction = instruction
    }
}
