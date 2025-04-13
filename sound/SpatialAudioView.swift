//import SwiftUI
//import ARKit
//import AVFoundation
//import CoreHaptics
//import CoreMotion
//import Combine
//import QuartzCore
//
//
//struct SpatialAudioView: UIViewControllerRepresentable {
//    class Controller: UIViewController {
//        var audioService: SpatialAudioService!
//        
//        override func viewDidLoad() {
//            super.viewDidLoad()
//            view.backgroundColor = .black
//            audioService = SpatialAudioService()
//            audioService.start()
//        }
//            
//        override func viewWillDisappear(_ animated: Bool) {
//            super.viewWillDisappear(animated)
//            audioService?.stop()
//        }
//    }
//    
//    // Conformance to UIViewControllerRepresentable:
//    typealias UIViewControllerType = Controller
//
//    func makeUIViewController(context: Context) -> Controller {
//        Controller()
//    }
//    
//    func updateUIViewController(_ uiViewController: Controller, context: Context) {
//        // Nothing to update—audio service manages itself.
//    }
//}
