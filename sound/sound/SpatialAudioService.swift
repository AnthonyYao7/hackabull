import SwiftUI
import ARKit
import AVFoundation
import CoreHaptics
import CoreMotion
import Combine
import QuartzCore
import CoreLocation


// MARK: - Background Spatial Audio Service
class SpatialAudioService: NSObject, ARSessionDelegate {
    
    // MARK: - Properties
    private var session = ARSession()
    private var isRunning = false
    
    // Audio engine components
    private let audioEngine = AVAudioEngine()
    private let environmentNode = AVAudioEnvironmentNode()
    private var audioPlayerNode: AVAudioPlayerNode?
    private var mixerNode: AVAudioMixerNode?
    
    // Beacon audio components
    private var beaconPlayerNode: AVAudioPlayerNode?
    private var beaconMixerNode: AVAudioMixerNode?
    private var beaconBuffer: AVAudioPCMBuffer?
    private var lastBeaconBeepTime: CFTimeInterval = 0.0
    private var beaconInterval: TimeInterval = 0.5 // Default interval
    
    private var beepBuffer: AVAudioPCMBuffer?

    /// We'll keep track of the last time we played a beep.
    private var lastBeepTime: CFTimeInterval = 0.0
    
    // Parameters
    private let maxDistance: Float = 10.0
    
    // Grid Configuration
    private let gridCountX = 5
    private let gridCountY = 5
    
    // Optional haptic engine
    private var hapticEngine: CHHapticEngine?
    
    private let headphoneMotionManager = CMHeadphoneMotionManager()
    
    private let lidarConfig: ARWorldTrackingConfiguration = {
        let c = ARWorldTrackingConfiguration()
        c.frameSemantics.insert(.sceneDepth)
        return c
    }()
    
    // MARK: - Initialization
    override init() {
        super.init()
        
        setupARSession()
        setupHaptics()
        setupAudioEngine()
        
        if headphoneMotionManager.isDeviceMotionAvailable {
            headphoneMotionManager.startDeviceMotionUpdates()
        } else {
            speakMessage("Headphone motion not available – falling back to ARCamera orientation")
        }
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Public Control Methods
    func start() {
        guard !isRunning else { return }
        
        configureAudioSession()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.setupBeaconAudio()
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
        
        if let player = audioPlayerNode {
            player.stop()
        }
        
        if let beaconPlayer = beaconPlayerNode {
            beaconPlayer.stop()
        }
        
        isRunning = false
        print("Spatial audio service stopped")
    }
    
    // MARK: - Audio Session Configuration
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.mixWithOthers, .duckOthers]
            )
            
            // Enable head tracking with AirPods Pro
            if #available(iOS 15.0, *) {
                try audioSession.setSupportsMultichannelContent(true)
            }
            
            try audioSession.setActive(true)
            // print("Audio session activated with spatial audio support: \(audioSession.currentRoute)")
        } catch {
            speakMessage("Failed to set up audio session: \(error)")
        }
    }
    
    // MARK: - AR Session Setup
    private func setupARSession() {
        session.delegate = self
    }
    
    // MARK: - Haptics Setup
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            speakMessage("Haptic engine error: \(error)")
        }
    }
    
    // MARK: - Audio Engine Setup
    private func setupAudioEngine() {
        // Reset any existing setup
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.reset()
        
        environmentNode.renderingAlgorithm = .HRTFHQ
        
        // Distance attenuation - how volume changes with distance
        environmentNode.distanceAttenuationParameters.distanceAttenuationModel = .exponential
        environmentNode.distanceAttenuationParameters.referenceDistance = 0.5
        environmentNode.distanceAttenuationParameters.maximumDistance = maxDistance
        
        // Initialize default listener position at origin
        environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environmentNode.listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: 0, pitch: 0, roll: 0)
        
        // Connect environment node to main mixer
        audioEngine.attach(environmentNode)
        audioEngine.connect(environmentNode, to: audioEngine.mainMixerNode, format: nil)
        
        // Create audio player for the sound
        createAudioPlayer()
    }
    
    // MARK: - Beacon Audio Setup
    private func setupBeaconAudio() {
        // Create dedicated nodes for the beacon sound
        let beaconPlayer = AVAudioPlayerNode()
        let beaconMixer = AVAudioMixerNode()
        
        audioEngine.attach(beaconPlayer)
        audioEngine.attach(beaconMixer)
        
        let envFormat = environmentNode.inputFormat(forBus: 0)
        
        // Connect chain: beaconPlayer -> beaconMixer -> environmentNode
        audioEngine.connect(beaconPlayer, to: beaconMixer, format: envFormat)
        audioEngine.connect(beaconMixer, to: environmentNode, format: envFormat)
        
        // Store references
        beaconPlayerNode = beaconPlayer
        beaconMixerNode = beaconMixer
        
        // Configure spatial properties
        if let mixer3D = beaconMixer as Optional<AVAudio3DMixing> {
            mixer3D.renderingAlgorithm = .HRTFHQ
            mixer3D.reverbBlend = 0.1
            // Position will be updated dynamically
        }
        
        // Create a distinct beacon sound (higher pitch than regular beep)
        createBeaconBuffer(for: beaconPlayer, format: envFormat)
    }
    
    private func createBeaconBuffer(for player: AVAudioPlayerNode, format: AVAudioFormat) {
        let sampleRate = format.sampleRate
        let duration = 0.08   // Very short beep
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            speakMessage("Failed to create beacon buffer")
            return
        }
        buffer.frameLength = frameCount
        
        let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(format.channelCount))
        for ch in 0..<Int(format.channelCount) {
            let channelData = channels[ch]
            for frame in 0..<Int(frameCount) {
                let t = Double(frame) / sampleRate
                // Higher frequency beacon sound at 1200 Hz
                let freq = 1200.0
                let wave = sin(2.0 * .pi * freq * t)
                
                // Envelope to avoid clicks
                let envelope = fadeInOut(t: t, total: duration)
                
                channelData[frame] = Float(wave * envelope * 0.4) // Slightly quieter than main beep
            }
        }
        
        // Save the buffer for scheduling later
        self.beaconBuffer = buffer
    }
    
    private func startAudioEngine() {
        do {
            try audioEngine.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.audioPlayerNode?.play()
                self?.beaconPlayerNode?.play()
            }
        } catch {
            speakMessage("Failed to start audio engine: \(error)")
        }
    }
    
    // MARK: - Audio Player Creation
    private func createAudioPlayer() {
        // Clean up existing player if needed
        if let existingPlayer = audioPlayerNode {
            existingPlayer.stop()
            audioEngine.detach(existingPlayer)
        }
        
        if let existingMixer = mixerNode {
            audioEngine.detach(existingMixer)
        }
        
        // Create a new player node
        let player = AVAudioPlayerNode()
        audioEngine.attach(player)
        
        // Get the environment node's input format
        let envFormat = environmentNode.inputFormat(forBus: 0)
        print("Environment node format: \(envFormat)")
        
        // Create a mixer node to handle any format conversion
        let mixer = AVAudioMixerNode()
        audioEngine.attach(mixer)
        
        // Connection chain: player -> mixer -> environment
        audioEngine.connect(player, to: mixer, format: envFormat)
        audioEngine.connect(mixer, to: environmentNode, format: envFormat)
        
        // Store references
        audioPlayerNode = player
        mixerNode = mixer
        
        // Configure spatial properties
        if let mixer3D = mixer as Optional<AVAudio3DMixing> {
            mixer3D.renderingAlgorithm = .sphericalHead
            mixer3D.reverbBlend = 0.2
            mixer3D.position = AVAudio3DPoint(x: 0, y: 0, z: -1.0)
        }
        
        createShortBeepBuffer(for: player, format: envFormat)
    }
    
    /// Create a single short "beep" buffer that we'll schedule repeatedly at runtime.
    private func createShortBeepBuffer(for player: AVAudioPlayerNode, format: AVAudioFormat) {
        let sampleRate = format.sampleRate
        let duration = 0.1   // Very short beep
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            speakMessage("Failed to create beep buffer")
            return
        }
        
        buffer.frameLength = frameCount
        
        let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(format.channelCount))
        for ch in 0..<Int(format.channelCount) {
            let channelData = channels[ch]
            for frame in 0..<Int(frameCount) {
                let t = Double(frame) / sampleRate
                // Simple sine wave beep at 880 Hz
                let freq = 880.0
                let wave = sin(2.0 * .pi * freq * t)
                
                // A little amplitude envelope to avoid clicks
                let envelope = fadeInOut(t: t, total: duration)
                
                channelData[frame] = Float(wave * envelope * 0.5)
            }
        }
        
        // Save the buffer for scheduling later
        self.beepBuffer = buffer
    }
    
    /// Quick helper to fade in and out over a short beep
    private func fadeInOut(t: Double, total: Double) -> Double {
        let attack = 0.01  // 10ms
        let decay  = 0.01  // 10ms
        let sustain = total - (attack + decay)
        
        if t < attack {
            // fade in
            return t / attack
        } else if t > attack + sustain {
            // fade out
            let dt = t - (attack + sustain)
            return 1.0 - (dt / decay)
        }
        return 1.0
    }
    
    // MARK: - Audio Positioning Logic
    private func updateSoundSourceFromDepthMap(depthMap: CVPixelBuffer, camera: ARCamera) {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        
        // Focus on the center region of the depth map
        let regionWidth = width / gridCountX
        let regionHeight = height / gridCountY
        
        // Center cell
        let centerXIndex = gridCountX / 2
        let centerYIndex = gridCountY / 2
        
        let startX = centerXIndex * regionWidth
        let startY = centerYIndex * regionHeight
        let endX = startX + regionWidth
        let endY = startY + regionHeight
        
        var minDistance: Float = .greatestFiniteMagnitude
        var minPixelX = startX
        var minPixelY = startY
        
        // Find closest point in the center region
        for y in startY..<endY {
            for x in startX..<endX {
                let index = (y * bytesPerRow / MemoryLayout<Float32>.size) + x
                let distance = floatBuffer[index]
                
                if distance > 0, distance < minDistance {
                    minDistance = distance
                    minPixelX = x
                    minPixelY = y
                }
            }
        }
        
        // Skip if no valid points found or no audio node to update
        guard minDistance < .greatestFiniteMagnitude,
              let mixerNode = self.mixerNode else {
            return
        }
        
        let normalizedX = (Float(minPixelX) / Float(width)) - 0.5
        let normalizedY = 0.5 - (Float(minPixelY) / Float(height))

        let forwardDir = simd_normalize(simd_float3(
            -camera.transform.columns.2.x,
             -camera.transform.columns.2.y,
             -camera.transform.columns.2.z
        ))
        
        let rightDir = simd_normalize(simd_float3(
            camera.transform.columns.0.x,
            camera.transform.columns.0.y,
            camera.transform.columns.0.z
        ))
        
        let upDir = simd_normalize(simd_float3(
            camera.transform.columns.1.x,
            camera.transform.columns.1.y,
            camera.transform.columns.1.z
        ))
        
        // We'll place our sound source on a sphere around the user
        // Get the camera/listener position
        let listenerPos = simd_float3(
            camera.transform.columns.3.x,
            camera.transform.columns.3.y,
            camera.transform.columns.3.z
        )
        
        // Make sure the sound source is always a fixed distance from the listener
        // regardless of the actual object distance
        let audioSourceDistance: Float = 1.0 // Fixed distance for consistent audio levels
        
        // Calculate the direction to the detected object using camera's orientation
        // Use the normalized coordinates to determine direction relative to camera
        let directionToObject = simd_normalize(
            forwardDir +
            rightDir * normalizedX +
            upDir * normalizedY
        )
        
        // Place the sound source at a fixed distance in that direction
        let audioSourcePosition = listenerPos + directionToObject * audioSourceDistance
        
        // Update the spatial audio position
        if let mixer3D = mixerNode as? AVAudio3DMixing {
            mixer3D.position = AVAudio3DPoint(
                x: audioSourcePosition.x,
                y: audioSourcePosition.y,
                z: audioSourcePosition.z
            )
            
            mixer3D.pointSourceInHeadMode = .mono
            mixer3D.renderingAlgorithm = .HRTFHQ
        }
        
        let beepInterval = mapDistanceToInterval(minDistance,
                                                 minInterval: 0.15,
                                                 maxInterval: 1.5)
        
        let beepVolume = 1.0 - mapDistanceToInterval(minDistance, minInterval: 0.2, maxInterval: 0.8)
        
        scheduleBeepIfNeeded(interval: beepInterval, volume: Float(beepVolume))
    }
    
    private func mapDistanceToInterval(_ distance: Float, minInterval: Double, maxInterval: Double) -> Double {
        let d = max(0, min(distance, maxDistance))
        return Double(d / maxDistance) * (maxInterval - minInterval) + minInterval
    }
    
    private func scheduleBeepIfNeeded(interval: Double, volume: Float) {
        guard let player = audioPlayerNode,
              let buffer = beepBuffer else {
            speakMessage("Missing player or buffer")
            return
        }
        
        let now = CACurrentMediaTime()
        if now - lastBeepTime >= interval {
            lastBeepTime = now
            provideHapticFeedback(intensity: volume)
            
            // Don't stop the player here, just adjust volume
            player.volume = volume
            
            // Schedule buffer without stopping first
            player.scheduleBuffer(buffer, at: nil)
            
            // Only call play() if player is not already playing
            if !player.isPlaying {
                player.play()
            }
        }
    }
    
    // Update the audio listener position and orientation
    private func updateAudioListener(using camera: ARCamera) {
        // Update the listener position based on the camera's position.
        let position = camera.transform.columns.3
        environmentNode.listenerPosition = AVAudio3DPoint(
            x: position.x,
            y: position.y,
            z: position.z
        )
        
        // Declare variables for yaw, pitch, and roll.
        var yaw: Float = 0.0, pitch: Float = 0.0, roll: Float = 0.0
        
        // Use headphone motion data if available.
        if let headphoneMotion = headphoneMotionManager.deviceMotion {
            // The attitude values are in radians; convert them to degrees.
            yaw = Float(headphoneMotion.attitude.yaw * 180.0 / .pi)
            pitch = Float(headphoneMotion.attitude.pitch * 180.0 / .pi)
            roll = Float(headphoneMotion.attitude.roll * 180.0 / .pi)
        } else {
            // Fallback: calculate yaw and pitch from the ARCamera's transform.
            let forwardVector = simd_float3(
                -camera.transform.columns.2.x,
                -camera.transform.columns.2.y,
                -camera.transform.columns.2.z
            )
            yaw = Float(atan2(forwardVector.x, forwardVector.z) * 180.0 / .pi)
            pitch = -Float(asin(forwardVector.y) * 180.0 / .pi)
            roll = 0
        }
        
        // Update the listener's angular orientation using the calculated yaw, pitch, and roll.
        environmentNode.listenerAngularOrientation = AVAudio3DAngularOrientation(
            yaw: 180 - yaw,
            pitch: pitch,
            roll: roll
        )
    }
    
    // MARK: - Haptic Feedback
    private func provideHapticFeedback(intensity: Float) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else { return }
        
        do {
            let intensityParameter = CHHapticEventParameter(
                parameterID: .hapticIntensity,
                value: Float(intensity)
            )
            
            let sharpnessParameter = CHHapticEventParameter(
                parameterID: .hapticSharpness,
                value: Float(intensity)
            )
            
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensityParameter, sharpnessParameter],
                relativeTime: 0
            )
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Haptic error: \(error)")
        }
    }
}

// MARK: - ARSession Delegate Extension
extension SpatialAudioService {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Process frames at about 10Hz to reduce CPU load
        if frame.timestamp.truncatingRemainder(dividingBy: 0.1) < 0.02 {
            // Update the listener position based on device position - this uses your existing head tracking
            updateAudioListener(using: frame.camera)
            
            updateBeaconDirection(camera: frame.camera)
            
            if let sceneDepth = frame.sceneDepth {
                updateSoundSourceFromDepthMap(depthMap: sceneDepth.depthMap, camera: frame.camera)
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        speakMessage("AR session failed: \(error.localizedDescription)")
    }
}

// MARK: - Location Beacon Methods
extension SpatialAudioService {
    func updateBeaconDirection(camera: ARCamera) {
        guard let userLocation = locationService.getCurrentLocation(),
              let beaconMixer = beaconMixerNode as? AVAudio3DMixing,
              applicationState.current_location.latitude != 0,
              applicationState.current_location.longitude != 0 else {
            return
        }
        
        // Calculate geographic bearing to target location (in radians)
        let geographicBearing = userLocation.coordinate.bearing(to: applicationState.current_location)
        
        let calibratedBearing = Float(geographicBearing) - Float(applicationState.headphone_calibration?.trueHeading ?? 0.0)
        
        // print(applicationState.headphone_calibration?.trueHeading ?? 0.0)
        
        // Get the listener position from camera
        let listenerPos = simd_float3(
            camera.transform.columns.3.x,
            camera.transform.columns.3.y,
            camera.transform.columns.3.z
        )
        
        // Fixed distance for the beacon sound
        let beaconDistance: Float = 2.0
        
        // Create a vector pointing in the direction of the geographic bearing IN WORLD SPACE
        let targetBearingVector = simd_float3(
            sin(Float(calibratedBearing)),
            0,
            -cos(Float(calibratedBearing))
        )
        
        // Calculate the position for the beacon sound source in world space
        let beaconPosition = listenerPos + targetBearingVector * beaconDistance
        
        // Update the spatial position of the beacon sound
        beaconMixer.position = AVAudio3DPoint(
            x: beaconPosition.x,
            y: beaconPosition.y,
            z: beaconPosition.z
        )
        
        // Calculate distance to target for adjusting beep frequency
        let distanceToTarget = userLocation.distance(from: CLLocation(
            latitude: applicationState.current_location.latitude,
            longitude: applicationState.current_location.longitude
        ))
        
        // Adjust beep interval based on distance (faster when closer)
        let minInterval = 0.2
        let maxInterval = 1.5
        let maxDistance = 500.0 // meters
        
        beaconInterval = min(maxInterval, max(minInterval,
            (distanceToTarget / maxDistance) * (maxInterval - minInterval) + minInterval))
        
        // Schedule the beacon sound
        scheduleBeaconBeepIfNeeded()
    }
    
    private func scheduleBeaconBeepIfNeeded() {
        guard let player = beaconPlayerNode,
              let buffer = beaconBuffer else {
            return
        }
        
        return;
        
        let now = CACurrentMediaTime()
        if now - lastBeaconBeepTime >= beaconInterval {
            lastBeaconBeepTime = now
            
            // Schedule buffer without stopping first
            player.scheduleBuffer(buffer, at: nil)
            
            // Only call play() if player is not already playing
            if !player.isPlaying {
                player.play()
            }
        }
    }
}

extension CLLocationCoordinate2D {
    func bearing(to coordinate: CLLocationCoordinate2D) -> Double {
        let lat1 = self.latitude * .pi / 180
        let lon1 = self.longitude * .pi / 180
        let lat2 = coordinate.latitude * .pi / 180
        let lon2 = coordinate.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        var bearing = atan2(y, x)
        bearing = (bearing + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
        
        return bearing
    }
}
