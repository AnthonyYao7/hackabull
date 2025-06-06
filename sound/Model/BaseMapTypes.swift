//
//  BaseMapTypes.swift
//  sound
//
//  Created by Cole Smith on 4/13/25.
//

struct Polyline : Codable {
    let encodedPolyline: String
}

struct NavigationInstruction : Codable {
    let maneuver: String
    let instructions: String
}

struct Step : Codable {
    let distanceMeters: Int
    let staticDuration: String
    let polyline: Polyline
    let navigationInstruction: NavigationInstruction
}

struct Leg : Codable {
    let steps: [Step]
    let distanceMeters: Int
    let duration: String
    let polyline: Polyline
}

struct Route : Codable {
    let legs: [Leg]
    
}

struct Directions : Codable {
    let routes: [Route]
}
