//
//  ProgressTypes.swift
//  sound
//
//  Created by Cole Smith on 4/13/25.
//

import CoreLocation

func decodePolyline(_ polyline: String) -> [CLLocationCoordinate2D] {
    var index = polyline.startIndex
    var lat = 0
    var lng = 0
    var coordinates: [(Double, Double)] = []
    
    while index < polyline.endIndex {
        var result = 0
        var shift = 0
        var b: Int
        
        // Decode latitude
        repeat {
            b = Int(polyline[index].asciiValue!) - 63
            index = polyline.index(after: index)
            result |= (b & 0x1F) << shift
            shift += 5
        } while b >= 0x20
        let deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        lat += deltaLat
        
        // Decode longitude
        result = 0
        shift = 0
        repeat {
            b = Int(polyline[index].asciiValue!) - 63
            index = polyline.index(after: index)
            result |= (b & 0x1F) << shift
            shift += 5
        } while b >= 0x20
        let deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        lng += deltaLng
        
        coordinates.append((Double(lat) / 1e5, Double(lng) / 1e5))
    }
    
    return coordinates.map {(lat, lon) in
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

class StepProgress  {
    var underlying_step: Step
    var path: [CLLocationCoordinate2D]
    
    init(step: Step) {
        underlying_step = step
        path = decodePolyline(step.polyline.encodedPolyline)
    }
}
