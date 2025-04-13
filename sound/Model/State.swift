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
    var in_route: Bool { path != nil }
    
    init() {
        path = nil;
    }
}
