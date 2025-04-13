import SwiftUI
import ARKit
import AVFoundation
import CoreHaptics
import CoreMotion
import Combine
import QuartzCore


struct SpatialAudioView: UIViewControllerRepresentable {
    class Controller: UIViewController {
        var audioService: SpatialAudioService!
        
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            audioService = SpatialAudioService()
            audioService.start()
        }
        
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            audioService?.stop()
        }
    }
    
    // Conformance to UIViewControllerRepresentable:
    typealias UIViewControllerType = Controller

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }
    
    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        // Nothing to update—audio service manages itself.
    }
}

// Minimal implementation of the audio service.
class SpatialAudioService: NSObject, ARSessionDelegate, ObservableObject {
    @Published var debugInfo: String = "Lidar status unknown."
    
    private var session = ARSession()
    private var isRunning = false
    
    private let audioEngine = AVAudioEngine()
    private let environmentNode = AVAudioEnvironmentNode()
    private var audioPlayerNode: AVAudioPlayerNode?
    private var mixerNode: AVAudioMixerNode?
    private var beepBuffer: AVAudioPCMBuffer?
    
    private var lastBeepTime: CFTimeInterval = 0.0
    private let maxDistance: Float = 10.0
    private let gridCountX = 5, gridCountY = 5
    
    private var hapticEngine: CHHapticEngine?
    private let headphoneMotionManager = CMHeadphoneMotionManager()
    
    // AR configuration enabling sceneDepth.
    lazy var lidarConfig: ARWorldTrackingConfiguration = {
        let c = ARWorldTrackingConfiguration()
        c.frameSemantics.insert(.sceneDepth)
        return c
    }()
    
    override init() {
        super.init()
        session.delegate = self
        setupHaptics()
        setupAudioEngine()
        
        if headphoneMotionManager.isDeviceMotionAvailable {
            headphoneMotionManager.startDeviceMotionUpdates()
        } else {
            print("Headphone motion not available – falling back to ARCamera orientation")
        }
        print("SpatialAudioService initialized")
    }
    
    deinit { stop() }
    
    func start() {
        guard !isRunning else { return }
        configureAudioSession()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.startAudioEngine()
        }
        session.run(lidarConfig)
        isRunning = true
        print("Spatial audio service started")
    }
    
    func stop() {
        guard isRunning else { return }
        session.pause()
        audioEngine.stop()
        audioPlayerNode?.stop()
        isRunning = false
        print("Spatial audio service stopped")
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback,
                                         mode: .spokenAudio,
                                         options: [.mixWithOthers, .duckOthers])
            if #available(iOS 15.0, *) { try audioSession.setSupportsMultichannelContent(true) }
            try audioSession.setActive(true)
            print("Audio session activated: \(audioSession.currentRoute)")
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptic engine error: \(error)")
        }
    }
    
    private func setupAudioEngine() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.reset()
        environmentNode.renderingAlgorithm = .HRTFHQ
        environmentNode.distanceAttenuationParameters.distanceAttenuationModel = .exponential
        environmentNode.distanceAttenuationParameters.referenceDistance = 0.5
        environmentNode.distanceAttenuationParameters.maximumDistance = maxDistance
        environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environmentNode.listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: 0, pitch: 0, roll: 0)
        audioEngine.attach(environmentNode)
        audioEngine.connect(environmentNode, to: audioEngine.mainMixerNode, format: nil)
        
        createAudioPlayer()
    }
    
    private func startAudioEngine() {
        do {
            try audioEngine.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.audioPlayerNode?.play()
            }
            print("Audio engine started successfully")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func createAudioPlayer() {
        if let existingPlayer = audioPlayerNode {
            existingPlayer.stop()
            audioEngine.detach(existingPlayer)
        }
        if let existingMixer = mixerNode {
            audioEngine.detach(existingMixer)
        }
        
        let player = AVAudioPlayerNode()
        audioEngine.attach(player)
        
        let envFormat = environmentNode.inputFormat(forBus: 0)
        let mixer = AVAudioMixerNode()
        audioEngine.attach(mixer)
        
        audioEngine.connect(player, to: mixer, format: envFormat)
        audioEngine.connect(mixer, to: environmentNode, format: envFormat)
        
        audioPlayerNode = player
        mixerNode = mixer
        
        if let player3D = player as? AVAudio3DMixing {
            player3D.renderingAlgorithm = .sphericalHead
            player3D.reverbBlend = 0.2
            player3D.position = AVAudio3DPoint(x: 0, y: 0, z: -1.0)
        }
        createShortBeepBuffer(for: player, format: envFormat)
    }
    
    private func createShortBeepBuffer(for player: AVAudioPlayerNode, format: AVAudioFormat) {
        let sampleRate = format.sampleRate, duration = 0.1
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("Failed to create beep buffer")
            return
        }
        buffer.frameLength = frameCount
        guard let floatChannelData = buffer.floatChannelData else {
            print("Failed to access channel data")
            return
        }
        let channelCount = Int(format.channelCount)
        for ch in 0..<channelCount {
            let channelData = floatChannelData[ch]
            for frame in 0..<Int(frameCount) {
                let t = Double(frame) / sampleRate
                let freq = 880.0, wave = sin(2.0 * .pi * freq * t)
                let envelope = fadeInOut(t: t, total: duration)
                channelData[frame] = Float(wave * envelope * 0.5)
            }
        }
        beepBuffer = buffer
    }
    
    private func fadeInOut(t: Double, total: Double) -> Double {
        let attack = 0.01, decay = 0.01
        let sustain = total - (attack + decay)
        if t < attack { return t / attack }
        else if t > attack + sustain { return 1.0 - ((t - (attack + sustain)) / decay) }
        return 1.0
    }
    
    // ARSession delegate method example:
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // For example, update listener position here.
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("AR session failed: \(error.localizedDescription)")
    }
}
